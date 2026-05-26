import Foundation
import Combine

class HistoryManager: ObservableObject {
    @Published var items: [HistoryItem] = []

    private let storageKey = "history_v1"
    private let maxItems = 10000

    init() {
        load()
    }

    func record(title: String, url: URL) {
        // Don't track internal/blank pages
        guard url.scheme == "https" || url.scheme == "http" else { return }

        if let idx = items.firstIndex(where: { $0.url == url }) {
            items[idx].visitDate = Date()
            items[idx].visitCount += 1
            let updated = items.remove(at: idx)
            items.insert(updated, at: 0)
        } else {
            let item = HistoryItem(title: title, url: url)
            items.insert(item, at: 0)
            if items.count > maxItems {
                items = Array(items.prefix(maxItems))
            }
        }
        save()
    }

    func delete(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        items.removeAll()
        save()
    }

    func clearToday() {
        items.removeAll { Calendar.current.isDateInToday($0.visitDate) }
        save()
    }

    func search(_ query: String) -> [HistoryItem] {
        guard !query.isEmpty else { return items }
        let q = query.lowercased()
        return items.filter {
            $0.title.lowercased().contains(q) ||
            $0.url.absoluteString.lowercased().contains(q)
        }
    }

    var groupedByDate: [(String, [HistoryItem])] {
        let grouped = Dictionary(grouping: items) { $0.dateGroupKey }
        let order = ["Today", "Yesterday"]
        var result: [(String, [HistoryItem])] = []

        for key in order {
            if let group = grouped[key] {
                result.append((key, group))
            }
        }
        for (key, group) in grouped.sorted(by: { $0.key > $1.key }) {
            if !order.contains(key) {
                result.append((key, group))
            }
        }
        return result
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = decoded
        }
    }
}
