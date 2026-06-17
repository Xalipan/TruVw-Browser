import SwiftUI
import WebKit

struct PageActionsView: View {
    @ObservedObject var viewModel: WebViewModel
    @EnvironmentObject var bookmarksManager: BookmarksManager
    @EnvironmentObject var historyManager: HistoryManager
    @Environment(\.dismiss) var dismiss

    @State private var showZoomPicker = false
    @State private var textSize: Double = 100
    @State private var isBookmarked = false

    var currentURL: URL? { viewModel.webView?.url }

    var body: some View {
        NavigationView {
            List {
                // Page info section
                Section {
                    if let url = currentURL {
                        HStack(spacing: 12) {
                            if let favicon = viewModel.favicon {
                                Image(uiImage: favicon)
                                    .resizable()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "globe")
                                            .foregroundColor(.secondary)
                                    )
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(url.host ?? url.absoluteString)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Quick actions
                Section {
                    actionRow(icon: "book", title: "Add to Reading List") {
                        dismiss()
                    }

                    actionRow(
                        icon: isBookmarked ? "bookmark.fill" : "bookmark",
                        title: isBookmarked ? "Remove Bookmark" : "Add Bookmark",
                        tint: isBookmarked ? .blue : nil
                    ) {
                        if let url = currentURL {
                            bookmarksManager.toggleBookmark(title: viewModel.title, url: url)
                            withAnimation { isBookmarked.toggle() }
                        }
                    }

                    actionRow(icon: "house", title: "Add to Home Screen") {
                        dismiss()
                    }

                    actionRow(icon: "square.and.arrow.up", title: "Share Page") {
                        dismiss()
                    }
                }

                // Viewing options
                Section("Viewing Options") {
                    HStack {
                        Text("Text Size")
                        Spacer()
                        Button {
                            adjustTextSize(-10)
                        } label: {
                            Image(systemName: "textformat.size.smaller")
                                .frame(width: 36, height: 36)
                        }
                        Text("\(Int(textSize))%")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 50)
                        Button {
                            adjustTextSize(10)
                        } label: {
                            Image(systemName: "textformat.size.larger")
                                .frame(width: 36, height: 36)
                        }
                    }

                    if viewModel.readerModeAvailable || viewModel.readerModeActive {
                        actionRow(
                            icon: viewModel.readerModeActive ? "text.alignleft" : "doc.plaintext",
                            title: viewModel.readerModeActive ? "Exit Reader Mode" : "Show Reader Mode"
                        ) {
                            if viewModel.readerModeActive {
                                viewModel.deactivateReaderMode()
                            } else {
                                viewModel.activateReaderMode()
                            }
                            dismiss()
                        }
                    }

                    actionRow(icon: "doc.text.magnifyingglass", title: "Find on Page") {
                        dismiss()
                    }
                }

                // Developer section
                Section("Developer") {
                    actionRow(icon: "chevron.left.forwardslash.chevron.right", title: "DOM Inspector") {
                        dismiss()
                    }

                    actionRow(icon: "terminal", title: "JavaScript Console") {
                        dismiss()
                    }

                    actionRow(icon: "doc.text", title: "View Page Source") {
                        viewPageSource()
                    }

                    actionRow(icon: "network", title: "Page Info") {
                        showPageInfo()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Page Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let url = currentURL {
                    isBookmarked = bookmarksManager.isBookmarked(url: url)
                }
            }
        }
    }

    @ViewBuilder
    private func actionRow(icon: String, title: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(tint ?? .blue)
                    .frame(width: 24)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
            }
        }
    }

    private func adjustTextSize(_ delta: Double) {
        textSize = max(50, min(200, textSize + delta))
        viewModel.webView?.evaluateJavaScript(
            "document.body.style.fontSize = '\(textSize)%'",
            completionHandler: nil
        )
    }

    private func viewPageSource() {
        viewModel.webView?.evaluateJavaScript("document.documentElement.outerHTML") { result, _ in
            if let source = result as? String, let url = self.currentURL {
                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("source.txt")
                try? source.write(to: tempFile, atomically: true, encoding: .utf8)
            }
        }
        dismiss()
    }

    private func showPageInfo() {
        dismiss()
    }
}
