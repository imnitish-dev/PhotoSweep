# PhotoSweep

A tiny macOS app for cleaning up a big Photos library, 100 pictures at a time.

- Categories: **Screenshots**, **WhatsApp & Saved images**, **Videos (longest first)**, **All Photos**
- Favorites (♡) are never shown, so they can't be deleted by accident
- Click a photo to open it full-size:
  **⌫ Delete** marks it for deletion, **Space** keeps it, **← →** move, **Esc** closes
- **⌘-click** in the grid marks a photo; **Mark All**, then un-mark keepers, for bulk junk
- Zoom the grid with the slider or **⌘+ / ⌘−**
- **Delete – Next 100** (⌘↩) applies the marks and loads the next batch
- Marked photos go to **Recently Deleted** in Photos (recoverable for 30 days)
- Photos you keep are remembered and never shown again
- Works with iCloud Photos, so deletions sync to your iPhone

## Install (macOS 14+)

1. Download **PhotoSweep.dmg** from [Releases](https://github.com/imnitish-dev/PhotoSweep/releases/latest).
2. Open it and drag **PhotoSweep** into **Applications**.
3. Open PhotoSweep. macOS blocks it the first time because it isn't signed with an Apple Developer ID:
   go to **System Settings → Privacy & Security**, scroll down, click **Open Anyway**.
   (Or in Terminal: `xattr -dr com.apple.quarantine /Applications/PhotoSweep.app`)
4. Allow **Full Access** when macOS asks for Photos permission.

### Build from source

Needs the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/imnitish-dev/PhotoSweep
cd PhotoSweep
./build.sh          # → build/PhotoSweep.app
./build.sh dmg      # → also build/PhotoSweep.dmg
```

## Releasing a new version

```sh
./build.sh dmg
gh release create v1.1 build/PhotoSweep.dmg --title "PhotoSweep 1.1" --notes "What changed"
```

### Why the "Open Anyway" step?

The app is not notarized by Apple. Removing that step needs the paid
[Apple Developer Program](https://developer.apple.com/programs/) ($99/year) for a
**Developer ID Application** certificate, then:

```sh
SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./build.sh dmg
xcrun notarytool submit build/PhotoSweep.dmg --apple-id you@example.com --team-id TEAMID --wait
xcrun stapler staple build/PhotoSweep.dmg
```

## Reset

"More → Show kept photos again" clears the kept list
(stored in `~/Library/Application Support/PhotoSweep/kept.json`).
