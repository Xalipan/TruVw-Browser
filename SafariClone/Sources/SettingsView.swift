import SwiftUI
import WebKit

struct SettingsView: View {
    @EnvironmentObject var privateBrowsingManager: PrivateBrowsingManager
    @Environment(\.dismiss) var dismiss

    @AppStorage("searchEngine") var searchEngine: String = "Google"
    @AppStorage("blockPopups") var blockPopups: Bool = true
    @AppStorage("enableJavaScript") var enableJavaScript: Bool = true
    @AppStorage("preventCrossTracking") var preventCrossTracking: Bool = true
    @AppStorage("fraudulentWarning") var fraudulentWarning: Bool = true
    @AppStorage("showFavoritesBar") var showFavoritesBar: Bool = false
    @AppStorage("openTabsInBackground") var openTabsInBackground: Bool = false
    @AppStorage("showTabBar") var showTabBar: Bool = true
    @AppStorage("domHooksEnabled") var domHooksEnabled: Bool = true

    let searchEngines = ["Google", "Yahoo", "Bing", "DuckDuckGo", "Ecosia"]

    var body: some View {
        NavigationView {
            List {
                Section("Search") {
                    Picker("Search Engine", selection: $searchEngine) {
                        ForEach(searchEngines, id: \.self) { Text($0) }
                    }
                }

                Section("General") {
                    Toggle("Show Favorites Bar", isOn: $showFavoritesBar)
                    Toggle("Open New Tabs in Background", isOn: $openTabsInBackground)
                    Toggle("Show Tab Bar", isOn: $showTabBar)
                }

                Section("Privacy & Security") {
                    Toggle("Block Pop-ups", isOn: $blockPopups)
                    Toggle("Prevent Cross-Site Tracking", isOn: $preventCrossTracking)
                    Toggle("Fraudulent Website Warning", isOn: $fraudulentWarning)
                    NavigationLink("Clear History and Website Data") {
                        ClearDataView()
                    }
                }

                Section("Content Blocking") {
                    Toggle("Enable JavaScript", isOn: $enableJavaScript)
                        .onChange(of: enableJavaScript) { enabled in
                            updateJavaScriptPreference(enabled)
                        }
                }

                Section("Developer Tools") {
                    Toggle("DOM Manipulation Hooks", isOn: $domHooksEnabled)
                    NavigationLink("DOM Inspector") {
                        Text("Open a browser tab and use the toolbar DOM Inspector button")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    NavigationLink("JavaScript Console") {
                        Text("Open a browser tab and use the toolbar JS Console button")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Safari Clone)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("WebKit Version")
                        Spacer()
                        Text(webKitVersion())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func updateJavaScriptPreference(_ enabled: Bool) {
        // This will apply to new web views created after the preference change.
    }

    private func webKitVersion() -> String {
        let userAgent = WKWebView(frame: .zero).value(forKey: "userAgent") as? String ?? ""
        if let range = userAgent.range(of: "AppleWebKit/"),
           let endRange = userAgent.range(of: " ", range: range.upperBound..<userAgent.endIndex) {
            return String(userAgent[range.upperBound..<endRange.lowerBound])
        }
        return "Unknown"
    }
}

struct ClearDataView: View {
    @State private var showConfirm = false

    var body: some View {
        List {
            Section {
                Button("Clear History and Website Data", role: .destructive) {
                    showConfirm = true
                }
            } footer: {
                Text("Removes history, cookies, and other browsing data. This does not cancel any subscriptions.")
            }
        }
        .navigationTitle("Clear Data")
        .alert("Are you sure?", isPresented: $showConfirm) {
            Button("Clear", role: .destructive) {
                clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all history, cookies, and website data.")
        }
    }

    private func clearAllData() {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) {}
    }
}
