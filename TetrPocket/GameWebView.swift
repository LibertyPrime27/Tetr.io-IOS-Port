import SwiftUI
import WebKit

/// Owns the web view and injects key events into the page.
final class WebViewProxy: ObservableObject {
    weak var webView: WKWebView?

    /// Prebuilt JS for every key press and release. Built once instead of
    /// interpolating a string on every button press.
    private static let dispatch: [String: (down: String, up: String)] = {
        var map: [String: (down: String, up: String)] = [:]
        for key in GameKey.allCases {
            let args = "'\(key.code)','\(key.keyValue)',\(key.keyCode)"
            map[key.rawValue] = (down: "__tp('keydown',\(args))",
                                 up: "__tp('keyup',\(args))")
        }
        return map
    }()

    private var didUnlockAudio = false

    func send(_ key: GameKey, down: Bool) {
        guard let js = Self.dispatch[key.rawValue] else { return }
        webView?.evaluateJavaScript(down ? js.down : js.up, completionHandler: nil)

        // First real interaction is the moment WebKit will accept an audio
        // unlock, so piggyback on it once and never pay for it again.
        if down && !didUnlockAudio {
            didUnlockAudio = true
            unlockAudio()
        }
    }

    /// Full press for menu actions.
    func tap(_ key: GameKey) {
        send(key, down: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            self?.send(key, down: false)
        }
    }

    func unlockAudio() {
        webView?.evaluateJavaScript("__tpUnlock && __tpUnlock()", completionHandler: nil)
    }

    func reload() {
        webView?.reload()
    }

    /// Release everything — used when entering edit mode so a key can't stick down.
    func releaseAll() {
        for key in GameKey.allCases where !key.isTapOnly {
            send(key, down: false)
        }
    }
}

struct GameWebView: UIViewRepresentable {
    @ObservedObject var proxy: WebViewProxy
    let adBlockEnabled: Bool
    let zoom: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(proxy: proxy)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let proxy: WebViewProxy

        init(proxy: WebViewProxy) {
            self.proxy = proxy
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Contexts created during load start suspended; nudge them now and
            // again on the first button press.
            proxy.unlockAudio()
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Persistent store so the TETR.IO login survives relaunches.
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        config.preferences.isFraudulentWebsiteWarningEnabled = false
        config.dataDetectorTypes = []

        // Ask for the desktop site properly, not just via the user-agent string.
        config.defaultWebpagePreferences.preferredContentMode = .desktop

        config.userContentController.addUserScript(Self.bootstrapScript())

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Opaque with a black backdrop: no per-frame blending against the host
        // view, and no white flash on load.
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.underPageBackgroundColor = .black

        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.maximumZoomScale = 1
        webView.scrollView.minimumZoomScale = 1
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.pageZoom = zoom

        // TETR.IO turns away mobile browsers, so present as desktop Safari.
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

        proxy.webView = webView

        let load = { [weak webView] in
            guard let webView, let url = URL(string: "https://tetr.io") else { return }
            webView.load(URLRequest(url: url))
        }

        if adBlockEnabled {
            AdBlock.compile { list in
                if let list {
                    webView.configuration.userContentController.add(list)
                }
                load()
            }
        } else {
            load()
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Zoom applies live; ad-block rules attach at creation, so that one waits
        // for the next launch.
        if abs(webView.pageZoom - zoom) > 0.001 {
            webView.pageZoom = zoom
        }
    }

    /// Page-side setup: the key-event helper, the WebAudio unlock, and input
    /// hygiene that keeps touch latency down.
    ///
    /// Deliberately *not* here: rewriting the viewport meta tag. Forcing
    /// `width=device-width` fights the desktop content mode the game is being
    /// served under, which pushes it through a different layout path for no gain.
    private static func bootstrapScript() -> WKUserScript {
        let source = """
        (function () {
          window.__tp = function (type, code, key, keyCode) {
            var e = new KeyboardEvent(type, {
              code: code, key: key, keyCode: keyCode, which: keyCode,
              bubbles: true, cancelable: true
            });
            document.dispatchEvent(e);
            window.dispatchEvent(e);
            if (document.activeElement) { document.activeElement.dispatchEvent(e); }
          };

          // --- WebAudio unlock -------------------------------------------------
          // Track every AudioContext the page makes so they can be resumed. iOS
          // creates them suspended and only a trusted gesture lifts that, which
          // synthetic key events are not.
          var AC = window.AudioContext || window.webkitAudioContext;
          window.__tpCtxs = [];
          if (AC) {
            var Tracked = function (opts) {
              var ctx = new AC(opts);
              window.__tpCtxs.push(ctx);
              return ctx;
            };
            Tracked.prototype = AC.prototype;
            window.AudioContext = Tracked;
            if (window.webkitAudioContext) { window.webkitAudioContext = Tracked; }
          }

          window.__tpUnlock = function () {
            var list = window.__tpCtxs || [];
            for (var i = 0; i < list.length; i++) {
              var c = list[i];
              if (c && c.state === 'suspended' && c.resume) {
                try { c.resume(); } catch (e) {}
              }
            }
          };

          // A real touch anywhere on the board also unlocks audio.
          ['touchend', 'pointerup', 'click'].forEach(function (t) {
            document.addEventListener(t, window.__tpUnlock, true);
          });

          // --- input hygiene ---------------------------------------------------
          var css = document.createElement('style');
          css.textContent =
            'html,body{overscroll-behavior:none!important;touch-action:none!important;}' +
            '*{-webkit-touch-callout:none!important;-webkit-user-select:none!important;' +
            '-webkit-tap-highlight-color:transparent!important;}';
          (document.head || document.documentElement).appendChild(css);
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }
}
