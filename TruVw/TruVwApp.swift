import SwiftUI

@main
struct TruVwApp: App {
    init() {
        ConfigManager.shared.fetchIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .ignoresSafeArea(.keyboard)
        }
    }
}
