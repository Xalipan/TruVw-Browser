import SwiftUI

struct DownloadsView: View {
    @ObservedObject var vm: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if vm.downloadManager.downloads.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Downloads")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Files you download appear here")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(vm.downloadManager.downloads) { item in
                            DownloadRow(item: item, vm: vm)
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !vm.downloadManager.completedDownloads.isEmpty {
                        Button("Clear") {
                            vm.downloadManager.clearCompleted()
                        }
                    }
                }
            }
        }
    }
}

struct DownloadRow: View {
    @ObservedObject var item: DownloadItem
    let vm: BrowserViewModel
    @State private var showShareSheet = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 28))
                .foregroundColor(iconColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename)
                    .font(.body)
                    .lineLimit(1)

                if item.status == .inProgress {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                    Text(item.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
            }

            Spacer()

            // Action button
            if item.status == .inProgress {
                Button {
                    vm.downloadManager.cancelDownload(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            } else if item.status == .completed, let url = item.localURL {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(items: [url])
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions {
            Button(role: .destructive) {
                vm.downloadManager.removeDownload(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    var iconName: String {
        let ext = (item.filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext.fill"
        case "zip", "gz", "rar", "tar": return "archivebox.fill"
        case "mp3", "m4a", "aac": return "music.note"
        case "mp4", "mov", "avi": return "film.fill"
        case "jpg", "jpeg", "png", "gif", "webp": return "photo.fill"
        case "doc", "docx": return "doc.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "ppt", "pptx": return "rectangle.stack.fill"
        default: return "arrow.down.circle.fill"
        }
    }

    var iconColor: Color {
        switch item.status {
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    var statusText: String {
        switch item.status {
        case .inProgress: return "Downloading…"
        case .completed: return item.formattedSize.isEmpty ? "Completed" : item.formattedSize
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var statusColor: Color {
        switch item.status {
        case .completed: return .secondary
        case .failed: return .red
        case .cancelled: return .secondary
        default: return .secondary
        }
    }
}
