import SwiftUI
import WebKit
import Combine

class WebViewModel: NSObject, ObservableObject {
    @Published var title: String = "New Tab"
    @Published var urlString: String = ""
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var favicon: UIImage? = nil
    @Published var findInPageResultCount: Int = 0
    @Published var findInPageCurrentIndex: Int = 0
    @Published var readerModeAvailable: Bool = false
    @Published var readerModeActive: Bool = false
    @Published var readerModeContent: ReaderContent? = nil
    @Published var domHooksEnabled: Bool = true

    let isPrivate: Bool
    weak var webView: WKWebView?
    private var cancellables = Set<AnyCancellable>()
    private var domHooksManager: DOMHooksManager?

    init(isPrivate: Bool = false) {
        self.isPrivate = isPrivate
        super.init()
        self.domHooksManager = DOMHooksManager(viewModel: self)
    }

    func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        if isPrivate {
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        }

        domHooksManager?.configure(configuration: configuration)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always

        setupObservers(for: webView)
        self.webView = webView
        return webView
    }

    private func setupObservers(for webView: WKWebView) {
        webView.publisher(for: \.title)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                self?.title = title ?? "New Tab"
            }
            .store(in: &cancellables)

        webView.publisher(for: \.url)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                if let url = url {
                    self?.urlString = url.absoluteString
                    self?.fetchFavicon(for: url)
                }
            }
            .store(in: &cancellables)

        webView.publisher(for: \.isLoading)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                self?.isLoading = loading
            }
            .store(in: &cancellables)

        webView.publisher(for: \.estimatedProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.estimatedProgress = progress
            }
            .store(in: &cancellables)

        webView.publisher(for: \.canGoBack)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canGoBack in
                self?.canGoBack = canGoBack
            }
            .store(in: &cancellables)

        webView.publisher(for: \.canGoForward)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canGoForward in
                self?.canGoForward = canGoForward
            }
            .store(in: &cancellables)
    }

    func load(url: URL) {
        webView?.load(URLRequest(url: url))
    }

    func load(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil {
            load(url: url)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            let withScheme = "https://\(trimmed)"
            if let url = URL(string: withScheme) {
                load(url: url)
            }
        } else {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            let searchURL = URL(string: "https://www.google.com/search?q=\(encoded)")!
            load(url: searchURL)
        }
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func stopLoading() { webView?.stopLoading() }

    func findInPage(query: String) {
        guard let webView = webView else { return }
        if query.isEmpty {
            let config = WKFindConfiguration()
            webView.find("", configuration: config) { _ in }
            return
        }
        let config = WKFindConfiguration()
        config.caseSensitive = false
        config.wraps = true
        webView.find(query, configuration: config) { [weak self] result in
            DispatchQueue.main.async {
                self?.findInPageResultCount = result.matchFound ? 1 : 0
            }
        }
    }

    func findNext(query: String) {
        guard let webView = webView, !query.isEmpty else { return }
        let config = WKFindConfiguration()
        config.caseSensitive = false
        config.wraps = true
        webView.find(query, configuration: config) { _ in }
    }

    func findPrevious(query: String) {
        guard let webView = webView, !query.isEmpty else { return }
        let config = WKFindConfiguration()
        config.caseSensitive = false
        config.backwards = true
        config.wraps = true
        webView.find(query, configuration: config) { _ in }
    }

    private func fetchFavicon(for url: URL) {
        guard let host = url.host else { return }
        let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")!
        URLSession.shared.dataTask(with: faviconURL) { [weak self] data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.favicon = image
                }
            }
        }.resume()
    }

    func checkReaderMode() {
        let script = """
        (function() {
            var article = document.querySelector('article');
            var content = document.querySelector('[role="main"]') || document.querySelector('main');
            var hasEnoughText = document.body.innerText.length > 500;
            return !!(article || content) && hasEnoughText;
        })();
        """
        webView?.evaluateJavaScript(script) { [weak self] result, _ in
            DispatchQueue.main.async {
                self?.readerModeAvailable = (result as? Bool) ?? false
            }
        }
    }

    func activateReaderMode() {
        let script = """
        (function() {
            var title = document.title;
            var article = document.querySelector('article') ||
                          document.querySelector('[role="main"]') ||
                          document.querySelector('main') ||
                          document.body;
            var content = article ? article.innerHTML : document.body.innerHTML;
            return JSON.stringify({ title: title, content: content });
        })();
        """
        webView?.evaluateJavaScript(script) { [weak self] result, _ in
            DispatchQueue.main.async {
                if let jsonString = result as? String,
                   let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    self?.readerModeContent = ReaderContent(
                        title: json["title"] ?? "",
                        htmlContent: json["content"] ?? ""
                    )
                    self?.readerModeActive = true
                }
            }
        }
    }

    func deactivateReaderMode() {
        readerModeActive = false
        readerModeContent = nil
    }

    func takeSnapshot(completion: @escaping (UIImage?) -> Void) {
        let config = WKSnapshotConfiguration()
        webView?.takeSnapshot(with: config) { image, _ in
            completion(image)
        }
    }
}

struct ReaderContent {
    let title: String
    let htmlContent: String
}

extension WebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        favicon = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        checkReaderMode()
        domHooksManager?.injectDOMHooks(into: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        let nsError = error as NSError
        if nsError.code != NSURLErrorCancelled {
            urlString = webView.url?.absoluteString ?? urlString
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.scheme == "tel" || url.scheme == "mailto" || url.scheme == "maps" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
}

extension WebViewModel: WKUIDelegate {
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            load(url: url)
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        NotificationCenter.default.post(
            name: .jsAlert,
            object: nil,
            userInfo: ["message": message, "completion": completionHandler as Any]
        )
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        NotificationCenter.default.post(
            name: .jsConfirm,
            object: nil,
            userInfo: ["message": message, "completion": completionHandler as Any]
        )
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        NotificationCenter.default.post(
            name: .jsPrompt,
            object: nil,
            userInfo: ["message": prompt, "defaultText": defaultText ?? "", "completion": completionHandler as Any]
        )
    }
}

extension Notification.Name {
    static let jsAlert = Notification.Name("com.safariclone.jsAlert")
    static let jsConfirm = Notification.Name("com.safariclone.jsConfirm")
    static let jsPrompt = Notification.Name("com.safariclone.jsPrompt")
    static let domMutation = Notification.Name("com.safariclone.domMutation")
    static let domEvent = Notification.Name("com.safariclone.domEvent")
    static let consoleLog = Notification.Name("com.safariclone.consoleLog")
}
