import SwiftUI
import WebKit

struct SettingsView: View {
    @ObservedObject var vm: BrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("searchEngine") private var searchEngine = "Google"
    @AppStorage("blockPopups") private var blockPopups = true
    @AppStorage("preventCrossTracking") private var preventCrossTracking = true
    @AppStorage("fraudWarning") private var fraudWarning = true
    @AppStorage("jsEnabled") private var jsEnabled = true

    let searchEngines = ["Google", "DuckDuckGo", "Bing", "Yahoo", "Ecosia"]

    var body: some View {
        NavigationView {
            Form {
                Section("Search") {
                    Picker("Search Engine", selection: $searchEngine) {
                        ForEach(searchEngines, id: \.self) { Text($0) }
                    }
                }

                Section("Content") {
                    Toggle("Block Pop-ups", isOn: $blockPopups)
                    Toggle("Prevent Cross-Site Tracking", isOn: $preventCrossTracking)
                    Toggle("Fraudulent Website Warning", isOn: $fraudWarning)
                    Toggle("JavaScript", isOn: $jsEnabled)
                }

                Section("Privacy") {
                    Button("Clear History and Website Data") {
                        vm.historyManager.clearAll()
                    }
                    .foregroundColor(.red)
                    Button("Clear Cookies") {
                        WKWebsiteDataStore.default().removeData(
                            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                            modifiedSince: Date(timeIntervalSince1970: 0)
                        ) {}
                    }
                    .foregroundColor(.red)
                }

                Section("Downloads") {
                    NavigationLink("Downloaded Files") {
                        DownloadedFilesView()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DownloadedFilesView: View {
    @State private var files: [URL] = []

    var body: some View {
        List(files, id: \.self) { url in
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.blue)
                Text(url.lastPathComponent)
                Spacer()
                Button {
                    shareFile(url)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("Downloaded Files")
        .onAppear(perform: loadFiles)
    }

    func loadFiles() {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Downloads") else { return }
        files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    }

    func shareFile(_ url: URL) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }
}
