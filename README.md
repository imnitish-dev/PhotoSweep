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

## Install

Requires macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/imnitish-dev/PhotoSweep
cd PhotoSweep
./build.sh
open build/PhotoSweep.app
```

Allow **Full Access** when macOS asks for Photos permission.

### Using a downloaded release instead

The app isn't signed with an Apple Developer ID, so macOS will block it the first time.
Right-click the app → **Open** → **Open**, or run:

```sh
xattr -dr com.apple.quarantine PhotoSweep.app
```

## Reset

"More → Show kept photos again" clears the kept list
(stored in `~/Library/Application Support/PhotoSweep/kept.json`).
