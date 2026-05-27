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

            // ── Find in Page + Bottom bar stack ─────────────────────
            VStack(spacing: 0) {
                Spacer()
                if vm.showFindInPage {
                    FindInPageBar(vm: vm)
                        .transition(.move(edge: .bottom))
                }
                SafariBottomBar(vm: vm)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.18), value: vm.showFindInPage)
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

// MARK: - Bottom bar
// Exact Safari layout: back | forward | url-pill | tabs | ellipsis.circle

struct SafariBottomBar: View {
    @ObservedObject var vm: BrowserViewModel
    @State private var showMenu = false
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {

                // ← Back
                BarButton(icon: "chevron.backward",
                          enabled: vm.canGoBack) { vm.navigateBack() }

                // → Forward
                BarButton(icon: "chevron.forward",
                          enabled: vm.canGoForward) { vm.navigateForward() }

                // URL pill
                AddressBarView(vm: vm)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 5)

                // Tabs square
                Button { vm.showTabGrid = true } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(.label), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        Text("\(vm.tabManager.tabs.count)")
                            .font(.system(
                                size: vm.tabManager.tabs.count > 9 ? 10 : 12,
                                weight: .bold, design: .rounded))
                            .foregroundColor(Color(.label))
                    }
                    .frame(width: 44, height: 44)
                }

                // ··· Ellipsis circle
                Button { showMenu = true } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .foregroundColor(Color(.label))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .background(.bar)
            .padding(.bottom, safeAreaBottom)
            .background(Material.bar)
        }
        .sheet(isPresented: $showMenu) {
            SafariMenuSheet(vm: vm, showShareSheet: $showShareSheet,
                            isPresented: $showMenu)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: vm.share())
        }
    }

    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - Menu sheet (ellipsis.circle → bottom sheet)
// Matches Safari: icon grid at top, action rows below

struct SafariMenuSheet: View {
    @ObservedObject var vm: BrowserViewModel
    @Binding var showShareSheet: Bool
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                // ── Icon grid ────────────────────────────────────────
                Section {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 4),
                        spacing: 12
                    ) {
                        MenuIconButton(icon: "book",             label: "Bookmarks")  { nav(.bookmarks) }
                        MenuIconButton(icon: "clock.arrow.circlepath", label: "History") { nav(.history) }
                        MenuIconButton(icon: "arrow.down.circle", label: "Downloads") { nav(.downloads) }
                        MenuIconButton(icon: "square.on.square", label: "All Tabs")   { navTabs() }
                    }
                    .padding(.vertical, 6)
                }

                // ── Action rows ──────────────────────────────────────
                Section {
                    MenuRow(icon: "square.and.arrow.up",   label: "Share…") {
                        close { showShareSheet = true }
                    }
                    MenuRow(icon: "plus.square",            label: "New Tab") {
                        isPresented = false
                        vm.openNewTab()
                    }
                    MenuRow(
                        icon:  vm.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark",
                        label: vm.isCurrentPageBookmarked ? "Remove Bookmark" : "Add Bookmark",
                        tint:  vm.isCurrentPageBookmarked ? .blue : nil
                    ) {
                        vm.toggleBookmark()
                        isPresented = false
                    }
                    MenuRow(icon: "doc.text.magnifyingglass", label: "Find on Page") {
                        close { vm.showFindInPage = true }
                    }
                    MenuRow(icon: "arrow.clockwise",         label: "Reload") {
                        vm.reload(); isPresented = false
                    }
                    MenuRow(icon: "gearshape",               label: "Settings") {
                        close { vm.activeSheet = .settings }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }.fontWeight(.semibold)
                }
            }
        }
    }

    private func nav(_ sheet: BrowserSheet) {
        close { vm.activeSheet = sheet }
    }

    private func navTabs() {
        close { vm.showTabGrid = true }
    }

    // Dismiss sheet first, then open next sheet after animation settles
    private func close(_ then: @escaping () -> Void) {
        isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: then)
    }
}

struct MenuIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    )
                Text(label)
                    .font(.system(size: 10))
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
                    .font(.system(size: 19))
                    .foregroundColor(tint ?? Color(.label))
                    .frame(width: 28, alignment: .center)
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
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { vm.findInPage(vm.findInPageQuery) }
                .onChange(of: vm.findInPageQuery) { q in
                    if !q.isEmpty { vm.findInPage(q) }
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
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
    }
}
