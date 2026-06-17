import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject var bookmarksManager: BookmarksManager
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var editMode: EditMode = .inactive
    @State private var showAddFolder = false
    @State private var newFolderName = ""

    var filteredBookmarks: [Bookmark] {
        if searchText.isEmpty { return bookmarksManager.bookmarks(in: nil) }
        return bookmarksManager.bookmarks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.url.absoluteString.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            List {
                if !bookmarksManager.folders.isEmpty && searchText.isEmpty {
                    Section("Folders") {
                        ForEach(bookmarksManager.folders) { folder in
                            NavigationLink {
                                FolderBookmarksView(folder: folder)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.blue)
                                    Text(folder.name)
                                }
                            }
                        }
                        .onDelete { offsets in
                            offsets.forEach { i in
                                bookmarksManager.removeFolder(bookmarksManager.folders[i])
                            }
                        }
                    }
                }

                Section(searchText.isEmpty ? "Bookmarks" : "Results") {
                    ForEach(filteredBookmarks) { bookmark in
                        BookmarkRowView(bookmark: bookmark) {
                            tabManager.activeTab?.webViewModel.load(url: bookmark.url)
                            dismiss()
                        }
                    }
                    .onDelete { offsets in
                        let filtered = filteredBookmarks
                        offsets.forEach { i in bookmarksManager.removeBookmark(filtered[i]) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search Bookmarks")
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAddFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        EditButton()
                        Button("Done") { dismiss() }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .alert("New Folder", isPresented: $showAddFolder) {
                TextField("Folder Name", text: $newFolderName)
                Button("Cancel", role: .cancel) { newFolderName = "" }
                Button("Create") {
                    if !newFolderName.isEmpty {
                        bookmarksManager.addFolder(name: newFolderName)
                        newFolderName = ""
                    }
                }
            }
        }
    }
}

struct FolderBookmarksView: View {
    @EnvironmentObject var bookmarksManager: BookmarksManager
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.dismiss) var dismiss
    let folder: BookmarkFolder

    var body: some View {
        List {
            ForEach(bookmarksManager.bookmarks(in: folder)) { bookmark in
                BookmarkRowView(bookmark: bookmark) {
                    tabManager.activeTab?.webViewModel.load(url: bookmark.url)
                    dismiss()
                }
            }
            .onDelete { offsets in
                let items = bookmarksManager.bookmarks(in: folder)
                offsets.forEach { i in bookmarksManager.removeBookmark(items[i]) }
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BookmarkRowView: View {
    let bookmark: Bookmark
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    if let data = bookmark.faviconData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(bookmark.url.host ?? bookmark.url.absoluteString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
