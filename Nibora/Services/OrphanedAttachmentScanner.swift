//
//  OrphanedAttachmentScanner.swift
//  Nibora
//

import Foundation

/// Finds files under any month's Attachments/ folder that aren't referenced
/// by any entry's `![](...)` image markdown in that same month — leftovers
/// from deleted image references or deleted entries. Reads bodies fresh
/// from disk rather than the cached searchableBody, since this feeds a
/// delete action and needs to reflect what's actually on disk right now.
enum OrphanedAttachmentScanner {
    struct OrphanedFile: Identifiable {
        let url: URL
        let monthKey: String
        let fileName: String
        var id: URL { url }
    }

    static func scan(vaultURL: URL, entries: [JournalEntryRecord]) -> [OrphanedFile] {
        let fileManager = FileManager.default
        var referencedFileNamesByMonth: [String: Set<String>] = [:]

        for entry in entries {
            let fileURL = vaultURL.appendingPathComponent(entry.relativePath)
            guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let body = MarkdownFrontmatterParser.parse(contents).body
            let nsBody = body as NSString
            let matches = MarkdownTextView.imageReferencePattern.matches(in: body, range: NSRange(location: 0, length: nsBody.length))
            for match in matches {
                let relativeRef = nsBody.substring(with: match.range(at: 1))
                referencedFileNamesByMonth[entry.monthKey, default: []].insert((relativeRef as NSString).lastPathComponent)
            }
        }

        guard let monthFolders = try? fileManager.contentsOfDirectory(
            at: vaultURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var orphans: [OrphanedFile] = []
        for monthFolder in monthFolders {
            let monthKey = monthFolder.lastPathComponent
            let attachmentsFolder = monthFolder.appendingPathComponent("Attachments")
            guard let attachmentFiles = try? fileManager.contentsOfDirectory(
                at: attachmentsFolder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            let referenced = referencedFileNamesByMonth[monthKey] ?? []
            for fileURL in attachmentFiles where !referenced.contains(fileURL.lastPathComponent) {
                orphans.append(OrphanedFile(url: fileURL, monthKey: monthKey, fileName: fileURL.lastPathComponent))
            }
        }

        return orphans.sorted { $0.fileName < $1.fileName }
    }
}
