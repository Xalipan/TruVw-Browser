import SwiftUI
import WebKit
import Combine

struct WebView: UIViewRepresentable {
    let tab: Tab
    @ObservedObject var vm: BrowserViewModel

    func makeUIView(context: Context) -> WKWebView {
        let webView = tab.webView

        // Coordinator as delegate
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Configure DOM bridge on the user content controller
        DOMBridge.shared.configure(userContentController: webView.configuration.userContentController)

        // KVO for live progress/state
        context.coordinator.observe(webView: webView, tab: tab)

        // Pull-to-refresh
        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Nothing — the webView is managed by Tab; navigation happens via load()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, vm: vm)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let tab: Tab
        let vm: BrowserViewModel
        private var observers: [NSKeyValueObservation] = []

        init(tab: Tab, vm: BrowserViewModel) {
            self.tab = tab
            self.vm = vm
        }

        deinit {
            observers.forEach { $0.invalidate() }
        }

        func observe(webView: WKWebView, tab: Tab) {
            observers = [
                webView.observe(\.estimatedProgress, options: .new) { [weak tab] wv, _ in
                    DispatchQueue.main.async { tab?.estimatedProgress = wv.estimatedProgress }
                },
                webView.observe(\.isLoading, options: .new) { [weak tab] wv, _ in
                    DispatchQueue.main.async { tab?.isLoading = wv.isLoading }
                },
                webView.observe(\.title, options: .new) { [weak tab] wv, _ in
                    DispatchQueue.main.async { tab?.title = wv.title ?? "New Tab" }
                },
                webView.observe(\.url, options: .new) { [weak tab] wv, _ in
                    DispatchQueue.main.async { tab?.url = wv.url }
                },
                webView.observe(\.canGoBack, options: .new) { [weak tab] wv, _ in
                    DispatchQueue.main.async { tab?.canGoBack = wv.canGoBack }
                },
                webView.observe(\.canGoForward, options: .new) { [weak tab] wv, _ in
                    DispatchQueue.main.async { tab?.canGoForward = wv.canGoForward }
                },
            ]
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if let url = webView.url {
                DOMBridge.shared.navigationDidStart(webView: webView, url: url)
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            if let url = webView.url {
                DOMBridge.shared.navigationDidCommit(webView: webView, url: url)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            let title = webView.title ?? ""

            // Record in history
            vm.historyManager.record(title: title, url: url)

            // Fire DOM bridge hook
            DOMBridge.shared.pageDidFinishLoading(webView: webView, url: url)

            // Capture snapshot for tab switcher
            let config = WKSnapshotConfiguration()
            webView.takeSnapshot(with: config) { [weak self] image, _ in
                DispatchQueue.main.async { self?.tab.snapshot = image }
            }

            // Refresh pull-to-refresh indicator
            webView.scrollView.refreshControl?.endRefreshing()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            webView.scrollView.refreshControl?.endRefreshing()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            // Ignore cancelled navigations
            guard nsError.code != NSURLErrorCancelled else { return }
            webView.scrollView.refreshControl?.endRefreshing()

            // Show offline/error page
            let html = Self.errorPageHTML(for: error)
            webView.loadHTMLString(html, baseURL: nil)
        }

        // Allow all navigation (like Safari)
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            if let url = navigationAction.request.url {
                // Handle tel:, mailto:, etc.
                if let scheme = url.scheme, !["http", "https", "about", "blob", "data", "file"].contains(scheme) {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }

                // Intercept download-type links
                let downloadExtensions = ["pdf", "zip", "gz", "tar", "rar", "dmg", "exe", "apk", "ipa", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "mp3", "mp4", "mov", "avi"]
                if let ext = url.pathExtension.lowercased() as String?,
                   downloadExtensions.contains(ext),
                   navigationAction.navigationType == .linkActivated {
                    vm.downloadManager.startDownload(url: url)
                    decisionHandler(.cancel)
                    return
                }
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

            // Handle content-disposition: attachment
            if let httpResponse = navigationResponse.response as? HTTPURLResponse,
               let contentDisp = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
               contentDisp.lowercased().contains("attachment"),
               let url = navigationResponse.response.url {
                vm.downloadManager.startDownload(url: url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        // MARK: WKUIDelegate (popups, alerts, new windows)

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Open target="_blank" links in a new tab
            if let url = navigationAction.request.url {
                DispatchQueue.main.async {
                    self.vm.tabManager.addTab(url: url)
                }
            }
            return nil
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: webView.url?.host, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            topViewController()?.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: webView.url?.host, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
            topViewController()?.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: webView.url?.host, message: prompt, preferredStyle: .alert)
            alert.addTextField { tf in tf.text = defaultText }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            topViewController()?.present(alert, animated: true)
        }

        @objc func handleRefresh(_ control: UIRefreshControl) {
            tab.webView.reload()
        }

        // MARK: - Error Page

        private static func errorPageHTML(for error: Error) -> String {
            let msg = error.localizedDescription
            return """
            <!DOCTYPE html><html>
            <head><meta name="viewport" content="width=device-width,initial-scale=1">
            <style>
            body { font-family: -apple-system; text-align: center; padding: 60px 20px; background: #f2f2f7; color: #3c3c43; }
            .icon { font-size: 60px; margin-bottom: 20px; }
            h1 { font-size: 22px; margin-bottom: 12px; }
            p { font-size: 15px; color: #6c6c70; line-height: 1.5; }
            </style></head>
            <body>
            <div class="icon">🌐</div>
            <h1>Page Cannot Be Opened</h1>
            <p>\(msg)</p>
            </body></html>
            """
        }

        private func topViewController() -> UIViewController? {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else { return nil }
            var top: UIViewController = root
            while let presented = top.presentedViewController { top = presented }
            return top
        }
    }
}
