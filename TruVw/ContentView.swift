import SwiftUI

// MARK: - Content View
// Uses NavigationStack + .toolbar placement so the system handles
// transparency, safe-area insets, and keyboard avoidance natively.

struct ContentView: View {
    @StateObject private var vm = BrowserViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Web content fills the whole screen behind everything
                ForEach(vm.tabManager.tabs) { tab in
                    TabContentView(tab: tab, vm: vm)
                        .opacity(tab.id == vm.tabManager.activeTabID ? 1 : 0)
                        .allowsHitTesting(tab.id == vm.tabManager.activeTabID)
                }

                // Suggestion overlay shown while address bar is focused
                if vm.isEditingAddress {
                    SuggestionsOverlay(vm: vm)
                        .transition(.opacity)
                }

                // Find-in-page bar floats above the toolbar
                if vm.showFindInPage {
                    VStack {
                        Spacer()
                        FindInPageBar(vm: vm)
                            .padding(.bottom, 44) // clear the toolbar
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea()
            .toolbar {
                // ── Bottom toolbar ────────────────────────────────
                // When NOT editing: [← →]  [url | reload]  [⋯]
                // When editing:     nothing — AddressBarView expands full-width

                if !vm.isEditingAddress {
                    ToolbarItem(placement: .bottomBar) {
                        // Back / Forward grouped pill
                        HStack(spacing: 0) {
                            Button { vm.navigateBack() } label: {
                                Image(systemName: "chevron.backward")
                                    .font(.system(size: 20))
                            }
                            .disabled(!vm.canGoBack)

                            if vm.canGoForward {
                                Divider().frame(height: 18).padding(.horizontal, 4)
                                Button { vm.navigateForward() } label: {
                                    Image(systemName: "chevron.forward")
                                        .font(.system(size: 20))
                                }
                            }
                        }
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }

                // Address bar + reload — grouped, expands to fill space
                ToolbarItem(placement: .bottomBar) {
                    AddressBarView(vm: vm)
                        .frame(minWidth: vm.isEditingAddress ? 280 : 180)
                }

                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }

                if !vm.isEditingAddress {
                    ToolbarItem(placement: .bottomBar) {
                        Menu {
                            Button { vm.showShareSheet = true } label: {
                                Label("Share…", systemImage: "square.and.arrow.up")
                            }
                            Button { vm.openNewTab() } label: {
                                Label("New Tab", systemImage: "plus.square")
                            }
                            Button {
                                vm.toggleBookmark()
                            } label: {
                                Label(
                                    vm.isCurrentPageBookmarked ? "Remove Bookmark" : "Add Bookmark",
                                    systemImage: vm.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark"
                                )
                            }
                            Button { vm.showFindInPage = true } label: {
                                Label("Find on Page", systemImage: "doc.text.magnifyingglass")
                            }
                            Button { vm.reload() } label: {
                                Label("Reload", systemImage: "arrow.clockwise")
                            }
                            Divider()
                            Button { vm.activeSheet = .bookmarks } label: {
                                Label("Bookmarks", systemImage: "book")
                            }
                            Button { vm.activeSheet = .history } label: {
                                Label("History", systemImage: "clock.arrow.circlepath")
                            }
                            Button { vm.activeSheet = .downloads } label: {
                                Label("Downloads", systemImage: "arrow.down.circle")
                            }
                            Button { vm.showTabGrid = true } label: {
                                Label("All Tabs", systemImage: "square.on.square")
                            }
                            Divider()
                            Button { vm.activeSheet = .settings } label: {
                                Label("Settings", systemImage: "gearshape")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20))
                        }
                    }
                }
            }
            .toolbarBackground(.regularMaterial, for: .bottomBar)
            .toolbarBackground(.visible, for: .bottomBar)
            .animation(.easeInOut(duration: 0.2), value: vm.isEditingAddress)
            .animation(.easeInOut(duration: 0.18), value: vm.showFindInPage)
        }
        .sheet(isPresented: $vm.showShareSheet) { ShareSheet(items: vm.share()) }
        .sheet(isPresented: $vm.showTabGrid) { TabGridView(vm: vm) }
        .sheet(item: $vm.activeSheet) { sheet in
            switch sheet {
            case .bookmarks: BookmarksView(vm: vm)
            case .history:   HistoryView(vm: vm)
            case .downloads: DownloadsView(vm: vm)
            case .settings:  SettingsView(vm: vm)
            case .tabs:      TabGridView(vm: vm)
            }
        }
    }
}

// MARK: - Suggestions overlay (shown when address bar is focused)

struct SuggestionsOverlay: View {
    @ObservedObject var vm: BrowserViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark
                  ? Color(.systemBackground).opacity(0.95)
                  : Color(.systemBackground).opacity(0.97))
            .ignoresSafeArea()
            .onTapGesture {
                vm.isEditingAddress = false
            }
    }
}

// MARK: - Tab Content

struct TabContentView: View {
    @ObservedObject var tab: Tab
    @ObservedObject var vm: BrowserViewModel
    var body: some View {
        if tab.hasNavigated {
            WebView(tab: tab, vm: vm).ignoresSafeArea()
        } else {
            StartPageView(vm: vm).ignoresSafeArea()
        }
    }
}

// MARK: - Find in Page Bar

struct FindInPageBar: View {
    @ObservedObject var vm: BrowserViewModel
    @FocusState private var focused: Bool
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Find on page", text: $vm.findInPageQuery)
                .focused($focused).submitLabel(.search)
                .onSubmit { vm.findInPage(vm.findInPageQuery) }
                .onChange(of: vm.findInPageQuery) { q in if !q.isEmpty { vm.findInPage(q) } }
            Spacer()
            Button("Done") { vm.showFindInPage = false; vm.findInPageQuery = "" }
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .top) { Divider() }
        .onAppear { focused = true }
    }
}

// MARK: - Reusable bar button

struct BarButton: View {
    let icon: String
    var size: CGFloat = 22
    var weight: Font.Weight = .regular
    var enabled: Bool = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: weight))
                .foregroundColor(enabled ? Color(.label) : Color(.tertiaryLabel))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .disabled(!enabled)
    }
}
