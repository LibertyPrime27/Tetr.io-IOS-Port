# TETR.IO iOS Port

An iOS wrapper for [TETR.IO](https://tetr.io) — the real game, running fullscreen in a
native app with fully customizable touch controls, native ad blocking, and hardware
keyboard and mouse support. TETR.IO has no official mobile version; this fills that gap.

> **Unofficial and unaffiliated.** Not affiliated with, authorized, or endorsed by
> [osk](https://osk.sh), TETR.IO, or The Tetris Company. TETR.IO and all its content
> belong to their respective owners.
>
> This repository contains **no game code, assets, or artwork** — it is a WebView shell
> that loads `tetr.io`, so you play the live official game with your own account, subject
> to TETR.IO's own terms of service. The app icon is original work made for this project.
> The touch overlay presses the game's normal keys and confers no gameplay advantage.
> Builds here are **unsigned**: you sign them yourself with your own Apple ID.

## Features

- **Fully customizable controls** — drag any button anywhere, resize it (40–160 pt), and
  set its opacity. Layouts persist across launches and adapt to rotation and screen size,
  because positions are stored as screen fractions rather than pixels.
- **Native ad blocking** — a `WKContentRuleList` (the same engine Safari content blockers
  use) drops ad requests in the networking layer, so they never reach the page. This is
  far cheaper than a JavaScript loop scrubbing the DOM, and it removes the ad *load* —
  the actual source of stutter — rather than just hiding the result. Toggleable.
- **Hardware keyboard and mouse** — key events reach the page directly, and pointer
  events are delivered as mouse input. The overlay auto-hides the first time a keyboard
  connects, and the controller icon in the HUD brings it back.
- **Tuned for performance** — 120 Hz unlocked on ProMotion displays, opaque compositing,
  no tap delay or rubber-banding, desktop content mode, persistent login.

## Controls

Defaults match TETR.IO's own default binds:

| Button | Action | Key sent |
|--------|--------|----------|
| ◀ ▶ | Move (hold for DAS) | ← / → |
| ▼ | Soft drop | ↓ |
| ⤓ | Hard drop | Space |
| ↺ / ↻ | Rotate CCW / CW | Z / ↑ |
| 180 | Rotate 180° | A |
| H | Hold | C |
| ESC / R | Menu back / retry | Esc / R |

If you've customized your binds in TETR.IO, either reset them to defaults or edit the
`GameKey` enum in [`TetrPocket/ControlModel.swift`](TetrPocket/ControlModel.swift).

**To rearrange:** tap the slider icon in the top-left HUD, drag buttons where you want
them, tap one to resize or fade it, then tap **Done**. There's a reset in the panel.

## Install

1. Download `Tetr.io-iOS-Port.ipa` from the [latest release](../../releases/tag/latest)
2. Sideload with [Sideloadly](https://sideloadly.io) or [AltStore](https://altstore.io):
   plug in the device, feed it the IPA, sign in with your Apple ID
3. On the device: **Settings → General → VPN & Device Management** → trust your
   certificate. iOS 16+: also enable **Developer Mode** under Privacy & Security

A free Apple ID signature lasts **7 days** — re-sideload to refresh (AltStore can
automate it). A paid developer account extends it to a year.

Have a Mac? Skip the IPA: open `TetrPocket.xcodeproj` in Xcode 16+, set your team under
*Signing & Capabilities*, and Run with the device connected.

## Building

Every push to `main` triggers the **Build IPA** workflow, which compiles on a macOS
runner, sanity-checks the bundle (architecture, Info.plist keys, compiled icon), and
replaces the IPA on the `latest` release. No Mac needed to get a build.

## Supporting the game

Ad blocking here is a client-side choice, and osk has [said publicly](https://blog.osk.sh/post.php?p=5f9dfef7f36858.79227265)
that TETR.IO won't complain about adblockers. If you play a lot, TETR.IO SUPPORTER
removes ads officially and the money actually reaches the developer — this toggle
does not.

## Troubleshooting

- **Stutters or low FPS** — lower the graphics preset in TETR.IO's own settings; it's a
  heavy WebGL game and older devices struggle regardless of what the wrapper does
- **"Browser not supported"** — the desktop user-agent and content mode normally avoid
  this; if it appears, look for a proceed option or tap reload in the HUD
- **Buttons do nothing** — the page may still be loading, or your in-game binds differ
  from the defaults
- **Ad-block toggle seems inert** — content rule lists attach at web-view creation, so
  it takes effect on the next launch
- **Build fails in Actions** — open the failed run; the sanity-check step names what's
  missing

## Project layout

```
Info.plist                  Explicit bundle config (120 Hz, orientations, display name)
TetrPocket/
  TetrPocketApp.swift       App entry
  ContentView.swift         Composition + hardware-keyboard detection
  GameWebView.swift         WKWebView setup, key-event bridge, page bootstrap
  ControlModel.swift        Keys, button model, persistence, default layouts
  TouchControls.swift       Draggable overlay + HUD
  EditPanel.swift           Size / opacity / toggles / reset
  AdBlock.swift             Content-rule-list rules
TetrPocket.xcodeproj/       Xcode project (Xcode 16+, iOS 17+)
.github/workflows/          CI: unsigned IPA build, verification, release upload
```
