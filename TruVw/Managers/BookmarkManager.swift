import Foundation
import Combine

class BookmarkManager: ObservableObject {
    @Published var bookmarks: [Bookmark] = []
    @Published var folders: [BookmarkFolder] = []

    private let bookmarksKey = "bookmarks_v1"
    private let foldersKey = "bookmark_folders_v1"

    init() {
        load()
        if bookmarks.isEmpty {
            seedDefaults()
        }
    }

    // MARK: - CRUD

    func addBookmark(title: String, url: URL, folderID: UUID? = nil) {
        let bm = Bookmark(title: title, url: url, folderID: folderID)
        bookmarks.insert(bm, at: 0)
        save()
    }

    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    func updateBookmark(_ bookmark: Bookmark) {
        if let idx = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[idx] = bookmark
            save()
        }
    }

    func isBookmarked(url: URL) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    func bookmark(for url: URL) -> Bookmark? {
        bookmarks.first { $0.url == url }
    }

    func addFolder(name: String, parentID: UUID? = nil) {
        let folder = BookmarkFolder(name: name, parentID: parentID)
        folders.append(folder)
        save()
    }

    func removeFolder(_ folder: BookmarkFolder) {
        folders.removeAll { $0.id == folder.id }
        bookmarks.removeAll { $0.folderID == folder.id }
        save()
    }

    func bookmarks(inFolder folderID: UUID?) -> [Bookmark] {
        bookmarks.filter { $0.folderID == folderID }
    }

    // MARK: - Persistence

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
            ("Apple", "https://www.apple.com"),
            ("Google", "https://www.google.com"),
            ("Wikipedia", "https://www.wikipedia.org"),
        ]
        for (title, urlStr) in defaults {
            if let url = URL(string: urlStr) {
                bookmarks.append(Bookmark(title: title, url: url))
            }
        }
        save()
    }
}
