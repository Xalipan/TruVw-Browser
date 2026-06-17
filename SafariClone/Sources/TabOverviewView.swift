import SwiftUI

struct TabOverviewView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var privateBrowsingManager: PrivateBrowsingManager
    @Binding var showTabOverview: Bool

    @State private var showNewTabMenu = false
    @Namespace private var animation

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            (privateBrowsingManager.isPrivate ? Color.black : Color(.systemGroupedBackground))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                tabOverviewHeader

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                            TabCardView(
                                tab: tab,
                                isActive: tabManager.activeTabIndex == index,
                                onClose: {
                                    withAnimation(.spring(response: 0.3)) {
                                        tabManager.closeTab(tab)
                                    }
                                },
                                onSelect: {
                                    tabManager.selectTab(tab)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        showTabOverview = false
                                    }
                                }
                            )
                            .matchedGeometryEffect(id: tab.id, in: animation)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }

                tabOverviewFooter
            }
        }
    }

    private var tabOverviewHeader: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    privateBrowsingManager.isPrivate.toggle()
                }
            } label: {
                Text(privateBrowsingManager.isPrivate ? "Private" : "Private")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(privateBrowsingManager.isPrivate ? .purple : .secondary)
            }

            Spacer()

            Text("\(tabManager.tabs.count) Tabs")
                .font(.headline.weight(.semibold))
                .foregroundColor(privateBrowsingManager.isPrivate ? .white : .primary)

            Spacer()

            Button("Done") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showTabOverview = false
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.blue)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            privateBrowsingManager.isPrivate
                ? Color(.systemGray6).opacity(0.3)
                : Color(.systemGroupedBackground)
        )
    }

    private var tabOverviewFooter: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    tabManager.addNewTab(isPrivate: privateBrowsingManager.isPrivate)
                    showTabOverview = false
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(privateBrowsingManager.isPrivate ? .purple : .blue)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                showNewTabMenu = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.on.square")
                    Text("New Tab")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(privateBrowsingManager.isPrivate ? .purple : .blue)
            }
            .confirmationDialog("Tab Actions", isPresented: $showNewTabMenu) {
                Button("New Tab") {
                    tabManager.addNewTab(isPrivate: privateBrowsingManager.isPrivate)
                    showTabOverview = false
                }
                Button("Close All Tabs", role: .destructive) {
                    tabManager.closeAllTabs(isPrivate: privateBrowsingManager.isPrivate)
                    showTabOverview = false
                }
            }

            Spacer()

            Button {
                tabManager.addNewTab(isPrivate: privateBrowsingManager.isPrivate)
                showTabOverview = false
            } label: {
                Text("New Tab")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(privateBrowsingManager.isPrivate ? .purple : .blue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            privateBrowsingManager.isPrivate
                ? Color.black.opacity(0.9)
                : Color(.systemBackground).opacity(0.98)
        )
        .overlay(Divider(), alignment: .top)
    }
}

// MARK: - Tab Card

struct TabCardView: View {
    let tab: BrowserTab
    let isActive: Bool
    let onClose: () -> Void
    let onSelect: () -> Void

    @ObservedObject var viewModel: WebViewModel
    @EnvironmentObject var privateBrowsingManager: PrivateBrowsingManager

    init(tab: BrowserTab, isActive: Bool, onClose: @escaping () -> Void, onSelect: @escaping () -> Void) {
        self.tab = tab
        self.isActive = isActive
        self.onClose = onClose
        self.onSelect = onSelect
        self.viewModel = tab.webViewModel
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    if let favicon = viewModel.favicon {
                        Image(uiImage: favicon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Text(viewModel.title.isEmpty ? "New Tab" : viewModel.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .foregroundColor(privateBrowsingManager.isPrivate ? .white : .primary)

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color(.systemGray5)))
                    }
                }
                .padding(8)
                .background(isActive ? Color.blue.opacity(0.15) : Color(.systemBackground))

                ZStack {
                    if let snapshot = tab.snapshot {
                        Image(uiImage: snapshot)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray6))
                            .frame(height: 150)
                            .overlay(
                                Image(systemName: "safari.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(Color(.systemGray4))
                            )
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isActive ? Color.blue : Color(.systemGray4),
                        lineWidth: isActive ? 2 : 0.5
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
