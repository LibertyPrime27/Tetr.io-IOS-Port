# TETR.IO iOS Port (TetrPocket)

A personal iOS wrapper for [TETR.IO](https://tetr.io) — the real game, running fullscreen
in a native app with touch controls, since TETR.IO has no official mobile version.

> **Personal use only.** TETR.IO and all its content belong to [osk](https://osk.sh).
> This repo is private and its builds are never distributed. It adds no gameplay
> advantage — the touch overlay just presses the game's normal keys.

## How it works

- A SwiftUI app hosting a fullscreen **WKWebView** pointed at `https://tetr.io`
- **Desktop Safari user-agent** (TETR.IO blocks mobile browsers), persistent cookies so
  you stay logged in, screen kept awake, scrolling and text selection disabled
- A **native touch overlay** that dispatches TETR.IO's default keybinds as synthetic
  key events into the page
- **GitHub Actions** compiles an unsigned IPA on a macOS runner on every push to `main`
  and pins it to the [`latest` release](../../releases/tag/latest)

## Touch controls

| Button | Action | Key sent |
|--------|--------|----------|
| ◀ ▶ | Move (hold for DAS) | ← / → |
| ▼ | Soft drop | ↓ |
| ⤓ | Hard drop | Space |
| ↺ / ↻ | Rotate CCW / CW | Z / ↑ |
| 180 | Rotate 180° | A |
| H | Hold | C |
| ESC / R / ⟳ | Menu back / retry / reload page | Esc / R / — |
| ✕ / 🎮 | Hide / show the overlay | — |

Keep TETR.IO's in-game keybinds at their **defaults** — the overlay maps to them.
If you've customized binds, either reset them or edit the `GameKey` enum in
[`TetrPocket/GameWebView.swift`](TetrPocket/GameWebView.swift).
A Bluetooth keyboard works too: hide the overlay with ✕ and play normally.

## Getting a build on your iPhone

1. Push any change to `main` (or run the workflow manually from the **Actions** tab)
2. Wait ~5–8 minutes for the **Build IPA** workflow to finish
3. Download `TetrPocket.ipa` from the [latest release](../../releases/tag/latest)
4. Sideload it with [Sideloadly](https://sideloadly.io) (Windows/macOS) or
   [AltStore](https://altstore.io): plug in the iPhone, feed it the IPA, sign in with
   your Apple ID
5. On the phone: **Settings → General → VPN & Device Management** → trust your
   certificate. iOS 16+: also enable **Developer Mode** under Privacy & Security

With a free Apple ID the signature lasts **7 days** — re-sideload to refresh
(AltStore can automate this). A paid developer account extends it to a year.

Have a Mac? You can skip the IPA entirely: open `TetrPocket.xcodeproj` in Xcode 16+,
set your team under *Signing & Capabilities*, and hit Run with your phone connected.

## Updating

Edit → commit → push. The workflow rebuilds the IPA and replaces the one on the
`latest` release automatically. Then re-sideload the new IPA.

## Troubleshooting

- **Stutters or low FPS** — lower the graphics preset in TETR.IO's own settings; the
  game is heavy WebGL and older devices struggle
- **"Browser not supported" screen** — the desktop user-agent usually avoids this;
  if it appears, look for a "proceed anyway" option or tap ⟳
- **Buttons do nothing** — the page may still be loading, or your in-game keybinds
  differ from the defaults (see above)
- **Build fails in Actions** — open the failed run's log; the `xcodebuild` step output
  says what broke

## Project layout

```
TetrPocket/               SwiftUI app source
  GameWebView.swift       WKWebView setup + key-event bridge (edit keybinds here)
  TouchControls.swift     The touch overlay
  ContentView.swift       Composition root
TetrPocket.xcodeproj/     Xcode project (Xcode 16+, iOS 17+)
.github/workflows/        CI: unsigned IPA build + release upload
```
