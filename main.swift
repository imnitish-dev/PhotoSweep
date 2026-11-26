import SwiftUI
import Photos

let batchSize = 100

enum Category: String, CaseIterable, Identifiable {
    case screenshots = "Screenshots"
    case whatsapp = "WhatsApp & Saved"
    case videos = "Videos (longest first)"
    case all = "All Photos"
    var id: String { rawValue }
}

@MainActor
final class Store: ObservableObject {
    @Published var category: Category = .screenshots
    @Published var batch: [PHAsset] = []
    @Published var marked = Set<String>()
    @Published var remaining = 0
    @Published var status = "Requesting access…"
    @Published var preview: PHAsset?
    let manager = PHCachingImageManager()

    // IDs you reviewed and kept: never shown again.
    private let keptURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhotoSweep", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("kept.json")
    }()
    private var kept: Set<String> = []

    func start() {
        kept = (try? JSONDecoder().decode(Set<String>.self, from: Data(contentsOf: keptURL))) ?? []
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
            Task { @MainActor in
                if s == .authorized || s == .limited { self.load() }
                else { self.status = "No access. Allow it in System Settings → Privacy & Security → Photos." }
            }
        }
    }

    func select(_ c: Category) { category = c; load() }

    func load() {
        status = "Loading…"; marked.removeAll(); batch = []
        let cat = category, skip = kept
        Task.detached {
            let list = Store.fetch(cat).filter { !skip.contains($0.localIdentifier) }
            await MainActor.run {
                self.remaining = list.count
                self.batch = Array(list.prefix(batchSize))
                self.status = list.isEmpty ? "All done here 🎉" : "\(list.count) left to review"
            }
        }
    }

    nonisolated static func fetch(_ cat: Category) -> [PHAsset] {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "favorite == NO")
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        var list: [PHAsset] = []
        switch cat {
        case .screenshots:
            PHAsset.fetchAssets(with: .image, options: opts).enumerateObjects { a, _, _ in
                if a.mediaSubtypes.contains(.photoScreenshot) { list.append(a) }
            }
        case .videos:
            PHAsset.fetchAssets(with: .video, options: opts).enumerateObjects { a, _, _ in list.append(a) }
            list.sort { $0.duration > $1.duration }
        case .whatsapp:
            let re = try! NSRegularExpression(pattern: "^(IMG|VID)-\\d{8}-WA\\d+|^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-")
            PHAsset.fetchAssets(with: .image, options: opts).enumerateObjects { a, _, _ in
                if a.mediaSubtypes.contains(.photoScreenshot) { return }
                guard let fn = PHAssetResource.assetResources(for: a).first?.originalFilename else { return }
                if re.firstMatch(in: fn, range: NSRange(fn.startIndex..., in: fn)) != nil { list.append(a) }
            }
        case .all:
            PHAsset.fetchAssets(with: opts).enumerateObjects { a, _, _ in list.append(a) }
        }
        return list
    }

    func toggle(_ a: PHAsset) {
        let id = a.localIdentifier
        if marked.contains(id) { marked.remove(id) } else { marked.insert(id) }
    }

    func markAll() { marked = Set(batch.map(\.localIdentifier)) }

    /// Delete the red ones (to Recently Deleted), remember the rest as kept, load next 100.
    func finishBatch() {
        let toDelete = marked
        let toKeep = batch.map(\.localIdentifier).filter { !toDelete.contains($0) }
        let saveKept = {
            self.kept.formUnion(toKeep)
            try? JSONEncoder().encode(self.kept).write(to: self.keptURL)
            self.load()
        }
        guard !toDelete.isEmpty else { saveKept(); return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: Array(toDelete), options: nil)
        PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.deleteAssets(assets) }) { ok, err in
            Task { @MainActor in
                if ok { saveKept() }   // cancelled confirm = nothing saved, batch stays
                else { self.status = "Not deleted: \(err?.localizedDescription ?? "cancelled")" }
            }
        }
    }

    func resetKept() {
        kept = []; try? FileManager.default.removeItem(at: keptURL); load()
    }
}

