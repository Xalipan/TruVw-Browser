import Foundation
import Combine
import WebKit
import SwiftUI

enum BrowserSheet: Identifiable {
    case bookmarks, history, downloads, tabs, settings
    var id: Self { self }
}

class BrowserViewModel: ObservableObject {
    let tabManager = TabManager()
    let bookmarkManager = BookmarkManager()
    let historyManager = HistoryManager()
    let downloadManager = DownloadManager()

    @Published var activeSheet: BrowserSheet?
    @Published var showTabGrid = false
    @Published var isPrivateMode = false
    @Published var searchText = ""
    @Published var isEditingAddress = false
    @Published var showFindInPage = false
    @Published var findInPageQuery = ""

    // Forward active tab properties
    @Published var currentURL: URL?
    @Published var currentTitle: String = "New Tab"
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var tabObservers = Set<AnyCancellable>()

    init() {
        // When active tab changes, re-subscribe to its publishers
        tabManager.$activeTabID
            .combineLatest(tabManager.$tabs)
            .sink { [weak self] _, _ in
                self?.bindActiveTab()
            }
            .store(in: &cancellables)
    }

    private func bindActiveTab() {
        tabObservers.removeAll()
        guard let tab = tabManager.activeTab else { return }

        tab.$url.receive(on: DispatchQueue.main).sink { [weak self] url in
            self?.currentURL = url
        }.store(in: &tabObservers)

        tab.$title.receive(on: DispatchQueue.main).sink { [weak self] title in
            self?.currentTitle = title
        }.store(in: &tabObservers)

        tab.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            self?.isLoading = loading
        }.store(in: &tabObservers)

        tab.$estimatedProgress.receive(on: DispatchQueue.main).sink { [weak self] p in
            self?.estimatedProgress = p
        }.store(in: &tabObservers)

        tab.$canGoBack.receive(on: DispatchQueue.main).sink { [weak self] val in
            self?.canGoBack = val
        }.store(in: &tabObservers)

        tab.$canGoForward.receive(on: DispatchQueue.main).sink { [weak self] val in
            self?.canGoForward = val
        }.store(in: &tabObservers)

        // Sync initial values
        currentURL = tab.url
        currentTitle = tab.title
        isLoading = tab.isLoading
        canGoBack = tab.canGoBack
        canGoForward = tab.canGoForward
    }

    // MARK: - Navigation

    func navigate(to input: String) {
        isEditingAddress = false
        let url = resolveURL(from: input)
        if let tab = tabManager.activeTab {
            tab.hasNavigated = true
            tab.webView.load(URLRequest(url: url))
        }
    }

    func navigateBack() {
        tabManager.activeTab?.webView.goBack()
    }

    func navigateForward() {
        tabManager.activeTab?.webView.goForward()
    }

    func reload() {
        tabManager.activeTab?.webView.reload()
    }

    func stopLoading() {
        tabManager.activeTab?.webView.stopLoading()
    }

    func openNewTab(url: URL? = nil) {
        tabManager.addTab(url: url)
        showTabGrid = false
    }

    // MARK: - Bookmarks

    func toggleBookmark() {
        guard let url = currentURL else { return }
        if bookmarkManager.isBookmarked(url: url) {
            if let bm = bookmarkManager.bookmark(for: url) {
                bookmarkManager.removeBookmark(bm)
            }
        } else {
            bookmarkManager.addBookmark(title: currentTitle, url: url)
        }
    }

    var isCurrentPageBookmarked: Bool {
        guard let url = currentURL else { return false }
        return bookmarkManager.isBookmarked(url: url)
    }

    // MARK: - Share

    func share() -> [Any] {
        var items: [Any] = []
        if let url = currentURL { items.append(url) }
        if !currentTitle.isEmpty { items.append(currentTitle) }
        return items
    }

    // MARK: - Find in Page

    func findInPage(_ query: String) {
        guard let webView = tabManager.activeTab?.webView else { return }
        let js = "__domBridge?.postMessage('findInPage', {query: \"\(query.replacingOccurrences(of: "\"", with: "\\\""))\"})"
        webView.evaluateJavaScript(js, completionHandler: nil)

        // Native WKWebView find API (iOS 16+) — .find() is async, must use Task
        if #available(iOS 16.0, *) {
            let config = WKFindConfiguration()
            config.backwards = false
            config.wraps = true
            Task {
                _ = try? await webView.find(query, configuration: config)
            }
        }
    }

    // MARK: - URL Resolution

    func resolveURL(from input: String) -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Already a valid URL with scheme
        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return url
        }

        // Looks like a domain (has a dot, no spaces)
        if !trimmed.contains(" ") && trimmed.contains(".") {
            if let url = URL(string: "https://\(trimmed)") {
                return url
            }
        }

        // Fall through to search
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: "https://www.google.com/search?q=\(encoded)")!
    }

    func displayURL(_ url: URL?) -> String {
        guard let url = url else { return "" }
        var display = url.host ?? url.absoluteString
        if let path = url.host.map({ _ in url.path }), !path.isEmpty, path != "/" {
            display += path
        }
        return display
    }
}
