import SwiftUI

struct StartPageView: View {
    @ObservedObject var vm: BrowserViewModel
    @Environment(\.colorScheme) private var colorScheme

    var topSites: [Bookmark] {
        Array(vm.bookmarkManager.bookmarks.prefix(8))
    }

    let columns = [GridItem(.adaptive(minimum: 64), spacing: 20)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {

                // ── Favorites ──────────────────────────────────────
                if !topSites.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Favorites")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(topSites) { bookmark in
                                FavoriteTile(bookmark: bookmark) {
                                    vm.navigate(to: bookmark.url.absoluteString)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // ── Recently Visited ───────────────────────────────
                if !vm.historyManager.items.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Recently Visited")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)

                        VStack(spacing: 0) {
                            ForEach(Array(vm.historyManager.items.prefix(6).enumerated()), id: \.element.id) { idx, item in
                                Button {
                                    vm.navigate(to: item.url.absoluteString)
                                } label: {
                                    HStack(spacing: 12) {
                                        // Favicon placeholder
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(faviconColor(for: item.url))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Text(String(item.displayTitle.prefix(1)).uppercased())
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                            )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.displayTitle)
                                                .font(.system(size: 15))
                                                .foregroundColor(Color(.label))
                                                .lineLimit(1)
                                            Text(item.url.host ?? "")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(.secondaryLabel))
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemBackground))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if idx < min(5, vm.historyManager.items.count - 1) {
                                    Divider().padding(.leading, 72)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    // Deterministic color per domain so tiles look consistent
    private func faviconColor(for url: URL) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo, .red]
        let hash = abs((url.host ?? "").hashValue)
        return colors[hash % colors.count]
    }
}

struct FavoriteTile: View {
    let bookmark: Bookmark
    let action: () -> Void

    // Deterministic color
    private var bgColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo, .red]
        let hash = abs(bookmark.url.host?.hashValue ?? bookmark.title.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(bgColor)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(String(bookmark.displayTitle.prefix(1)).uppercased())
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: bgColor.opacity(0.3), radius: 4, x: 0, y: 2)

                Text(bookmark.displayTitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color(.secondaryLabel))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
            }
        }
        .buttonStyle(.plain)
    }
}
