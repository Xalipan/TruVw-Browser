import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var privateBrowsingManager: PrivateBrowsingManager
    @State private var showTabOverview = false

    var body: some View {
        ZStack {
            if showTabOverview {
                TabOverviewView(showTabOverview: $showTabOverview)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                BrowserView(showTabOverview: $showTabOverview)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showTabOverview)
        .ignoresSafeArea(edges: showTabOverview ? .all : [])
    }
}
