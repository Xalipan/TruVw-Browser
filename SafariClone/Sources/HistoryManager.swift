import Foundation
import Combine

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    var title: String
    var url: URL
    var visitDate: Date
    var visitCount: Int

    init(title: String, url: URL) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.visitDate = Date()
        self.visitCount = 1
    }
}

class HistoryManager: ObservableObject {
    @Published var entries: [HistoryEntry] = []

    private let historyKey = "com.safariclone.history"
    private let maxEntries = 1000

    init() {
        load()
    }

    func recordVisit(title: String, url: URL) {
        let urlString = url.absoluteString
        if let existing = entries.firstIndex(where: { $0.url.absoluteString == urlString }) {
            entries[existing].title = title
            entries[existing].visitDate = Date()
            entries[existing].visitCount += 1
            let entry = entries.remove(at: existing)
            entries.insert(entry, at: 0)
        } else {
            let entry = HistoryEntry(title: title, url: url)
            entries.insert(entry, at: 0)
            if entries.count > maxEntries {
                entries = Array(entries.prefix(maxEntries))
            }
        }
        save()
    }

    func removeEntry(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clearHistory() {
        entries.removeAll()
        save()
    }

    func clearHistory(before date: Date) {
        entries.removeAll { $0.visitDate < date }
        save()
    }

    func search(query: String) -> [HistoryEntry] {
        guard !query.isEmpty else { return entries }
        let q = query.lowercased()
        return entries.filter {
            $0.title.lowercased().contains(q) || $0.url.absoluteString.lowercased().contains(q)
        }
    }

    var groupedEntries: [(String, [HistoryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry -> String in
            if calendar.isDateInToday(entry.visitDate) { return "Today" }
            if calendar.isDateInYesterday(entry.visitDate) { return "Yesterday" }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: entry.visitDate)
        }
        let sortedKeys = grouped.keys.sorted { a, b in
            let priority = ["Today": 0, "Yesterday": 1]
            if let pa = priority[a], let pb = priority[b] { return pa < pb }
            if priority[a] != nil { return true }
            if priority[b] != nil { return false }
            return a > b
        }
        return sortedKeys.compactMap { key in
            guard let items = grouped[key] else { return nil }
            return (key, items)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            entries = decoded
        }
    }
}
