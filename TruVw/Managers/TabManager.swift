import Foundation
import Combine
import UIKit

class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var activeTabID: UUID?

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabID }
    }

    init() {
        addTab()
    }

    @discardableResult
    func addTab(url: URL? = nil) -> Tab {
        let tab = Tab(url: url)
        tabs.append(tab)
        activeTabID = tab.id
        return tab
    }

    func closeTab(_ tab: Tab) {
        guard let idx = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: idx)
        if tabs.isEmpty {
            addTab()
        } else if activeTabID == tab.id {
            let newIdx = min(idx, tabs.count - 1)
            activeTabID = tabs[newIdx].id
        }
    }

    func closeAllTabs() {
        tabs.removeAll()
        addTab()
    }

    func selectTab(_ tab: Tab) {
        activeTabID = tab.id
    }

    func duplicateTab(_ tab: Tab) {
        let newTab = Tab(url: tab.url, title: tab.title)
        if let idx = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs.insert(newTab, at: idx + 1)
        } else {
            tabs.append(newTab)
        }
        activeTabID = newTab.id
    }

    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }
}
