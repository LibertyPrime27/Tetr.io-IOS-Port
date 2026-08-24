import AVFoundation

/// Why game audio goes missing in a WKWebView wrapper, and what fixes it.
///
/// Two separate things have to be true before you hear anything:
///
/// 1. The app's audio session must be a category that actually plays. The
///    default (`soloAmbient`) is silenced by the ring/silent switch, so a muted
///    device means a silent game even though the page is happily producing
///    audio. `.playback` keeps sound on regardless of that switch.
///
/// 2. WebKit must have unlocked WebAudio. iOS starts every `AudioContext`
///    suspended until a *genuine* user gesture arrives — and the overlay's
///    synthetic key events are `isTrusted: false`, so they do not count. The
///    page-side unlock in `GameWebView` handles that half.
enum AudioSession {

    static func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            NSLog("[Audio] session setup failed: \(error.localizedDescription)")
        }
    }

    /// Re-assert the session after an interruption or a trip to the background.
    static func reactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            NSLog("[Audio] reactivate failed: \(error.localizedDescription)")
        }
    }
}
