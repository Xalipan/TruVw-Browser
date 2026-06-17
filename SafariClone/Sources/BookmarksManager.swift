import Foundation
import Combine

struct Bookmark: Identifiable, Codable {
    let id: UUID
    var title: String
    var url: URL
    var faviconData: Data?
    var dateAdded: Date
    var folderId: UUID?

    init(title: String, url: URL, faviconData: Data? = nil, folderId: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.faviconData = faviconData
        self.dateAdded = Date()
        self.folderId = folderId
    }
}

struct BookmarkFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var dateCreated: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.dateCreated = Date()
    }
}

class BookmarksManager: ObservableObject {
    @Published var bookmarks: [Bookmark] = []
    @Published var folders: [BookmarkFolder] = []

    private let bookmarksKey = "com.safariclone.bookmarks"
    private let foldersKey = "com.safariclone.folders"

    init() {
        load()
        if bookmarks.isEmpty {
            seedDefaults()
        }
    }

    func addBookmark(title: String, url: URL, faviconData: Data? = nil, folderId: UUID? = nil) {
        let bookmark = Bookmark(title: title, url: url, faviconData: faviconData, folderId: folderId)
        bookmarks.insert(bookmark, at: 0)
        save()
    }

    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    func removeBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        save()
    }

    func updateBookmark(_ bookmark: Bookmark, title: String, url: URL) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index].title = title
            bookmarks[index].url = url
            save()
        }
    }

    func isBookmarked(url: URL) -> Bool {
        return bookmarks.contains { $0.url.absoluteString == url.absoluteString }
    }

    func toggleBookmark(title: String, url: URL, faviconData: Data? = nil) {
        if let existing = bookmarks.first(where: { $0.url.absoluteString == url.absoluteString }) {
            removeBookmark(existing)
        } else {
            addBookmark(title: title, url: url, faviconData: faviconData)
        }
    }

    func addFolder(name: String) {
        let folder = BookmarkFolder(name: name)
        folders.append(folder)
        save()
    }

    func removeFolder(_ folder: BookmarkFolder) {
        folders.removeAll { $0.id == folder.id }
        bookmarks.removeAll { $0.folderId == folder.id }
        save()
    }

    func bookmarks(in folder: BookmarkFolder?) -> [Bookmark] {
        if let folder = folder {
            return bookmarks.filter { $0.folderId == folder.id }
        }
        return bookmarks.filter { $0.folderId == nil }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: foldersKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            bookmarks = decoded
        }
        if let data = UserDefaults.standard.data(forKey: foldersKey),
           let decoded = try? JSONDecoder().decode([BookmarkFolder].self, from: data) {
            folders = decoded
        }
    }

    private func seedDefaults() {
        let defaults: [(String, String)] = [
            ("Apple", "https://apple.com"),
            ("Google", "https://google.com"),
            ("GitHub", "https://github.com"),
            ("Wikipedia", "https://wikipedia.org"),
        ]
        for (title, urlStr) in defaults {
            if let url = URL(string: urlStr) {
                addBookmark(title: title, url: url)
            }
        }
    }
}
