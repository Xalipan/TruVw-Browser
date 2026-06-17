import WebKit
import Combine

// MARK: - DOM Hook Event Types

struct DOMEvent: Codable {
    let type: String
    let timestamp: Double
    let data: DOMEventData
}

struct DOMEventData: Codable {
    let selector: String?
    let tagName: String?
    let id: String?
    let classes: [String]?
    let textContent: String?
    let attributeName: String?
    let oldValue: String?
    let newValue: String?
    let eventType: String?
    let x: Double?
    let y: Double?
    let key: String?
    let value: String?
    let addedNodes: Int?
    let removedNodes: Int?
    let mutationType: String?
}

struct ConsoleMessage: Identifiable {
    let id = UUID()
    let level: String
    let message: String
    let timestamp: Date
    let url: String?
    let line: Int?
}

// MARK: - Script Message Names

enum ScriptMessage: String, CaseIterable {
    case domMutation = "domMutationHandler"
    case domEvent = "domEventHandler"
    case consoleLog = "consoleLogHandler"
    case networkRequest = "networkRequestHandler"
    case domQuery = "domQueryHandler"
    case domManipulate = "domManipulateHandler"
}

// MARK: - DOM Hooks Manager

class DOMHooksManager: NSObject {
    weak var viewModel: WebViewModel?
    private(set) var consoleMessages: [ConsoleMessage] = []
    private(set) var domMutations: [DOMEvent] = []
    private var scriptMessageHandlers: [ScriptMessage: WKScriptMessageHandler] = [:]