struct Thumb: View {
    let asset: PHAsset
    let manager: PHCachingImageManager
    let marked: Bool
    var size: CGFloat = 160
    @State private var image: NSImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image { Image(nsImage: image).resizable().scaledToFill() }
                else { Color.gray.opacity(0.2) }
            }
            .frame(width: size, height: size).clipped()
            if asset.mediaType == .video {
                Text(Duration.seconds(asset.duration).formatted(.time(pattern: .minuteSecond)))
                    .font(.caption.bold()).padding(3)
                    .background(.black.opacity(0.6)).foregroundStyle(.white)
            }
        }
        .overlay(marked ? Color.red.opacity(0.45) : .clear)
        .overlay(alignment: .topTrailing) {
            if marked { Image(systemName: "trash.circle.fill").font(.title).foregroundStyle(.white).padding(4) }
        }
        .border(marked ? Color.red : .clear, width: 3)
        .task(id: "\(asset.localIdentifier)-\(Int(size / 120))") { // re-fetch sharper image when zoomed in
            let o = PHImageRequestOptions()
            o.isNetworkAccessAllowed = true
            o.deliveryMode = .opportunistic
            manager.requestImage(for: asset, targetSize: CGSize(width: size * 2, height: size * 2),
                                 contentMode: .aspectFill, options: o) { img, _ in
                if let img { image = img }
            }
        }
    }
}

struct ContentView: View {
    @StateObject var store = Store()
    @AppStorage("thumbSize") var thumb: Double = 160

    var body: some View {
        NavigationSplitView {
            List(Category.allCases, selection: Binding(get: { store.category }, set: { if let c = $0 { store.select(c) } })) {
                Text($0.rawValue).tag($0)
            }
            .navigationSplitViewColumnWidth(200)
        } detail: {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: thumb), spacing: 6)], spacing: 6) {
                        ForEach(store.batch, id: \.localIdentifier) { a in
                            Thumb(asset: a, manager: store.manager, marked: store.marked.contains(a.localIdentifier), size: thumb)
                                .onTapGesture { store.toggle(a) }
                                .contextMenu { Button("Preview") { store.preview = a } }
                        }
                    }
                    .padding(8)
                }
                Divider()
                HStack {
                    Text(store.status).foregroundStyle(.secondary)
                    Spacer()
                    Button { thumb = max(80, thumb - 40) } label: { Image(systemName: "minus.magnifyingglass") }
                        .keyboardShortcut("-", modifiers: .command)
                    Slider(value: $thumb, in: 80...480).frame(width: 140)
                    Button { thumb = min(480, thumb + 40) } label: { Image(systemName: "plus.magnifyingglass") }
                        .keyboardShortcut("=", modifiers: .command)
                    Button("Mark All") { store.markAll() }
                    Button("Clear") { store.marked.removeAll() }
                    Button(store.marked.isEmpty ? "Keep All – Next 100" : "Delete \(store.marked.count) – Next 100") {
                        store.finishBatch()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(store.marked.isEmpty ? .accentColor : .red)
                    .disabled(store.batch.isEmpty)
                }
                .padding(10)
            }
            .navigationTitle(store.category.rawValue)
            .toolbar {
                Menu("More") { Button("Show kept photos again (reset)") { store.resetKept() } }
            }
        }
        .sheet(item: Binding(get: { store.preview.map { PreviewItem(asset: $0) } }, set: { store.preview = $0?.asset })) { p in
            VStack {
                Thumb(asset: p.asset, manager: store.manager, marked: false, size: 700)
                Button("Close") { store.preview = nil }.keyboardShortcut(.cancelAction)
            }.padding()
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear { store.start() }
    }
}

struct PreviewItem: Identifiable { let asset: PHAsset; var id: String { asset.localIdentifier } }

@main
struct PhotoSweepApp: App {
    var body: some Scene { WindowGroup("PhotoSweep") { ContentView() } }
}
