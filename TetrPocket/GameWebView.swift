import SwiftUI
import WebKit

/// Owns the web view and injects key events into the page.
final class WebViewProxy: ObservableObject {
    weak var webView: WKWebView?

    /// Press or release a key. The page-side helper is installed once as a user
    /// script, so each call ships only a short function invocation instead of a
    /// full event-construction blob — less to parse on the hot path.
    func send(_ key: GameKey, down: Bool) {
        let js = "__tp('\(down ? "keydown" : "keyup")','\(key.code)','\(key.keyValue)',\(key.keyCode))"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Full press for menu actions.
    func tap(_ key: GameKey) {
        send(key, down: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            self?.send(key, down: false)
        }
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

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Persistent store so the TETR.IO login survives relaunches.
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        config.suppressesIncrementalRendering = false

        // Ask for the desktop site properly, not just via the user-agent string.
        config.defaultWebpagePreferences.preferredContentMode = .desktop

        config.userContentController.addUserScript(Self.bootstrapScript())

        let webView = WKWebView(frame: .zero, configuration: config)

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
        // Ad-block changes are applied on next launch; nothing to do per-update.
    }

    /// Page-side setup: the key-event helper plus input hygiene that keeps touch
    /// latency down (no tap delay, no callouts, no rubber-banding).
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

          var css = document.createElement('style');
          css.textContent =
            'html,body{overscroll-behavior:none!important;touch-action:none!important;}' +
            '*{-webkit-touch-callout:none!important;-webkit-user-select:none!important;' +
            '-webkit-tap-highlight-color:transparent!important;}';
          (document.head || document.documentElement).appendChild(css);

          var vp = document.querySelector('meta[name=viewport]');
          if (!vp) {
            vp = document.createElement('meta');
            vp.name = 'viewport';
            (document.head || document.documentElement).appendChild(vp);
          }
          vp.content = 'width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover';
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }
}
