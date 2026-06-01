import SwiftUI
import WebKit

struct BrowserView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var bookmarksManager: BookmarksManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var privateBrowsingManager: PrivateBrowsingManager
    @Binding var showTabOverview: Bool

    @State private var showBookmarks = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var showFindInPage = false
    @State private var showDOMInspector = false
    @State private var showJSConsole = false
    @State private var urlBarFocused = false
    @State private var addressBarExpanded = false
    @State private var showReaderMode = false
    @State private var toolbarVisible = true
    @State private var lastScrollY: CGFloat = 0
    @State private var jsAlertMessage: String? = nil
    @State private var showJSAlert = false
    @State private var showPageActions = false

    var activeTab: BrowserTab? { tabManager.activeTab }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let tab = activeTab {
                    WebViewContainer(
                        viewModel: tab.webViewModel,
                        toolbarVisible: $toolbarVisible,
                        showFindInPage: $showFindInPage
                    )
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    NewTabView()
                }
            }

            VStack(spacing: 0) {
                Spacer()
                if showFindInPage, let tab = activeTab {
                    FindInPageView(
                        viewModel: tab.webViewModel,
                        isVisible: $showFindInPage
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                BottomToolbarView(
                    activeTab: activeTab,
                    showTabOverview: $showTabOverview,
                    showBookmarks: $showBookmarks,
                    showHistory: $showHistory,
                    showSettings: $showSettings,
                    showShareSheet: $showShareSheet,
                    showFindInPage: $showFindInPage,
                    showDOMInspector: $showDOMInspector,
                    showJSConsole: $showJSConsole,
                    showPageActions: $showPageActions,
                    urlBarFocused: $urlBarFocused,
                    toolbarVisible: toolbarVisible
                )
            }
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = activeTab?.webViewModel.webView?.url {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showDOMInspector) {
            if let tab = activeTab {
                DOMInspectorView(viewModel: tab.webViewModel)
            }
        }
        .sheet(isPresented: $showJSConsole) {
            if let tab = activeTab {
                JSConsoleView(viewModel: tab.webViewModel)
            }
        }
        .sheet(isPresented: $showPageActions) {
            if let tab = activeTab {
                PageActionsView(viewModel: tab.webViewModel)
            }
        }
        .alert("JavaScript", isPresented: $showJSAlert, presenting: jsAlertMessage) { _ in
            Button("OK") {}
        } message: { msg in
            Text(msg)
        }
        .onReceive(NotificationCenter.default.publisher(for: .jsAlert)) { notification in
            if let msg = notification.userInfo?["message"] as? String {
                jsAlertMessage = msg
                showJSAlert = true
                if let completion = notification.userInfo?["completion"] as? () -> Void {
                    completion()
                }
            }
        }
    }
}

// MARK: - WebView Container

struct WebViewContainer: UIViewRepresentable {
    let viewModel: WebViewModel
    @Binding var toolbarVisible: Bool
    @Binding var showFindInPage: Bool

    func makeUIView(context: Context) -> WKWebView {
        let webView = viewModel.makeWebView()
        webView.scrollView.delegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(toolbarVisible: $toolbarVisible)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        @Binding var toolbarVisible: Bool
        private var lastOffset: CGFloat = 0

        init(toolbarVisible: Binding<Bool>) {
            _toolbarVisible = toolbarVisible
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let currentOffset = scrollView.contentOffset.y
            let delta = currentOffset - lastOffset
            if abs(delta) > 5 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    toolbarVisible = delta < 0 || currentOffset <= 0
                }
                lastOffset = currentOffset
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                withAnimation(.easeInOut(duration: 0.2)) {
                    toolbarVisible = true
                }
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            withAnimation(.easeInOut(duration: 0.2)) {
                toolbarVisible = true
            }
        }
    }
}

// MARK: - New Tab View

struct NewTabView: View {
    @EnvironmentObject var bookmarksManager: BookmarksManager
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var privateBrowsingManager: PrivateBrowsingManager

