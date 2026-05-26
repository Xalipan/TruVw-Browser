import SwiftUI

struct HistoryView: View {
    @ObservedObject var vm: BrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var displayGroups: [(String, [HistoryItem])] {
        if searchText.isEmpty {
            return vm.historyManager.groupedByDate
        }
        let results = vm.historyManager.search(searchText)
        return results.isEmpty ? [] : [("Results", results)]
    }

    var body: some View {
        NavigationView {
            Group {
                if vm.historyManager.items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No History")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Pages you visit appear here")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(displayGroups, id: \.0) { group, items in
                            Section(group) {
                                ForEach(items) { item in
                                    Button {
                                        vm.navigate(to: item.url.absoluteString)
                                        dismiss()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.displayTitle)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text(item.url.host ?? item.url.absoluteString)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            vm.historyManager.delete(item)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search History")
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            vm.historyManager.clearToday()
                        } label: {
                            Label("Clear Today", systemImage: "clock")
                        }
                        Button(role: .destructive) {
                            vm.historyManager.clearAll()
                        } label: {
                            Label("Clear All History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}
