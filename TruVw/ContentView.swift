import SwiftUI

struct ContentView: View {
    @StateObject private var vm = BrowserViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Web content — full screen ────────────────────────────
            ZStack {
                ForEach(vm.tabManager.tabs) { tab in
                    TabContentView(tab: tab, vm: vm)
                        .opacity(tab.id == vm.tabManager.activeTabID ? 1 : 0)
                        .allowsHitTesting(tab.id == vm.tabManager.activeTabID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // ── Find in Page bar sits above bottom bar ───────────────
            VStack(spacing: 0) {
                Spacer()
                if vm.showFindInPage {
                    FindInPageBar(vm: vm)
                        .transition(.move(edge: .bottom))
                }
                // ── Bottom bar — Safari-identical ────────────────────
                SafariBottomBar(vm: vm)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.18), value: vm.showFindInPage)
        // ── Sheets ───────────────────────────────────────────────────
        .sheet(isPresented: $vm.showTabGrid) {
            TabGridView(vm: vm)
        }
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

// MARK: - Safari Bottom Bar
// Layout (left→right): back | forward | [url pill] | tabs | ellipsis

struct SafariBottomBar: View {
    @ObservedObject var vm: BrowserViewModel
    @State private var showMenu = false
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                // Back
                BarButton(icon: "chevron.left", size: 21, weight: .medium,
                          enabled: vm.canGoBack) { vm.navigateBack() }

                // Forward
                BarButton(icon: "chevron.right", size: 21, weight: .medium,
                          enabled: vm.canGoForward) { vm.navigateForward() }

                // URL pill — fills remaining space
                AddressBarView(vm: vm)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 6)

                // Tab switcher
                Button {
                    vm.showTabGrid = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(.label), lineWidth: 1.6)
                            .frame(width: 23, height: 23)
                        Text("\(vm.tabManager.tabs.count)")
                            .font(.system(
                                size: vm.tabManager.tabs.count > 9 ? 10 : 12,
                                weight: .bold, design: .rounded))
                            .foregroundColor(Color(.label))
                    }
                    .frame(width: 46, height: 44)
                }

                // Ellipsis — opens Safari-style action sheet
                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(Color(.label))
                        .frame(width: 46, height: 44)
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 44)
            .background(.bar)
            // Safe area padding so bar clears home indicator
            .padding(.bottom, bottomSafeArea)
            .background(Material.bar)
        }
        // ── Ellipsis context menu sheet ──────────────────────────────
        .sheet(isPresented: $showMenu) {
            SafariMenuSheet(vm: vm, showShareSheet: $showShareSheet, isPresented: $showMenu)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: vm.share())
        }
    }

    private var bottomSafeArea: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0)
    }
}

// MARK: - Safari Menu Sheet (ellipsis → bottom sheet)
// Top row: icon grid (Bookmarks, History, Downloads, New Tab)
// Below: list of additional actions

struct SafariMenuSheet: View {
    @ObservedObject var vm: BrowserViewModel
    @Binding var showShareSheet: Bool
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                // ── Icon grid row ────────────────────────────────────
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        MenuIconButton(icon: "book", label: "Bookmarks") {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.activeSheet = .bookmarks
                            }
                        }
                        MenuIconButton(icon: "clock", label: "History") {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.activeSheet = .history
                            }
                        }
                        MenuIconButton(icon: "arrow.down.circle", label: "Downloads") {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.activeSheet = .downloads
                            }
                        }
                        MenuIconButton(icon: "square.on.square", label: "All Tabs") {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.showTabGrid = true
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // ── Action list ──────────────────────────────────────
                Section {
                    MenuRow(icon: "square.and.arrow.up", label: "Share…") {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showShareSheet = true
                        }
                    }
                    MenuRow(icon: "plus", label: "New Tab") {
                        isPresented = false
                        vm.openNewTab()
                    }
                    MenuRow(icon: vm.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark",
                            label: vm.isCurrentPageBookmarked ? "Remove Bookmark" : "Add Bookmark",
                            tint: vm.isCurrentPageBookmarked ? .blue : nil) {
                        vm.toggleBookmark()
                        isPresented = false
                    }
                    MenuRow(icon: "textformat.size", label: "Find on Page") {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            vm.showFindInPage = true
                        }
                    }
                    MenuRow(icon: "arrow.clockwise", label: "Reload") {
                        vm.reload()
                        isPresented = false
                    }
                    MenuRow(icon: "gearshape", label: "Settings") {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            vm.activeSheet = .settings
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct MenuIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    )
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(Color(.secondaryLabel))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MenuRow: View {
    let icon: String
    let label: String
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(tint ?? Color(.label))
                    .frame(width: 26)
                Text(label)
                    .foregroundColor(Color(.label))
                Spacer()
            }
        }
    }
}

// MARK: - Tab Content

struct TabContentView: View {
    @ObservedObject var tab: Tab
    @ObservedObject var vm: BrowserViewModel

    var body: some View {
        if tab.hasNavigated {
            WebView(tab: tab, vm: vm)
                .ignoresSafeArea()
        } else {
            StartPageView(vm: vm)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Find in Page Bar

struct FindInPageBar: View {
    @ObservedObject var vm: BrowserViewModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Find on page", text: $vm.findInPageQuery)
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { vm.findInPage(vm.findInPageQuery) }
                .onChange(of: vm.findInPageQuery) { query in
                    if !query.isEmpty { vm.findInPage(query) }
                }
            Spacer()
            Button("Done") {
                vm.showFindInPage = false
                vm.findInPageQuery = ""
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .top) { Divider() }
        .onAppear { focused = true }
    }
}

// MARK: - Shared bar button

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
                .frame(width: 46, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
    }
}
