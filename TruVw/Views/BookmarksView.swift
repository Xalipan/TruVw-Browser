import SwiftUI

struct BookmarksView: View {
    @ObservedObject var vm: BrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showAddFolder = false
    @State private var newFolderName = ""
    @State private var currentFolderID: UUID? = nil
    @State private var editMode: EditMode = .inactive

    var filteredBookmarks: [Bookmark] {
        let inFolder = vm.bookmarkManager.bookmarks(inFolder: currentFolderID)
        if searchText.isEmpty { return inFolder }
        return inFolder.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.url.absoluteString.localizedCaseInsensitiveContains(searchText)
        }
    }

    var currentFolders: [BookmarkFolder] {
        vm.bookmarkManager.folders.filter { $0.parentID == currentFolderID }
    }

    var body: some View {
        NavigationView {
            List {
                // Folders
                ForEach(currentFolders) { folder in
                    Button {
                        currentFolderID = folder.id
                    } label: {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.yellow)
                            Text(folder.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { vm.bookmarkManager.removeFolder(currentFolders[$0]) }
                }

                // Bookmarks
                ForEach(filteredBookmarks) { bookmark in
                    Button {
                        vm.navigate(to: bookmark.url.absoluteString)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bookmark.displayTitle)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(bookmark.url.host ?? bookmark.url.absoluteString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            vm.bookmarkManager.removeBookmark(bookmark)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search Bookmarks")
            .navigationTitle(currentFolderID == nil ? "Bookmarks" : vm.bookmarkManager.folders.first(where: { $0.id == currentFolderID })?.name ?? "Folder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentFolderID != nil {
                        Button { currentFolderID = nil } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Bookmarks")
                            }
                        }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showAddFolder = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                        Button(role: .destructive) {
                            // handled inline via swipe
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("New Folder", isPresented: $showAddFolder) {
                TextField("Folder Name", text: $newFolderName)
                Button("Cancel", role: .cancel) { newFolderName = "" }
                Button("Save") {
                    if !newFolderName.isEmpty {
                        vm.bookmarkManager.addFolder(name: newFolderName, parentID: currentFolderID)
                        newFolderName = ""
                    }
                }
            }
        }
    }
}