    init(viewModel: WebViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    func configure(configuration: WKWebViewConfiguration) {
        let contentController = configuration.userContentController

        for messageType in ScriptMessage.allCases {
            let handler = WeakScriptMessageHandler(delegate: self)
            contentController.add(handler, name: messageType.rawValue)
        }

        injectEarlyScripts(into: contentController)
    }

    private func injectEarlyScripts(into contentController: WKUserContentController) {
        let consoleCaptureScript = makeConsoleCaptureScript()
        let mutationObserverScript = makeMutationObserverScript()
        let eventInterceptorScript = makeEventInterceptorScript()
        let networkInterceptorScript = makeNetworkInterceptorScript()
        let domHelperScript = makeDOMHelperScript()

        let atDocStart = WKUserScriptInjectionTime.atDocumentStart
        let atDocEnd = WKUserScriptInjectionTime.atDocumentEnd

        contentController.addUserScript(WKUserScript(
            source: consoleCaptureScript, injectionTime: atDocStart, forMainFrameOnly: false))
        contentController.addUserScript(WKUserScript(
            source: networkInterceptorScript, injectionTime: atDocStart, forMainFrameOnly: false))
        contentController.addUserScript(WKUserScript(
            source: domHelperScript, injectionTime: atDocStart, forMainFrameOnly: true))
        contentController.addUserScript(WKUserScript(
            source: mutationObserverScript, injectionTime: atDocEnd, forMainFrameOnly: true))
        contentController.addUserScript(WKUserScript(
            source: eventInterceptorScript, injectionTime: atDocEnd, forMainFrameOnly: false))
    }

    func injectDOMHooks(into webView: WKWebView) {
        let readyScript = """
        if (window.__safariCloneDOMHooks && !window.__safariCloneDOMHooks.initialized) {
            window.__safariCloneDOMHooks.initialize();
        }
        """
        webView.evaluateJavaScript(readyScript, completionHandler: nil)
    }

    // MARK: - DOM Manipulation API (callable from native code)

    func querySelector(_ selector: String, in webView: WKWebView, completion: @escaping ([String: Any]?) -> Void) {
        let script = """
        (function() {
            var el = document.querySelector('\(selector.escaped)');
            if (!el) return null;
            return {
                tagName: el.tagName,
                id: el.id,
                className: el.className,
                textContent: el.textContent.substring(0, 500),
                innerHTML: el.innerHTML.substring(0, 2000),
                outerHTML: el.outerHTML.substring(0, 2000),
                attributes: Array.from(el.attributes).map(a => ({ name: a.name, value: a.value })),
                rect: (function(r) { return { top: r.top, left: r.left, width: r.width, height: r.height }; })(el.getBoundingClientRect())
            };
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            completion(result as? [String: Any])
        }
    }

    func querySelectorAll(_ selector: String, in webView: WKWebView, completion: @escaping ([[String: Any]]) -> Void) {
        let script = """
        (function() {
            var els = document.querySelectorAll('\(selector.escaped)');
            return Array.from(els).slice(0, 100).map(function(el) {
                return {
                    tagName: el.tagName,
                    id: el.id,
                    className: el.className,
                    textContent: el.textContent.substring(0, 200),
                    attributes: Array.from(el.attributes).map(a => ({ name: a.name, value: a.value }))
                };
            });
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            completion(result as? [[String: Any]] ?? [])
        }
    }

    func setAttribute(_ attribute: String, value: String, selector: String, in webView: WKWebView) {
        let script = """
        (function() {
            var els = document.querySelectorAll('\(selector.escaped)');
            els.forEach(function(el) { el.setAttribute('\(attribute.escaped)', '\(value.escaped)'); });
            return els.length;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func removeAttribute(_ attribute: String, selector: String, in webView: WKWebView) {
        let script = """
        document.querySelectorAll('\(selector.escaped)').forEach(function(el) {
            el.removeAttribute('\(attribute.escaped)');
        });
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func setStyle(_ style: String, value: String, selector: String, in webView: WKWebView) {
        let script = """
        document.querySelectorAll('\(selector.escaped)').forEach(function(el) {
            el.style['\(style.escaped)'] = '\(value.escaped)';
        });
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func setInnerHTML(_ html: String, selector: String, in webView: WKWebView) {
        let escapedHTML = html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        let script = """
        (function() {
            var el = document.querySelector('\(selector.escaped)');
            if (el) el.innerHTML = `\(escapedHTML)`;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func setTextContent(_ text: String, selector: String, in webView: WKWebView) {
        let script = """
        document.querySelectorAll('\(selector.escaped)').forEach(function(el) {
            el.textContent = '\(text.escaped)';
        });
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func addClass(_ className: String, selector: String, in webView: WKWebView) {
        let script = """
        document.querySelectorAll('\(selector.escaped)').forEach(function(el) {
            el.classList.add('\(className.escaped)');
        });
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func removeClass(_ className: String, selector: String, in webView: WKWebView) {
        let script = """
        document.querySelectorAll('\(selector.escaped)').forEach(function(el) {
            el.classList.remove('\(className.escaped)');
        });
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func removeElement(_ selector: String, in webView: WKWebView) {
        let script = """
        document.querySelectorAll('\(selector.escaped)').forEach(function(el) {
            el.parentNode && el.parentNode.removeChild(el);
        });
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func insertHTML(_ html: String, position: DOMInsertPosition, selector: String, in webView: WKWebView) {
        let escapedHTML = html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        let script = """
        (function() {
            var el = document.querySelector('\(selector.escaped)');
            if (el) el.insertAdjacentHTML('\(position.rawValue)', `\(escapedHTML)`);
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func injectCSS(_ css: String, in webView: WKWebView) {
        let escaped = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        let script = """
        (function() {
            var existing = document.getElementById('__safariCloneInjectedCSS');
            if (existing) { existing.textContent += `\(escaped)`; return; }
            var style = document.createElement('style');
            style.id = '__safariCloneInjectedCSS';
            style.textContent = `\(escaped)`;
            document.head.appendChild(style);
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func injectScript(_ js: String, in webView: WKWebView, completion: ((Any?, Error?) -> Void)? = nil) {
        webView.evaluateJavaScript(js, completionHandler: completion)
    }

    func dispatchEvent(_ eventName: String, selector: String, detail: [String: Any]? = nil, in webView: WKWebView) {
        let detailJSON = (try? JSONSerialization.data(withJSONObject: detail ?? [:]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let script = """
        (function() {
            var el = document.querySelector('\(selector.escaped)');
            if (!el) return false;
            var event = new CustomEvent('\(eventName.escaped)', { detail: \(detailJSON), bubbles: true, cancelable: true });
            el.dispatchEvent(event);
            return true;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func observeSelector(_ selector: String, events: [String], in webView: WKWebView) {
        let eventsJSON = (try? JSONSerialization.data(withJSONObject: events))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let script = """
        (function() {
            var els = document.querySelectorAll('\(selector.escaped)');
            els.forEach(function(el) {
                \(eventsJSON).forEach(function(eventType) {
                    el.addEventListener(eventType, function(e) {
                        var data = {
                            selector: '\(selector.escaped)',
                            tagName: el.tagName,
                            id: el.id,
                            classes: Array.from(el.classList),
                            eventType: eventType,
                            x: e.clientX || null,
                            y: e.clientY || null,
                            key: e.key || null,
                            value: el.value !== undefined ? el.value : null
                        };
                        window.webkit.messageHandlers.domEventHandler.postMessage({ type: 'event', timestamp: Date.now(), data: data });
                    });
                });
            });
            return els.length;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func getDocumentState(in webView: WKWebView, completion: @escaping ([String: Any]) -> Void) {
        let script = """
        (function() {
            return {
                url: window.location.href,
                title: document.title,
                readyState: document.readyState,
                characterSet: document.characterSet,
                contentType: document.contentType,
                lastModified: document.lastModified,
                cookieEnabled: navigator.cookieEnabled,
                bodyWordCount: document.body ? document.body.innerText.split(/\\s+/).length : 0,
                linkCount: document.links.length,
                imageCount: document.images.length,
                scriptCount: document.scripts.length,
                styleSheetCount: document.styleSheets.length,
                formCount: document.forms.length,
                frameCount: window.frames.length
            };
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            completion(result as? [String: Any] ?? [:])
        }
    }

    func scrollTo(x: Int, y: Int, animated: Bool, in webView: WKWebView) {
        let behavior = animated ? "smooth" : "instant"
        webView.evaluateJavaScript("window.scrollTo({ left: \(x), top: \(y), behavior: '\(behavior)' });", completionHandler: nil)
    }

    func scrollIntoView(_ selector: String, in webView: WKWebView) {
        webView.evaluateJavaScript("""
        var el = document.querySelector('\(selector.escaped)');
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        """, completionHandler: nil)
    }

    func clickElement(_ selector: String, in webView: WKWebView) {
        webView.evaluateJavaScript("""
        var el = document.querySelector('\(selector.escaped)');
        if (el) el.click();
        """, completionHandler: nil)
    }

    func focusElement(_ selector: String, in webView: WKWebView) {
        webView.evaluateJavaScript("""
        var el = document.querySelector('\(selector.escaped)');
        if (el) el.focus();
        """, completionHandler: nil)
    }

    func setInputValue(_ value: String, selector: String, in webView: WKWebView) {
        let script = """
        (function() {
            var el = document.querySelector('\(selector.escaped)');
            if (!el) return false;
            var nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
            nativeInputValueSetter.call(el, '\(value.escaped)');
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func getPageSource(in webView: WKWebView, completion: @escaping (String) -> Void) {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { result, _ in
            completion(result as? String ?? "")
        }
    }

    func getCookies(in webView: WKWebView, completion: @escaping ([HTTPCookie]) -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies(completion)
    }

    func setCookie(name: String, value: String, domain: String, in webView: WKWebView) {
        var props: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: "/",
            .expires: Date().addingTimeInterval(86400 * 365)
        ]
        if let cookie = HTTPCookie(properties: props) {
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie, completionHandler: nil)
        }
    }

    func deleteCookie(name: String, domain: String, in webView: WKWebView) {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        store.getAllCookies { cookies in
            for cookie in cookies where cookie.name == name && cookie.domain == domain {
                store.delete(cookie, completionHandler: nil)
            }
        }
    }

    func getLocalStorage(in webView: WKWebView, completion: @escaping ([String: String]) -> Void) {
        webView.evaluateJavaScript("""
        (function() {
            var items = {};
            for (var i = 0; i < localStorage.length; i++) {
                var key = localStorage.key(i);
                items[key] = localStorage.getItem(key);
            }
            return items;
        })();
        """) { result, _ in
            completion(result as? [String: String] ?? [:])
        }
    }

    func setLocalStorage(key: String, value: String, in webView: WKWebView) {
        webView.evaluateJavaScript("localStorage.setItem('\(key.escaped)', '\(value.escaped)');", completionHandler: nil)
    }

    func clearLocalStorage(in webView: WKWebView) {
        webView.evaluateJavaScript("localStorage.clear();", completionHandler: nil)
    }

    // MARK: - JavaScript Script Templates

    private func makeConsoleCaptureScript() -> String {
        return """
        (function() {
            var handler = window.webkit && window.webkit.messageHandlers.consoleLogHandler;
            if (!handler || window.__consoleHooked) return;
            window.__consoleHooked = true;
            var methods = ['log', 'warn', 'error', 'info', 'debug'];
            methods.forEach(function(method) {
                var original = console[method].bind(console);
                console[method] = function() {
                    var args = Array.prototype.slice.call(arguments);
                    original.apply(console, args);
                    try {
                        handler.postMessage({
                            level: method,
                            message: args.map(function(a) {
                                if (typeof a === 'object') { try { return JSON.stringify(a); } catch(e) { return String(a); } }
                                return String(a);
                            }).join(' '),
                            timestamp: Date.now(),
                            url: window.location.href
                        });
                    } catch(e) {}
                };
            });
            window.addEventListener('error', function(e) {
                try {
                    handler.postMessage({
                        level: 'error',
                        message: e.message + ' (' + e.filename + ':' + e.lineno + ':' + e.colno + ')',
                        timestamp: Date.now(),
                        url: window.location.href
                    });
                } catch(ex) {}
            });
            window.addEventListener('unhandledrejection', function(e) {
                try {
                    handler.postMessage({
                        level: 'error',
                        message: 'Unhandled Promise Rejection: ' + String(e.reason),
                        timestamp: Date.now(),
                        url: window.location.href
                    });
                } catch(ex) {}
            });
        })();
        """
    }

    private func makeMutationObserverScript() -> String {
        return """
        (function() {
            var handler = window.webkit && window.webkit.messageHandlers.domMutationHandler;
            if (!handler || window.__mutationObserverInstalled) return;
            window.__mutationObserverInstalled = true;
            var batchedMutations = [];
            var flushTimer = null;
            function flush() {
                if (batchedMutations.length === 0) return;
                var batch = batchedMutations.splice(0, 50);
                batch.forEach(function(m) {
                    try { handler.postMessage(m); } catch(e) {}
                });
                flushTimer = null;
            }
            var observer = new MutationObserver(function(mutations) {
                mutations.forEach(function(mutation) {
                    var data = {
                        type: 'mutation',
                        timestamp: Date.now(),
                        data: {
                            mutationType: mutation.type,
                            selector: mutation.target.id ? '#' + mutation.target.id : mutation.target.tagName,
                            tagName: mutation.target.tagName,
                            id: mutation.target.id || null,
                            classes: Array.from(mutation.target.classList || []),
                            attributeName: mutation.attributeName || null,
                            oldValue: mutation.oldValue || null,
                            newValue: mutation.type === 'attributes' ? mutation.target.getAttribute(mutation.attributeName) : null,
                            addedNodes: mutation.addedNodes.length,
                            removedNodes: mutation.removedNodes.length
                        }
                    };
                    batchedMutations.push(data);
                });
                if (!flushTimer) flushTimer = setTimeout(flush, 100);
            });
            observer.observe(document.body || document.documentElement, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeOldValue: true,
                characterData: false
            });
        })();
        """
    }

    private func makeEventInterceptorScript() -> String {
        return """
        (function() {
            var handler = window.webkit && window.webkit.messageHandlers.domEventHandler;
            if (!handler || window.__eventInterceptorInstalled) return;
            window.__eventInterceptorInstalled = true;
            var trackedEvents = ['click', 'submit', 'input', 'change', 'focus', 'blur', 'keydown', 'scroll'];
            trackedEvents.forEach(function(eventType) {
                document.addEventListener(eventType, function(e) {
                    try {
                        var target = e.target;
                        var data = {
                            type: 'event',
                            timestamp: Date.now(),
                            data: {
                                eventType: eventType,
                                selector: target.id ? '#' + target.id : (target.className ? '.' + target.className.split(' ')[0] : target.tagName),
                                tagName: target.tagName,
                                id: target.id || null,
                                classes: Array.from(target.classList || []),
                                value: target.value !== undefined ? String(target.value).substring(0, 200) : null,
                                x: e.clientX || null,
                                y: e.clientY || null,
                                key: e.key || null
                            }
                        };
                        handler.postMessage(data);
                    } catch(ex) {}
                }, { passive: true, capture: true });
            });
        })();
        """
    }

    private func makeNetworkInterceptorScript() -> String {
        return """
        (function() {
            var handler = window.webkit && window.webkit.messageHandlers.networkRequestHandler;
            if (!handler || window.__networkInterceptorInstalled) return;
            window.__networkInterceptorInstalled = true;
            var origFetch = window.fetch;
            window.fetch = function(input, init) {
                var url = typeof input === 'string' ? input : input.url;
                var method = (init && init.method) || (input.method) || 'GET';
                try {
                    handler.postMessage({ type: 'fetch', url: url, method: method, timestamp: Date.now() });
                } catch(e) {}
                return origFetch.apply(this, arguments).then(function(response) {
                    try {
                        handler.postMessage({ type: 'fetch_response', url: url, status: response.status, timestamp: Date.now() });
                    } catch(e) {}
                    return response;
                });
            };
            var origOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url) {
                this.__url = url;
                this.__method = method;
                return origOpen.apply(this, arguments);
            };
            var origSend = XMLHttpRequest.prototype.send;
            XMLHttpRequest.prototype.send = function() {
                var xhr = this;
                try {
                    handler.postMessage({ type: 'xhr', url: xhr.__url, method: xhr.__method, timestamp: Date.now() });
                } catch(e) {}
                return origSend.apply(this, arguments);
            };
        })();
        """
    }

    private func makeDOMHelperScript() -> String {
        return """
        (function() {
            window.__safariCloneDOMHooks = {
                initialized: false,
                initialize: function() {
                    this.initialized = true;
                },
                query: function(selector) {
                    var el = document.querySelector(selector);
                    if (!el) return null;
                    return {
                        tagName: el.tagName,
                        id: el.id,
                        className: el.className,
                        textContent: el.textContent.substring(0, 500),
                        innerHTML: el.innerHTML.substring(0, 2000)
                    };
                },
                queryAll: function(selector) {
                    return Array.from(document.querySelectorAll(selector)).map(function(el) {
                        return { tagName: el.tagName, id: el.id, className: el.className };
                    });
                },
                highlight: function(selector, color) {
                    color = color || '#ffeb3b';
                    document.querySelectorAll(selector).forEach(function(el) {
                        el.style.outline = '3px solid ' + color;
                        el.style.outlineOffset = '2px';
                    });
                },
                unhighlight: function(selector) {
                    document.querySelectorAll(selector).forEach(function(el) {
                        el.style.outline = '';
                        el.style.outlineOffset = '';
                    });
                },
                getComputedStyle: function(selector, property) {
                    var el = document.querySelector(selector);
                    if (!el) return null;
                    return window.getComputedStyle(el).getPropertyValue(property);
                },
                xpath: function(expression) {
                    var result = document.evaluate(expression, document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                    var nodes = [];
                    for (var i = 0; i < result.snapshotLength; i++) {
                        var node = result.snapshotItem(i);
                        nodes.push({ tagName: node.tagName || '#text', textContent: (node.textContent || '').substring(0, 200) });
                    }
                    return nodes;
                }
            };
        })();
        """
    }
}

// MARK: - WKScriptMessageHandler

extension DOMHooksManager: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }

        switch message.name {
        case ScriptMessage.domMutation.rawValue:
            handleDOMMutation(body)
        case ScriptMessage.domEvent.rawValue:
            handleDOMEvent(body)
        case ScriptMessage.consoleLog.rawValue:
            handleConsoleLog(body)
        case ScriptMessage.networkRequest.rawValue:
            handleNetworkRequest(body)
        default:
            break
        }
    }

    private func handleDOMMutation(_ body: [String: Any]) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .domMutation, object: nil, userInfo: body)
        }
    }

    private func handleDOMEvent(_ body: [String: Any]) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .domEvent, object: nil, userInfo: body)
        }
    }

    private func handleConsoleLog(_ body: [String: Any]) {
        let level = body["level"] as? String ?? "log"
        let message = body["message"] as? String ?? ""
        let timestamp = Date(timeIntervalSince1970: (body["timestamp"] as? Double ?? 0) / 1000)
        let url = body["url"] as? String
        let line = body["line"] as? Int

        let logMessage = ConsoleMessage(level: level, message: message, timestamp: timestamp, url: url, line: line)
        DispatchQueue.main.async {
            self.consoleMessages.append(logMessage)
            if self.consoleMessages.count > 1000 {
                self.consoleMessages.removeFirst(self.consoleMessages.count - 1000)
            }
            NotificationCenter.default.post(name: .consoleLog, object: nil, userInfo: [
                "level": level,
                "message": message,
                "timestamp": timestamp
            ])
        }
    }

    private func handleNetworkRequest(_ body: [String: Any]) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .domEvent, object: nil, userInfo: body)
        }
    }
}

// MARK: - Weak Handler Wrapper (prevents memory leaks)

class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(delegate: WKScriptMessageHandler) { self.delegate = delegate }
    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - Insert Position

enum DOMInsertPosition: String {
    case beforeBegin = "beforebegin"
    case afterBegin = "afterbegin"
    case beforeEnd = "beforeend"
    case afterEnd = "afterend"
}

// MARK: - String Helpers

private extension String {
    var escaped: String {
        return self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