    let frequentSites: [(String, String, String)] = [
        ("Google", "https://google.com", "g.co"),
        ("YouTube", "https://youtube.com", "youtube.com"),
        ("Apple", "https://apple.com", "apple.com"),
        ("GitHub", "https://github.com", "github.com"),
        ("Reddit", "https://reddit.com", "reddit.com"),
        ("Twitter", "https://x.com", "x.com"),
        ("Wikipedia", "https://wikipedia.org", "wikipedia.org"),
        ("Amazon", "https://amazon.com", "amazon.com"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 60)

                if privateBrowsingManager.isPrivate {
                    PrivateBrowsingNewTabView()
                } else {
                    VStack(spacing: 8) {
                        Text("Favorites")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                            ForEach(frequentSites, id: \.0) { site in
                                Button {
                                    if let url = URL(string: site.1) {
                                        tabManager.activeTab?.webViewModel.load(url: url)
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray5))
                                            .frame(width: 52, height: 52)
                                            .overlay(
                                                Text(String(site.0.prefix(1)))
                                                    .font(.title2.weight(.semibold))
                                                    .foregroundColor(.primary)
                                            )
                                        Text(site.2)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer(minLength: 100)
            }
        }
        .background(Color(.systemBackground))
    }
}

struct PrivateBrowsingNewTabView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundColor(.purple)

            Text("Private Browsing Mode")
                .font(.title2.weight(.bold))

            Text("Safari won't remember the pages you visit, your search history, or your AutoFill information after you close a tab.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 40)
    }
}

// MARK: - Bottom Toolbar

struct BottomToolbarView: View {
    var activeTab: BrowserTab?
    @Binding var showTabOverview: Bool
    @Binding var showBookmarks: Bool
    @Binding var showHistory: Bool
    @Binding var showSettings: Bool
    @Binding var showShareSheet: Bool
    @Binding var showFindInPage: Bool
    @Binding var showDOMInspector: Bool
    @Binding var showJSConsole: Bool
    @Binding var showPageActions: Bool
    @Binding var urlBarFocused: Bool
    var toolbarVisible: Bool

    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var privateBrowsingManager: PrivateBrowsingManager
    @State private var showAddressBar = false

    var body: some View {
        VStack(spacing: 0) {
            if showAddressBar || urlBarFocused {
                AddressBarView(
                    viewModel: activeTab?.webViewModel,
                    isExpanded: $showAddressBar,
                    urlBarFocused: $urlBarFocused
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                Divider()
                    .opacity(toolbarVisible ? 1 : 0)

                HStack(spacing: 0) {
                    ToolbarButton(
                        icon: "chevron.left",
                        isEnabled: activeTab?.webViewModel.canGoBack ?? false
                    ) {
                        activeTab?.webViewModel.goBack()
                    }

                    ToolbarButton(
                        icon: "chevron.right",
                        isEnabled: activeTab?.webViewModel.canGoForward ?? false
                    ) {
                        activeTab?.webViewModel.goForward()
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showAddressBar.toggle()
                            urlBarFocused = showAddressBar
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if let tab = activeTab {
                                if tab.webViewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else if let favicon = tab.webViewModel.favicon {
                                    Image(uiImage: favicon)
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                } else {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text(displayText(for: tab.webViewModel))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 180)
                            } else {
                                Text("Search or enter website name")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray5))
                        )
                        .frame(maxWidth: 220)
                    }

                    Spacer()

                    ToolbarButton(icon: "square.and.arrow.up") {
                        showShareSheet = true
                    }

                    Button {
                        showTabOverview = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.primary, lineWidth: 1.5)
                                .frame(width: 20, height: 20)
                            Text("\(tabManager.tabs.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .frame(height: 50)
                .background(
                    privateBrowsingManager.isPrivate
                        ? Color(.systemGray6).opacity(0.98)
                        : Color(.systemBackground).opacity(0.98)
                )
                .opacity(toolbarVisible ? 1 : 0)
                .offset(y: toolbarVisible ? 0 : 60)
            }
            .animation(.easeInOut(duration: 0.2), value: toolbarVisible)
        }
    }

    private func displayText(for vm: WebViewModel) -> String {
        if vm.urlString.isEmpty { return "Search or enter website name" }
        if let url = URL(string: vm.urlString), let host = url.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return vm.urlString
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(isEnabled ? .blue : Color(.systemGray3))
                .frame(width: 44, height: 44)
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
