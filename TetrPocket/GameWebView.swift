import SwiftUI
import WebKit

/// Bridge object the touch controls use to fire key events into the page.
final class WebViewProxy: ObservableObject {
    weak var webView: WKWebView?

    /// Dispatch a synthetic keyboard event into the page.
    /// TETR.IO reads `event.code`, so that's the important field.
    func sendKey(_ key: GameKey, down: Bool) {
        let type = down ? "keydown" : "keyup"
        let js = """
        (function() {
            var e = new KeyboardEvent('\(type)', {
                code: '\(key.code)',
                key: '\(key.key)',
                keyCode: \(key.keyCode),
                which: \(key.keyCode),
                bubbles: true,
                cancelable: true
            });
            document.dispatchEvent(e);
            window.dispatchEvent(e);
        })();
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func reload() {
        webView?.reload()
    }
}

/// TETR.IO default keybinds.
enum GameKey {
    case left, right, softDrop, hardDrop, rotateCCW, rotateCW, rotate180, hold, escape, retry

    var code: String {
        switch self {
        case .left:      return "ArrowLeft"
        case .right:     return "ArrowRight"
        case .softDrop:  return "ArrowDown"
        case .hardDrop:  return "Space"
        case .rotateCCW: return "KeyZ"
        case .rotateCW:  return "ArrowUp"
        case .rotate180: return "KeyA"
        case .hold:      return "KeyC"
        case .escape:    return "Escape"
        case .retry:     return "KeyR"
        }
    }

    var key: String {
        switch self {
        case .left:      return "ArrowLeft"
        case .right:     return "ArrowRight"
        case .softDrop:  return "ArrowDown"
        case .hardDrop:  return " "
        case .rotateCCW: return "z"
        case .rotateCW:  return "ArrowUp"
        case .rotate180: return "a"
        case .hold:      return "c"
        case .escape:    return "Escape"
        case .retry:     return "r"
        }
    }

    var keyCode: Int {
        switch self {
        case .left:      return 37
        case .right:     return 39
        case .softDrop:  return 40
        case .hardDrop:  return 32
        case .rotateCCW: return 90
        case .rotateCW:  return 38
        case .rotate180: return 65
        case .hold:      return 67
        case .escape:    return 27
        case .retry:     return 82
        }
    }
}

struct GameWebView: UIViewRepresentable {
    @ObservedObject var proxy: WebViewProxy

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // persistent — stay logged in
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true

        // Kill long-press callouts / text selection so the overlay feels like buttons
        let css = """
        var style = document.createElement('style');
        style.innerHTML = '* { -webkit-touch-callout: none !important; -webkit-user-select: none !important; }';
        document.head.appendChild(style);
        """
        let script = WKUserScript(source: css, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false

        // Desktop UA — TETR.IO refuses/limits mobile browsers
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

        proxy.webView = webView
        webView.load(URLRequest(url: URL(string: "https://tetr.io")!))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
