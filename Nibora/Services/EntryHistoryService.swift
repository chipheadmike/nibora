//
//  EntryHistoryService.swift
//  Nibora
//

import Foundation

struct EntrySnapshot: Identifiable {
    let url: URL
    let date: Date
    var id: URL { url }
}

/// Pure-Swift version history — no subprocess, no sandbox risk (deliberately
/// chosen over shelling out to /usr/bin/git, which a sandboxed app can't
/// reliably do anyway). Each entry gets a hidden ".history/<filename>/"
/// folder alongside it in the same month directory, holding full-content
/// snapshots named by timestamp. ".history" is deliberately a dot-prefixed
/// (hidden) folder name so EntryIndexer's vault walk and the orphaned-
/// attachment scanner — both of which already skip hidden files/only look
/// for ".md"/"Attachments" — ignore it without any changes on their end.
enum EntryHistoryService {
    /// Throttles snapshots to at most one per this interval, so autosave
    /// (which fires ~1s after every pause in typing) doesn't create a new
    /// snapshot on nearly every keystroke.
    static let snapshotInterval: TimeInterval = 600

    static func historyFolder(for fileURL: URL) -> URL {
        fileURL.deletingLastPathComponent()
            .appendingPathComponent(".history", isDirectory: true)
            .appendingPathComponent(fileURL.lastPathComponent, isDirectory: true)
    }

    /// Snapshots whatever is currently on disk at `fileURL` — call this
    /// immediately before overwriting the file with new content, so the
    /// snapshot captures the version about to be replaced.
    static func snapshotIfNeeded(fileURL: URL) {
        guard let currentContents = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        let folder = historyFolder(for: fileURL)

        if let latest = snapshots(in: folder).first, Date().timeIntervalSince(latest.date) < snapshotInterval {
            return
        }

        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let timestamp = timestampFormatter.string(from: Date())
        let snapshotURL = folder.appendingPathComponent("\(timestamp).md")
        try? currentContents.write(to: snapshotURL, atomically: true, encoding: .utf8)
    }

    static func snapshots(for fileURL: URL) -> [EntrySnapshot] {
        snapshots(in: historyFolder(for: fileURL))
    }

    private static func snapshots(in folder: URL) -> [EntrySnapshot] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> EntrySnapshot? in
                guard let date = timestampFormatter.date(from: url.deletingPathExtension().lastPathComponent) else { return nil }
                return EntrySnapshot(url: url, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
