import SwiftUI

// MARK: - Content View

struct ContentView: View {
    @StateObject private var vm = BrowserViewModel()

    var body: some View {
        // The toolbar VStack lives in normal layout flow so SwiftUI's
        // built-in keyboard avoidance moves it up automatically.
        // The web content is attached as a .background() — it expands
        // to fill the screen behind the toolbar without affecting the
        // layout of the toolbar itself or its safe area handling.
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if vm.showFindInPage {
                FindInPageBar(vm: vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            SafariBottomBar(vm: vm)
        }
        .background(
            ZStack {
                ForEach(vm.tabManager.tabs) { tab in
                    TabContentView(tab: tab, vm: vm)
                        .opacity(tab.id == vm.tabManager.activeTabID ? 1 : 0)
                        .allowsHitTesting(tab.id == vm.tabManager.activeTabID)
                }
            }
            .ignoresSafeArea()
        )
        .ignoresSafeArea(.container, edges: .bottom)
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

// MARK: - Safari-style bottom toolbar (Liquid Glass, iOS 26)
//
// Layout:  [← →]  [         URL pill         ]  [↺]  [⋯]
//           pill   grows to fill remaining space
//
// Each interactive cluster sits inside a rounded-rect "glass" capsule
// (ultraThinMaterial) that matches Safari's liquid-glass toolbar aesthetic.

struct SafariBottomBar: View {
    @ObservedObject var vm: BrowserViewModel
    @State private var showMenu        = false
    @State private var showShareSheet  = false

    // The safe-area bottom inset — we extend the toolbar background
    // down into this space but keep controls above it.
    private var safeAreaBottom: CGFloat {
        UIApplication.keyWindow?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hairline separator at the very top of the bar
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(height: 0.5)

            HStack(spacing: 10) {

                // ── Back / Forward cluster ───────────────────────────
                // Single pill: back always visible, forward only when available
                HStack(spacing: 0) {
                    GlassBarButton(icon: "chevron.backward",
                                   enabled: vm.canGoBack) { vm.navigateBack() }

                    if vm.canGoForward {
                        Rectangle()
                            .fill(Color(.separator).opacity(0.5))
                            .frame(width: 0.5, height: 22)
                        GlassBarButton(icon: "chevron.forward",
                                       enabled: true) { vm.navigateForward() }
                    }
                }
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))

                // ── URL pill ─────────────────────────────────────────
                AddressBarView(vm: vm)
                    .frame(maxWidth: .infinity)

                // ── Reload / Stop ────────────────────────────────────
                GlassBarButton(
                    icon: vm.isLoading ? "xmark" : "arrow.clockwise",
                    enabled: vm.currentURL != nil || vm.isLoading
                ) {
                    vm.isLoading ? vm.stopLoading() : vm.reload()
                }
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                .disabled(vm.currentURL == nil && !vm.isLoading)

                // ── Tabs square ──────────────────────────────────────
                Button { vm.showTabGrid = true } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(.label), lineWidth: 1.7)
                            .frame(width: 21, height: 21)
                        Text("\(vm.tabManager.tabs.count)")
                            .font(.system(
                                size: vm.tabManager.tabs.count > 9 ? 9 : 11,
                                weight: .bold, design: .rounded))
                            .foregroundColor(Color(.label))
                    }
                    .frame(width: 48, height: 48)
                }
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))

                // ── Ellipsis (more) ──────────────────────────────────
                GlassBarButton(icon: "ellipsis", enabled: true) { showMenu = true }
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8 + safeAreaBottom)
            .background(.ultraThinMaterial)
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
}

// A single icon button sized to match Safari's toolbar targets
struct GlassBarButton: View {
    let icon: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(enabled ? Color(.label) : Color(.tertiaryLabel))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
    }
}

// MARK: - Menu sheet

struct SafariMenuSheet: View {
    @ObservedObject var vm: BrowserViewModel
    @Binding var showShareSheet: Bool
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                Section {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 4),
                        spacing: 12
                    ) {
                        MenuIconButton(icon: "book",                   label: "Bookmarks")  { nav(.bookmarks) }
                        MenuIconButton(icon: "clock.arrow.circlepath", label: "History")    { nav(.history) }
                        MenuIconButton(icon: "arrow.down.circle",      label: "Downloads")  { nav(.downloads) }
                        MenuIconButton(icon: "square.on.square",       label: "All Tabs")   { navTabs() }
                    }
                    .padding(.vertical, 6)
                }
                Section {
                    MenuRow(icon: "square.and.arrow.up", label: "Share…") {
                        close { showShareSheet = true }
                    }
                    MenuRow(icon: "plus.square", label: "New Tab") {
                        isPresented = false; vm.openNewTab()
                    }
                    MenuRow(
                        icon:  vm.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark",
                        label: vm.isCurrentPageBookmarked ? "Remove Bookmark" : "Add Bookmark",
                        tint:  vm.isCurrentPageBookmarked ? .blue : nil
                    ) { vm.toggleBookmark(); isPresented = false }
                    MenuRow(icon: "doc.text.magnifyingglass", label: "Find on Page") {
                        close { vm.showFindInPage = true }
                    }
                    MenuRow(icon: "arrow.clockwise", label: "Reload") {
                        vm.reload(); isPresented = false
                    }
                    MenuRow(icon: "gearshape", label: "Settings") {
                        close { vm.activeSheet = .settings }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }.fontWeight(.semibold)
                }
            }
        }
    }

    private func nav(_ sheet: BrowserSheet) { close { vm.activeSheet = sheet } }
    private func navTabs() { close { vm.showTabGrid = true } }
    private func close(_ then: @escaping () -> Void) {
        isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: then)
    }
}

struct MenuIconButton: View {
    let icon: String; let label: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 54, height: 54)
                    .overlay(Image(systemName: icon).font(.system(size: 22)).foregroundColor(.blue))
                Text(label).font(.system(size: 10)).foregroundColor(Color(.secondaryLabel)).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MenuRow: View {
    let icon: String; let label: String; var tint: Color? = nil; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 19))
                    .foregroundColor(tint ?? Color(.label)).frame(width: 28, alignment: .center)
                Text(label).foregroundColor(Color(.label))
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

// MARK: - Reusable bar button (kept for any other callers)

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
