import Foundation
import WebKit

// ============================================================
// DOMBridge: Hook system for DOM manipulation
//
// This is where you'll plug in your DOM manipulation logic.
// Each hook is called at a specific point in the page lifecycle.
//
// USAGE EXAMPLE:
//   DOMBridge.shared.onPageLoaded = { webView, url in
//       webView.evaluateJavaScript("document.body.style.background = 'red'", completionHandler: nil)
//   }
// ============================================================

typealias DOMHook = (WKWebView, URL) -> Void
typealias DOMScriptHook = (WKWebView, URL) -> String?  // returns JS to inject, or nil

class DOMBridge: NSObject {
    static let shared = DOMBridge()

    // ── Lifecycle Hooks ──────────────────────────────────────

    /// Called when a page finishes loading
    var onPageLoaded: DOMHook?

    /// Called when navigation to a new URL begins
    var onNavigationStarted: DOMHook?

    /// Called when navigation commits (HTML starts arriving)
    var onNavigationCommitted: DOMHook?

    /// Called on every page load — return JS string to inject at document-start
    var documentStartScript: DOMScriptHook?

    /// Called on every page load — return JS string to inject at document-end
    var documentEndScript: DOMScriptHook?

    // ── Message Handlers ─────────────────────────────────────
    // JS can post messages back to native via:
    //   window.webkit.messageHandlers.domBridge.postMessage({type: "myEvent", data: {...}})

    var onMessageReceived: ((_ message: WKScriptMessage) -> Void)?

    // ── Content Rules (ad blocking, etc.) ────────────────────
    // Add WKContentRuleList rules here
    var contentRules: [String]? // JSON rule strings for WKContentRuleListStore

    // ── User Scripts ─────────────────────────────────────────
    // Add WKUserScript objects to inject globally
    var userScripts: [WKUserScript] = []

    // ── Internal: apply to WKWebView configuration ───────────

    func configure(userContentController: WKUserContentController) {
        // Register native message handler
        userContentController.add(WeakScriptMessageHandler(delegate: self),
                                  name: "domBridge")

        // Inject base bridge JS at document-start
        let bridgeScript = WKUserScript(
            source: Self.baseBridgeJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(bridgeScript)

        // Inject any extra user scripts
        for script in userScripts {
            userContentController.addUserScript(script)
        }
    }

    // Called by WebView wrapper at key points

    func pageDidFinishLoading(webView: WKWebView, url: URL) {
        onPageLoaded?(webView, url)

        if let js = documentEndScript?(webView, url), !js.isEmpty {
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        // ── Config-driven rule injection ──────────────────────────
        let rules = ConfigManager.shared.matchingRules(for: url)
        if !rules.isEmpty {
            RuleEngine.shared.apply(rules: rules, to: webView, url: url)
        }
    }

    func navigationDidStart(webView: WKWebView, url: URL) {
        onNavigationStarted?(webView, url)
    }

    func navigationDidCommit(webView: WKWebView, url: URL) {
        onNavigationCommitted?(webView, url)

        if let js = documentStartScript?(webView, url), !js.isEmpty {
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    // ── Convenience DOM helpers ───────────────────────────────

    /// Inject arbitrary JS into the active tab's webview
    func evaluate(_ js: String, in webView: WKWebView, completion: ((Any?, Error?) -> Void)? = nil) {
        webView.evaluateJavaScript(js, completionHandler: completion)
    }

    /// Inject a CSS string into the page
    func injectCSS(_ css: String, in webView: WKWebView) {
        let escaped = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        let js = """
        (function() {
            var style = document.createElement('style');
            style.type = 'text/css';
            style.innerHTML = "\(escaped)";
            document.head.appendChild(style);
        })();
        """
        evaluate(js, in: webView)
    }

    /// Remove elements matching a CSS selector
    func removeElements(matching selector: String, in webView: WKWebView) {
        let escaped = selector.replacingOccurrences(of: "\"", with: "\\\"")
        let js = """
        document.querySelectorAll("\(escaped)").forEach(el => el.remove());
        """
        evaluate(js, in: webView)
    }

    /// Get the page's text content
    func getTextContent(from webView: WKWebView, completion: @escaping (String?) -> Void) {
        evaluate("document.body.innerText", in: webView) { result, _ in
            completion(result as? String)
        }
    }

    /// Get the full HTML of the page
    func getHTML(from webView: WKWebView, completion: @escaping (String?) -> Void) {
        evaluate("document.documentElement.outerHTML", in: webView) { result, _ in
            completion(result as? String)
        }
    }

    // ── Base bridge JS injected into every page ───────────────

    private static let baseBridgeJS = """
    // TruVw DOM Bridge — injected at document-start
    window.__domBridge = {
        version: '1.0',
        postMessage: function(type, data) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.domBridge) {
                window.webkit.messageHandlers.domBridge.postMessage({ type: type, data: data });
            }
        },
        // Hook: fires when DOM is ready (use instead of DOMContentLoaded if injecting at start)
        onDOMReady: function(callback) {
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', callback);
            } else {
                callback();
            }
        }
    };
    // Notify native that script-context is alive
    window.__domBridge.postMessage('scriptContextReady', { url: window.location.href });
    """
}

// MARK: - WKScriptMessageHandler

extension DOMBridge: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        onMessageReceived?(message)
    }
}

// Avoid retain cycle
class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(delegate: WKScriptMessageHandler) { self.delegate = delegate }
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(ucc, didReceive: message)
    }
}
