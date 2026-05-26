import Foundation

struct Bookmark: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var url: URL
    var faviconData: Data?
    var dateAdded: Date = Date()
    var folderID: UUID?  // nil = root

    var displayTitle: String {
        title.isEmpty ? url.host ?? url.absoluteString : title
    }
}

struct BookmarkFolder: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var parentID: UUID?
    var dateCreated: Date = Date()
}
