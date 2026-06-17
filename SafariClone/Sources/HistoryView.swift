import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var showClearConfirm = false

    var body: some View {
        NavigationView {
            Group {
                if historyManager.entries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No History")
                            .font(.title3.weight(.medium))
                        Text("Websites you visit will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchText.isEmpty {
                    groupedHistoryList
                } else {
                    searchResultsList
                }
            }
            .searchable(text: $searchText, prompt: "Search History")
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") { showClearConfirm = true }
                        .foregroundColor(.red)
                        .disabled(historyManager.entries.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear History", isPresented: $showClearConfirm) {
                Button("Clear All History", role: .destructive) {
                    historyManager.clearHistory()
                }
                Button("Clear Today's History", role: .destructive) {
                    historyManager.clearHistory(before: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)))
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var groupedHistoryList: some View {
        List {
            ForEach(historyManager.groupedEntries, id: \.0) { group, entries in
                Section(group) {
                    ForEach(entries) { entry in
                        HistoryRowView(entry: entry) {
                            tabManager.activeTab?.webViewModel.load(url: entry.url)
                            dismiss()
                        }
                    }
                    .onDelete { offsets in
                        offsets.forEach { i in historyManager.removeEntry(entries[i]) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var searchResultsList: some View {
        List {
            let results = historyManager.search(query: searchText)
            if results.isEmpty {
                HStack {
                    Spacer()
                    Text("No results")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ForEach(results) { entry in
                    HistoryRowView(entry: entry) {
                        tabManager.activeTab?.webViewModel.load(url: entry.url)
                        dismiss()
                    }
                }
                .onDelete { offsets in
                    offsets.forEach { i in historyManager.removeEntry(results[i]) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct HistoryRowView: View {
    let entry: HistoryEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title.isEmpty ? entry.url.absoluteString : entry.title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(entry.url.host ?? entry.url.absoluteString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(timeAgo(entry.visitDate))
                    .font(.caption2)
                    .foregroundColor(Color(.systemGray3))
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
