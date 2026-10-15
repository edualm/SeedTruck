# Store screenshots

App Store screenshots are generated, not made by hand. Each shot is a DEBUG-only showcase scene
(`Shared/Utilities/Showcase.swift`): the app opens straight to a prepared moment with a sample seedbox, served by
an in-memory connection instead of the network and kept out of the Keychain, and logs each step. Scripts capture
each scene once its log says it's done. Release builds contain none of it.

    scripts/store/capture.sh [iphone|ipad|duo|mac|watch|duo-folded|all] [--only <id or scene>] [--skip-build]
    scripts/store/frame.sh [--only <pattern>] [--edit]

| Step | Writes | Notes |
| --- | --- | --- |
| `capture.sh` | `store-assets/raw/<platform>/<id>.png` | iPhone 18 Pro Max 1320 x 2868; iPad Pro 13" landscape 2752 x 2064; iPhone Duo inner screen, landscape, 2853 x 2007, and outer screen, folded, 1398 x 2034; Mac window 1700 x 1200 (Settings with its sheet 1080 x 1026); Apple Watch Ultra 3 422 x 514 |
| `frame.sh` | `store-assets/final/<platform>/NN.png` | Backdrop, device frame, title, and subtitle by screenshot-maker: iPhone 1320 x 2868, iPad 2732 x 2048, Duo 2007 x 2853 (folded, first) and 2853 x 2007 (open), Mac 2560 x 1600, Watch 422 x 514 |

`store-assets/` is ignored, except `store-assets/banners/` (from `scripts/store/banners.sh`). Every step checks
its output's size. Captures repeat exactly.

- **Settings:** `scripts/store/store.json`: bundle ID, schemes, platforms, simulator types, and sizes.
- **Shots:** `scripts/store/shots.json` lists each platform's shots in order. `scripts/store/screenshots.json` gives
  each its title and subtitle; `scripts/store/templates/` holds the looks (dark gradient, SF Pro captions).
- **Fixture:** `scripts/store/fixtures/seedbox.json`: the server (My Server), the four torrents of
  `Tools/mockserver` in Transmission's `torrent_get` format (parsed by the app's own Transmission model), the
  server's labels and speed limits, and the Ubuntu torrent file the add scene opens. Every shot uses it.
- **Simulators:** the scripts create and use their own "Seed Truck Store …" simulators, in English (US), with
  Apple's 9:41 status bar. The iPad and open Duo shots hide the status bar (`--hide-status-bar`), as the originals did.
  The watch takes no status bar override, so its clock is painted out (`statusBarPatch`).
- **iPhone Duo:** no script can open or fold a Duo; DeviceHub's hinge is the only control. `duo` captures the open
  inner screen: drag the hinge fully open, and the showcase turns the app to landscape, where the torrent list and
  details show side by side. `duo-folded` captures the outer screen (the set's first shot), so fold it first. Both
  use the same "Seed Truck Store Duo" simulator and stop with a note if it's in the wrong state, so `all`, which
  runs `duo-folded` last, captures everything else and then asks for the fold.
- **Mac:** the app opens in an 850 x 600 window, its default size, captured with ScreenCaptureKit along with any
  sheet over it. The terminal needs Screen Recording permission once.
- **screenshot-maker:** `frame.sh` expects a checkout beside this repository; `SCREENSHOT_MAKER=<path>` points
  elsewhere. To change the look, run `scripts/store/frame.sh --edit`, open a shot from **Open job…**, adjust it,
  and **Save Preset** over its template or **Copy shot changes** into that shot.

Showcase launch arguments, all DEBUG-only:

| Argument or variable | Effect |
| --- | --- |
| `--showcase <scene>` | Stages a scene: `list` (the torrent list), `details` (the fixture's selected torrent), `add` (Add Torrent for the fixture's file, as when opening it from Files or the Finder), `limits` (the server's speed limits) |
| `--showcase-log <file>` | Writes JSON lines `{t, wall, event}`: `launched`, `ready`, `done`, or `failed: <reason>` |
| `--showcase-landscape` | iPad and open iPhone Duo: turns to landscape (the capture build sets `UIRequiresFullScreen`) |
| `--showcase-window 850x600` | Mac: the main window's content size |
| `--showcase-appearance dark` | Mac: light or dark (simulators are switched by the scripts) |
| `SHOWCASE_STATE` | Base64 of the fixture's state |
| `SHOWCASE_SESSION` | Set on every scripted launch |
