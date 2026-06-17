import SwiftUI

@main
struct SafariCloneApp: App {
    @StateObject private var tabManager = TabManager()
    @StateObject private var bookmarksManager = BookmarksManager()
    @StateObject private var historyManager = HistoryManager()
    @StateObject private var privateBrowsingManager = PrivateBrowsingManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tabManager)
                .environmentObject(bookmarksManager)
                .environmentObject(historyManager)
                .environmentObject(privateBrowsingManager)
                .preferredColorScheme(privateBrowsingManager.isPrivate ? .dark : nil)
        }
    }
}
