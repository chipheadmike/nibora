//
//  AttachmentGalleryScanner.swift
//  Nibora
//

import Foundation
import UniformTypeIdentifiers

struct GalleryAttachment: Identifiable {
    let url: URL
    let monthKey: String
    let fileName: String
    var id: URL { url }
}

/// Walks every month's Attachments/ folder and lists all image files,
/// chronologically (month folders sort as strings, and attachment
/// filenames are timestamp-prefixed, so simple name sorting is enough).
enum AttachmentGalleryScanner {
    static func scan(vaultURL: URL) -> [GalleryAttachment] {
        let fileManager = FileManager.default
        guard let monthFolders = try? fileManager.contentsOfDirectory(
            at: vaultURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [GalleryAttachment] = []
        for monthFolder in monthFolders.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let monthKey = monthFolder.lastPathComponent
            let attachmentsFolder = monthFolder.appendingPathComponent("Attachments")
            guard let files = try? fileManager.contentsOfDirectory(at: attachmentsFolder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            for fileURL in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where isImageFile(fileURL) {
                results.append(GalleryAttachment(url: fileURL, monthKey: monthKey, fileName: fileURL.lastPathComponent))
            }
        }
        return results
    }

    /// Finds the entry (if any) whose body references this attachment via
    /// "![](Attachments/<filename>)". Scoped to entries in the same month
    /// since attachment references are always month-relative.
    static func owningEntry(for attachment: GalleryAttachment, in entries: [JournalEntryRecord]) -> JournalEntryRecord? {
        entries.first { entry in
            guard entry.monthKey == attachment.monthKey else { return false }
            let nsBody = entry.searchableBody as NSString
            let matches = MarkdownTextView.imageReferencePattern.matches(in: entry.searchableBody, range: NSRange(location: 0, length: nsBody.length))
            return matches.contains { match in
                let relativeRef = nsBody.substring(with: match.range(at: 1))
                return (relativeRef as NSString).lastPathComponent == attachment.fileName
            }
        }
    }

    private static func isImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }
}
