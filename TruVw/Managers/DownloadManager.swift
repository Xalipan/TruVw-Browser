import Foundation
import Combine

class DownloadManager: NSObject, ObservableObject {
    @Published var downloads: [DownloadItem] = []

    private var sessions: [UUID: URLSessionDownloadTask] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    var activeDownloads: [DownloadItem] {
        downloads.filter { $0.status == .inProgress }
    }

    var completedDownloads: [DownloadItem] {
        downloads.filter { $0.status == .completed }
    }

    func startDownload(url: URL) {
        let filename = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
        let item = DownloadItem(url: url, filename: filename)
        downloads.insert(item, at: 0)

        let task = urlSession.downloadTask(with: url)
        sessions[item.id] = task
        task.taskDescription = item.id.uuidString
        task.resume()
    }

    func cancelDownload(_ item: DownloadItem) {
        sessions[item.id]?.cancel()
        sessions.removeValue(forKey: item.id)
        item.status = .cancelled
    }

    func removeDownload(_ item: DownloadItem) {
        downloads.removeAll { $0.id == item.id }
        if let localURL = item.localURL {
            try? FileManager.default.removeItem(at: localURL)
        }
    }

    func clearCompleted() {
        downloads.removeAll { $0.status == .completed || $0.status == .cancelled || $0.status == .failed }
    }

    private func saveToDownloads(_ tempURL: URL, filename: String) -> URL? {
        let fm = FileManager.default
        guard let downloadsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Downloads") else { return nil }

        try? fm.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        var destURL = downloadsDir.appendingPathComponent(filename)
        var counter = 1
        while fm.fileExists(atPath: destURL.path) {
            let name = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            let newName = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
            destURL = downloadsDir.appendingPathComponent(newName)
            counter += 1
        }

        do {
            try fm.moveItem(at: tempURL, to: destURL)
            return destURL
        } catch {
            return nil
        }
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let idStr = downloadTask.taskDescription,
              let id = UUID(uuidString: idStr),
              let item = downloads.first(where: { $0.id == id }) else { return }

        let savedURL = saveToDownloads(location, filename: item.filename)
        DispatchQueue.main.async {
            item.localURL = savedURL
            item.status = savedURL != nil ? .completed : .failed
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let idStr = downloadTask.taskDescription,
              let id = UUID(uuidString: idStr),
              let item = downloads.first(where: { $0.id == id }) else { return }
        DispatchQueue.main.async {
            item.bytesReceived = totalBytesWritten
            item.totalBytes = totalBytesExpectedToWrite
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error,
              let idStr = task.taskDescription,
              let id = UUID(uuidString: idStr),
              let item = downloads.first(where: { $0.id == id }) else { return }
        let cancelled = (error as NSError).code == NSURLErrorCancelled
        DispatchQueue.main.async {
            item.status = cancelled ? .cancelled : .failed
        }
    }
}
