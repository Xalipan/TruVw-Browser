import Foundation

enum DownloadStatus: String, Codable {
    case inProgress, completed, failed, cancelled
}

class DownloadItem: Identifiable, ObservableObject {
    let id: UUID = UUID()
    let url: URL
    let filename: String
    let startDate: Date = Date()
    @Published var status: DownloadStatus = .inProgress
    @Published var bytesReceived: Int64 = 0
    @Published var totalBytes: Int64 = -1
    @Published var localURL: URL?

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesReceived) / Double(totalBytes)
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        if totalBytes > 0 {
            return "\(formatter.string(fromByteCount: bytesReceived)) / \(formatter.string(fromByteCount: totalBytes))"
        }
        return formatter.string(fromByteCount: bytesReceived)
    }

    init(url: URL, filename: String) {
        self.url = url
        self.filename = filename
    }
}
