# Port for TETR.IO — iOS

An iOS wrapper for [TETR.IO](https://tetr.io) — the real game, running fullscreen in a
native app with fully customizable touch controls, adjustable board zoom, working audio,
native ad blocking, and hardware keyboard and mouse support. TETR.IO has no official
mobile version; this fills that gap.

> **Unofficial and unaffiliated.** Not affiliated with, authorized, or endorsed by
> [osk](https://osk.sh), TETR.IO, or The Tetris Company.
>
> TETR.IO and its logo are property of osk. The logo is used here under osk's
> [branding terms](https://txt.osk.sh/branding/), unmodified and without any claim of
> affiliation — which is also why this is named "Port **for** TETR.IO" rather than
> "TETR.IO Port": those terms allow the former pattern and disallow the latter, since a
> leading trademark reads as an official product.
>
> This repository contains **no game code or assets**. It is a WebView shell that loads
> `tetr.io`, so you play the live official game with your own account, subject to
> TETR.IO's terms of service. The touch overlay presses the game's normal keys and
> confers no gameplay advantage. Builds are **not distribution-signed**: you sign them
> yourself with your own Apple ID.

## Features

- **Fully customizable controls** — drag any button anywhere, resize it (40–170 pt), set
  its opacity. Arrangements save automatically and are kept **separately per device class
  and orientation**, so an iPhone-portrait layout can't wreck your iPad-landscape one.
- **Adjustable board zoom** (80–200%) — a live slider in the settings panel. Because
  zooming shrinks the CSS viewport, the game lays out across fewer pixels, so a bigger
  board is also a *cheaper* frame. It's the single most effective performance control here.
- **Working audio** — see [Audio](#audio) for why a plain WebView wrapper is silent and
  what this does about it.
- **Native ad blocking** — a `WKContentRuleList` (the engine behind Safari content
  blockers) drops ad requests in the networking layer, so they never load. Far cheaper
  than a JavaScript loop scrubbing the DOM, and it removes the ad *load* — the actual
  source of stutter — rather than just hiding the result. Toggleable.
- **Hardware keyboard and mouse** — key events reach the page directly and pointer events
  arrive as mouse input. The overlay auto-hides the first time a keyboard connects; the
  controller icon in the HUD brings it back.
- **Tuned per device** — 120 Hz unlocked on ProMotion displays, opaque compositing, no tap
  delay, desktop content mode, persistent login. Haptics default on for iPhone, off for
  iPad, which has no haptic engine.

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

**Settings and rearranging:** tap the slider icon in the top-left HUD. Board zoom is at
the top of the panel; drag buttons to move them, tap one to resize or fade it, then tap
**Done**. Reset restores defaults for the current orientation only.

## Audio

Two independent things have to be true before a WebView wrapper makes any sound, and
both are handled:

1. **The audio session.** The default category (`soloAmbient`) is silenced by the
   ring/silent switch, so a muted device means a silent game even though the page is
   producing audio normally. The app sets `.playback`, which plays regardless of that
   switch, and re-asserts it when returning from the background.
2. **The WebAudio unlock.** iOS creates every `AudioContext` suspended until a *genuine*
   user gesture arrives — and the overlay's synthetic key events are `isTrusted: false`,
   so they don't qualify. The app tracks the contexts the page creates and resumes them
   on load, on the first button press, and on any real touch.

If it's still silent: tap the board once (a real touch is the strongest unlock signal),
check the device isn't in Do Not Disturb with audio routed elsewhere, and confirm volume
is up while the app is foregrounded — the volume you set applies to the active session.

## Performance

The dominant cost is TETR.IO's own WebGL rendering, which a wrapper can't optimize away.
What it *can* do:

- **Raise the board zoom.** Fewer CSS pixels to lay out means fewer physical pixels to
  render. Try 130–150% before anything else.
- **Lower TETR.IO's own graphics preset** in the game's settings.
- **The 120 Hz unlock is a trade-off.** `CADisableMinimumFrameDuration` in `Info.plist`
  lets the app render above 60 fps on ProMotion displays — good if the device can sustain
  it, but on hardware that can only manage ~70–90 fps the uneven pacing can feel *worse*
  than a steady 60. If motion looks juddery rather than slow, delete that key and rebuild.

Also trimmed in 3.0: the injected viewport override was removed (it fought the desktop
content mode the game is served under, forcing a different layout path for no benefit),
and key-dispatch JavaScript is now prebuilt per key rather than assembled on every press.

## Install

Grab `Tetr.io-iOS-Port.ipa` from the [latest release](../../releases/latest), then pick a
route:

**Sideloadly / AltStore** — plug in the device, feed it the IPA, sign in with your Apple
ID. Then on the device: **Settings → General → VPN & Device Management** → trust your
certificate. On iOS 16+ also enable **Developer Mode** under Privacy & Security. A free
Apple ID signature lasts 7 days; AltStore can refresh it automatically.

**LiveContainer** — import the IPA as a guest app. The build is ad-hoc signed so
LiveContainer's re-signer has a well-formed signature to work from.

**Xcode** — no IPA needed: open `TetrPocket.xcodeproj` in Xcode 16+, set your team under
*Signing & Capabilities*, and Run with the device connected.

### If LiveContainer says the code signature is invalid

The message *"signed with the latest certificate but its code signature is invalid"*
comes from LiveContainer's JIT-less signing, before any of this app's code runs, so it is
usually about the signing environment rather than the IPA:

1. Open LiveContainer's **JIT-Less Diagnose** page and check whether your certificate
   reads as **Revoked** or expired — a revoked cert is the most common cause, and
   [the upstream issue tracker](https://github.com/LiveContainer/LiveContainer/issues/521)
   shows exactly this symptom across every app a user tried.
2. Refresh AltStore / SideStore so a fresh certificate is issued, then re-import.
3. In the guest app's settings, use **Force re-sign**.
4. Confirm JIT-Less mode is set up per LiveContainer's own docs.

This build helps on its side by shipping a valid ad-hoc signature and leaving Mach-O
header padding (`-headerpad`) so a re-signer can insert its load commands without
rewriting the image. A fully unsigned binary has no code-signature slot at all, which is
what builds before 2.0 got wrong.

## Building and releasing

- **Push to `main`** → CI builds, ad-hoc signs, verifies the bundle (architecture,
  Info.plist keys, compiled icon, signature present) and uploads a build artifact.
  It does **not** touch any release.
- **Push a tag `vX.Y`** → same build, plus its own GitHub release carrying the IPA.

```bash
git tag v3.1 && git push origin v3.1
```

## Supporting the game

Ad blocking here is a client-side choice, and osk has
[said publicly](https://blog.osk.sh/post.php?p=5f9dfef7f36858.79227265) that TETR.IO
won't complain about adblockers. If you play a lot, TETR.IO SUPPORTER removes ads
officially and the money actually reaches the developer — this toggle does not.

## Troubleshooting

- **No sound** — see [Audio](#audio) above
- **Choppy** — see [Performance](#performance) above
- **"Browser not supported"** — the desktop user-agent and content mode normally avoid
  this; if it appears, look for a proceed option or tap reload in the HUD
- **Buttons do nothing** — the page may still be loading, or your in-game binds differ
  from the defaults
- **Ad-block toggle seems inert** — content rule lists attach when the web view is
  created, so it applies on next launch. Zoom, by contrast, applies immediately
- **Controls in the wrong place after rotating** — each orientation has its own layout;
  arrange it once per orientation
- **Build fails in CI** — open the failed run; the verify step names what's missing

## Project layout

```
Info.plist                  Bundle config (120 Hz, orientations, display name)
Signing/adhoc.entitlements  Entitlements applied by CI's ad-hoc signing
TetrPocket/
  TetrPocketApp.swift       App entry, audio session setup
  ContentView.swift         Composition, orientation slots, keyboard detection
  GameWebView.swift         WKWebView setup, key bridge, audio unlock, zoom
  AudioSession.swift        AVAudioSession category and reactivation
  ControlModel.swift        Keys, button model, per-slot persistence, zoom, defaults
  TouchControls.swift       Draggable overlay + HUD
  EditPanel.swift           Zoom / size / opacity / toggles / reset
  AdBlock.swift             Content-rule-list rules
TetrPocket.xcodeproj/       Xcode project (Xcode 16+, iOS 17+)
.github/workflows/          CI: build, ad-hoc sign, verify, tag-triggered release
```
