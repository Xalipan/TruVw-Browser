import Foundation
import WebKit

// RuleEngine takes the matching rules for a URL and fires the right
// JS injection into the webview for each injection type.

class RuleEngine {

    static let shared = RuleEngine()
    private init() {}

    // Entry point — call this from DOMBridge.pageDidFinishLoading
    func apply(rules: [ConfigRule], to webView: WKWebView, url: URL) {
        for rule in rules {
            for injection in rule.inject {
                apply(injection: injection, to: webView, url: url, ruleId: rule.id)
            }
        }
    }

    // MARK: - Dispatch by type

    private func apply(injection: Injection, to webView: WKWebView, url: URL, ruleId: String) {
        switch injection.type {
        case .banner:        injectBanner(injection, webView)
        case .css:           injectCSS(injection, webView)
        case .searchResult:  injectSearchResult(injection, webView)
        case .videoSwap:     injectVideoSwap(injection, webView)
        case .elementReplace: injectElementReplace(injection, webView)
        case .script:        injectScript(injection, webView)
        }
    }

    // MARK: - Banner

    private func injectBanner(_ i: Injection, _ wv: WKWebView) {
        guard let html = i.html else { return }
        let position = i.position ?? .top
        let dismissable = i.dismissable ?? true
        let extraStyle = i.style ?? ""

        // Default banner style mirrors a system alert stripe
        let defaultStyle = """
            position: fixed;
            \(position == .top ? "top: 0;" : "bottom: 0;")
            left: 0; right: 0;
            z-index: 2147483647;
            background: #1c1c1e;
            color: #ffffff;
            font-family: -apple-system, sans-serif;
            font-size: 14px;
            padding: 12px 16px;
            box-shadow: 0 2px 12px rgba(0,0,0,0.4);
            display: flex;
            align-items: center;
            justify-content: space-between;
            \(extraStyle)
        """

        let dismissButton = dismissable ? """
            <button onclick="this.parentElement.remove()" style="
                background: none; border: none; color: #aaa;
                font-size: 18px; cursor: pointer; margin-left: 12px; padding: 0;
            ">✕</button>
        """ : ""

        let wrappedHTML = """
            <div id="__truvw_banner_\(Int.random(in: 1000...9999))" style="\(defaultStyle)">
                <div style="flex:1">\(html)</div>
                \(dismissButton)
            </div>
        """

        let escaped = jsStringEscape(wrappedHTML)
        let js = """
        (function() {
            if (document.getElementById('__truvw_banner')) return;
            var el = document.createElement('div');
            el.innerHTML = '\(escaped)';
            document.body.appendChild(el.firstChild);
        })();
        """
        eval(js, wv)
    }

    // MARK: - CSS

    private func injectCSS(_ i: Injection, _ wv: WKWebView) {
        if let cssUrl = i.cssUrl {
            // Fetch remote CSS then inject
            guard let url = URL(string: cssUrl) else { return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let css = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async { self.injectCSSString(css, wv) }
            }.resume()
        }
        if let inline = i.cssInline {
            injectCSSString(inline, wv)
        }
    }

    private func injectCSSString(_ css: String, _ wv: WKWebView) {
        let escaped = jsStringEscape(css)
        let js = """
        (function() {
            var s = document.createElement('style');
            s.textContent = '\(escaped)';
            document.head.appendChild(s);
        })();
        """
        eval(js, wv)
    }

    // MARK: - Fake Search Result (Google)
    // Inserts a result card that visually matches Google's organic result style.

