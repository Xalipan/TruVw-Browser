import SwiftUI

@main
struct TruVwApp: App {
    init() {
        ConfigManager.shared.fetchIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
            // Do NOT ignore keyboard safe area here — ContentView
            // manages it explicitly so the bottom bar lifts above
            // the keyboard while the web content stays full-bleed.
        }
    }
}
