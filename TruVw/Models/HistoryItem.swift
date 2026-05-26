import Foundation

struct HistoryItem: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var url: URL
    var visitDate: Date = Date()
    var visitCount: Int = 1

    var displayTitle: String {
        title.isEmpty ? url.host ?? url.absoluteString : title
    }

    var dateGroupKey: String {
        let cal = Calendar.current
        if cal.isDateInToday(visitDate) { return "Today" }
        if cal.isDateInYesterday(visitDate) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: visitDate)
    }
}