    private func injectSearchResult(_ i: Injection, _ wv: WKWebView) {
        guard let title = i.title,
              let snippet = i.snippet,
              let targetUrl = i.targetUrl else { return }

        let displayUrl = i.displayUrl ?? targetUrl
        let position = i.resultPosition ?? 0
        let escapedTitle   = jsStringEscape(title)
        let escapedSnippet = jsStringEscape(snippet)
        let escapedDisplay = jsStringEscape(displayUrl)
        let escapedTarget  = jsStringEscape(targetUrl)

        let js = """
        (function() {
            // Google result containers — works on current Google DOM
            var containers = document.querySelectorAll('div.g, div[data-hveid]');
            if (!containers.length) {
                // Retry once after a short delay if results not rendered yet
                setTimeout(arguments.callee, 800);
                return;
            }

            if (document.getElementById('__truvw_result')) return;

            // Build a card that matches Google's result style
            var card = document.createElement('div');
            card.id = '__truvw_result';
            card.innerHTML = `
                <div style="font-family: arial,sans-serif; margin-bottom: 28px;">
                    <div style="font-size: 12px; color: #202124; margin-bottom: 1px;">
                        <span style="color: #4d5156;">\(escapedDisplay)</span>
                    </div>
                    <a href="\(escapedTarget)" style="
                        font-size: 20px; color: #1a0dab; text-decoration: none; line-height: 1.3;
                        display: block; margin-bottom: 3px;
                    ">\(escapedTitle)</a>
                    <div style="font-size: 14px; color: #4d5156; line-height: 1.58;">
                        \(escapedSnippet)
                    </div>
                </div>
            `;

            var target = containers[\(position)];
            if (target && target.parentNode) {
                target.parentNode.insertBefore(card, target);
            } else {
                containers[0].parentNode.prepend(card);
            }
        })();
        """
        eval(js, wv)
    }

    // MARK: - Video Swap

    private func injectVideoSwap(_ i: Injection, _ wv: WKWebView) {
        guard let replacementUrl = i.replacementUrl else { return }
        let poster = i.poster ?? ""
        let selector = i.videoSelector ?? "video"
        let escapedUrl    = jsStringEscape(replacementUrl)
        let escapedPoster = jsStringEscape(poster)
        let escapedSel    = jsStringEscape(selector)

        let js = """
        (function() {
            function swapVideos() {
                var vids = document.querySelectorAll('\(escapedSel)');
                vids.forEach(function(v) {
                    if (v.dataset.truvwSwapped) return;
                    v.dataset.truvwSwapped = '1';
                    // Replace src
                    v.src = '\(escapedUrl)';
                    if ('\(escapedPoster)') v.poster = '\(escapedPoster)';
                    // Remove all <source> children
                    Array.from(v.querySelectorAll('source')).forEach(s => s.remove());
                    v.load();
                });

                // Also handle YouTube iframes — replace with native <video>
                var frames = document.querySelectorAll('iframe[src*="youtube"]');
                frames.forEach(function(frame) {
                    if (frame.dataset.truvwSwapped) return;
                    frame.dataset.truvwSwapped = '1';
                    var vid = document.createElement('video');
                    vid.src = '\(escapedUrl)';
                    vid.poster = '\(escapedPoster)';
                    vid.controls = true;
                    vid.style.cssText = frame.style.cssText;
                    vid.width = frame.width;
                    vid.height = frame.height;
                    frame.parentNode.replaceChild(vid, frame);
                });
            }

            swapVideos();
            // Also watch for dynamically added videos
            var obs = new MutationObserver(swapVideos);
            obs.observe(document.body, { childList: true, subtree: true });
        })();
        """
        eval(js, wv)
    }

    // MARK: - Element Replace

    private func injectElementReplace(_ i: Injection, _ wv: WKWebView) {
        guard let selector = i.selector,
              let replacement = i.replacementHtml else { return }
        let escapedSel  = jsStringEscape(selector)
        let escapedHTML = jsStringEscape(replacement)

        let js = """
        (function() {
            document.querySelectorAll('\(escapedSel)').forEach(function(el) {
                el.outerHTML = '\(escapedHTML)';
            });
        })();
        """
        eval(js, wv)
    }

    // MARK: - Script

    private func injectScript(_ i: Injection, _ wv: WKWebView) {
        if let js = i.js {
            eval(js, wv)
        }
        if let jsUrl = i.jsUrl, let url = URL(string: jsUrl) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let js = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async { self.eval(js, wv) }
            }.resume()
        }
    }

    // MARK: - Helpers

    private func eval(_ js: String, _ wv: WKWebView) {
        DispatchQueue.main.async {
            wv.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    /// Escape a string for safe embedding inside a JS single-quoted string literal
    private func jsStringEscape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'",  with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "</", with: "<\\/")
    }
}
