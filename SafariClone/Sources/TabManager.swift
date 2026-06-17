import SwiftUI
import WebKit
import Combine

class BrowserTab: ObservableObject, Identifiable {
    let id: UUID
    @Published var title: String
    @Published var url: URL?
    @Published var favicon: UIImage?
    @Published var isLoading: Bool
    @Published var estimatedProgress: Double
    @Published var canGoBack: Bool
    @Published var canGoForward: Bool
    @Published var snapshot: UIImage?
    var webViewModel: WebViewModel

    init(url: URL? = nil, isPrivate: Bool = false) {
        self.id = UUID()
        self.title = "New Tab"
        self.url = url
        self.favicon = nil
        self.isLoading = false
        self.estimatedProgress = 0
        self.canGoBack = false
        self.canGoForward = false
        self.snapshot = nil
        self.webViewModel = WebViewModel(isPrivate: isPrivate)

        if let url = url {
            webViewModel.load(url: url)
        }
    }
}

class TabManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabIndex: Int = 0

    var activeTab: BrowserTab? {
        guard !tabs.isEmpty, tabs.indices.contains(activeTabIndex) else { return nil }
        return tabs[activeTabIndex]
    }

    init() {
        addNewTab()
    }

    func addNewTab(url: URL? = nil, isPrivate: Bool = false) {
        let tab = BrowserTab(url: url, isPrivate: isPrivate)
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
    }

    func closeTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        tabs.remove(at: index)
        if tabs.isEmpty {
            addNewTab()
        } else {
            activeTabIndex = max(0, min(activeTabIndex, tabs.count - 1))
        }
    }

    func closeTab(_ tab: BrowserTab) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            closeTab(at: index)
        }
    }

    func selectTab(_ tab: BrowserTab) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            activeTabIndex = index
        }
    }

    func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeTabIndex = index
    }

    func closeAllTabs(isPrivate: Bool = false) {
        tabs.removeAll()
        addNewTab(isPrivate: isPrivate)
    }
}
