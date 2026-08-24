import WebKit

/// Native ad blocking via WKContentRuleList — the same engine Safari content
/// blockers use. Rules are compiled once and enforced in the networking layer,
/// so blocked requests never hit the page. That is dramatically cheaper than a
/// JavaScript loop polling the DOM, and it removes the ad *load* (the actual
/// source of stutter) rather than just hiding the result.
///
/// osk has said publicly that TETR.IO does not mind adblockers. If you want to
/// support the game's servers, TETR.IO SUPPORTER removes ads officially and the
/// money reaches the developer — this toggle does not.
enum AdBlock {

    static let identifier = "tetrport-adblock-v2"

    /// Ad/tracking hosts serving TETR.IO's ad slots.
    private static let blockedDomains = [
        "googlesyndication.com",
        "doubleclick.net",
        "googleadservices.com",
        "googletagservices.com",
        "adservice.google.com",
        "adsystem.com",
        "adnxs.com",
        "amazon-adsystem.com",
        "rubiconproject.com",
        "pubmatic.com",
        "openx.net",
        "criteo.com",
        "taboola.com",
        "outbrain.com",
    ]

    /// Precise selectors only. Broad patterns like `[class*="ad"]` are a trap —
    /// they also match "loading", "header", "shadow", "download" and friends,
    /// which quietly dismantles the game's own UI.
    private static let cosmeticSelectors = [
        "ins.adsbygoogle",
        ".adsbygoogle",
        "iframe[src*=\"googlesyndication\"]",
        "iframe[src*=\"doubleclick\"]",
        "iframe[id^=\"google_ads\"]",
        "div[id^=\"google_ads\"]",
        "div[id^=\"div-gpt-ad\"]",
        "[data-google-query-id]",
        "#ad-bottom",
        ".ad-slot",
        ".ad-container",
        ".ad-banner",
        ".ad-rectangle",
        ".ads-frame",
        ".google-ads",
    ].joined(separator: ", ")

    /// Build the rule list JSON. Uses JSONSerialization so regex escaping can't
    /// be fumbled by hand.
    private static func ruleListJSON() -> String? {
        var rules: [[String: Any]] = blockedDomains.map { domain in
            let escaped = domain.replacingOccurrences(of: ".", with: "\\.")
            return [
                "trigger": [
                    "url-filter": "^[^:]+://([^/]+\\.)?\(escaped)[/:]"
                ],
                "action": ["type": "block"],
            ]
        }

        // Collapse any leftover ad containers so they don't reserve layout space.
        rules.append([
            "trigger": [
                "url-filter": ".*",
                "if-domain": ["*tetr.io"],
            ],
            "action": [
                "type": "css-display-none",
                "selector": cosmeticSelectors,
            ],
        ])

        guard let data = try? JSONSerialization.data(withJSONObject: rules, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Compile the rule list, then hand it back on the main queue. Calls back
    /// with nil if compilation fails, in which case the app simply loads without
    /// blocking rather than refusing to start.
    static func compile(completion: @escaping (WKContentRuleList?) -> Void) {
        guard let store = WKContentRuleListStore.default(), let json = ruleListJSON() else {
            completion(nil)
            return
        }

        store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json) { list, error in
            if let error {
                NSLog("[AdBlock] compile failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { completion(list) }
        }
    }
}
