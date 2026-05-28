import SwiftUI

struct TabGridView: View {
    @ObservedObject var vm: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(vm.tabManager.tabs) { tab in
                        TabCard(tab: tab, isActive: tab.id == vm.tabManager.activeTabID) {
                            vm.tabManager.selectTab(tab)
                            vm.showTabGrid = false
                        } onClose: {
                            vm.tabManager.closeTab(tab)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { vm.showTabGrid = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            vm.openNewTab()
                        } label: {
                            Label("New Tab", systemImage: "plus")
                        }
                        Button(role: .destructive) {
                            vm.tabManager.closeAllTabs()
                        } label: {
                            Label("Close All Tabs", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    vm.openNewTab()
                } label: {
                    Label("New Tab", systemImage: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .padding()
                }
            }
        }
    }
}

struct TabCard: View {
    @ObservedObject var tab: Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card tap area
            Button(action: onSelect) {
                VStack(spacing: 0) {
                    // Header bar (no close button here)
                    HStack {
                        AsyncFaviconView(url: tab.url)
                            .frame(width: 16, height: 16)
                            .cornerRadius(3)
                        Text(tab.title.isEmpty ? "New Tab" : tab.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        Spacer()
                        // Spacer to reserve room for the close button overlay
                        Color.clear.frame(width: 28, height: 28)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))

                    // Snapshot preview
                    Group {
                        if let snapshot = tab.snapshot {
                            Image(uiImage: snapshot)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Color(.systemBackground))
                                .overlay(
                                    Image(systemName: "globe")
                                        .font(.system(size: 30))
                                        .foregroundColor(Color(.quaternaryLabel))
                                )
                        }
                    }
                    .frame(height: 120)
                    .clipped()
                }
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Close button sits on top, outside the card Button's touch area
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, Color(.systemGray3))
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
    }
}

struct AsyncFaviconView: View {
    let url: URL?
    var body: some View {
        Image(systemName: "globe")
            .resizable()
            .foregroundColor(.secondary)
    }
}
