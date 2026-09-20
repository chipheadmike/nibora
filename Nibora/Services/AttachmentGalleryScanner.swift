//
//  AttachmentGalleryScanner.swift
//  Nibora
//

import Foundation
import UniformTypeIdentifiers

struct GalleryAttachment: Identifiable {
    enum Kind {
        case image
        case video
    }

    let url: URL
    /// Vault-relative path of the folder this attachment's Attachments/
    /// folder lives in ("" = vault root) — a Journal vault's month folder
    /// name, or a Freeform vault's (possibly nested) folder path.
    let folderRelativePath: String
    let fileName: String
    let kind: Kind
    var id: URL { url }
}

/// Recursively finds every Attachments/ folder anywhere in the vault and
/// lists their image and video files — a plain one-level walk (Journal's
/// month folders only) would silently miss Freeform vaults' arbitrarily
/// nested Attachments folders.
enum AttachmentGalleryScanner {
    static func scan(vaultURL: URL) -> [GalleryAttachment] {
        var results: [GalleryAttachment] = []
        walk(vaultURL, relativePath: "", results: &results)
        return results.sorted {
            $0.folderRelativePath == $1.folderRelativePath ? $0.fileName < $1.fileName : $0.folderRelativePath < $1.folderRelativePath
        }
    }

    private static func walk(_ folderURL: URL, relativePath: String, results: inout [GalleryAttachment]) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }

        for itemURL in contents {
            let isDirectory = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory else { continue }

            if itemURL.lastPathComponent == "Attachments" {
                guard let files = try? fileManager.contentsOfDirectory(at: itemURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                for fileURL in files {
                    if isImageFile(fileURL) {
                        results.append(GalleryAttachment(url: fileURL, folderRelativePath: relativePath, fileName: fileURL.lastPathComponent, kind: .image))
                    } else if isVideoFile(fileURL) {
                        results.append(GalleryAttachment(url: fileURL, folderRelativePath: relativePath, fileName: fileURL.lastPathComponent, kind: .video))
                    }
                }
            } else {
                let childRelativePath = relativePath.isEmpty ? itemURL.lastPathComponent : "\(relativePath)/\(itemURL.lastPathComponent)"
                walk(itemURL, relativePath: childRelativePath, results: &results)
            }
        }
    }

    /// Finds the entry (if any) whose body references this attachment via
    /// "![](Attachments/<filename>)" or "[label](Attachments/<filename>)".
    /// Scoped to entries in the same folder, since attachment references
    /// are always folder-relative (see EntryEditorView's attachmentsFolder
    /// computation).
    static func owningEntry(for attachment: GalleryAttachment, in entries: [JournalEntryRecord]) -> JournalEntryRecord? {
        entries.first { entry in
            guard (entry.relativePath as NSString).deletingLastPathComponent == attachment.folderRelativePath else { return false }
            let nsBody = entry.searchableBody as NSString
            let fullRange = NSRange(location: 0, length: nsBody.length)

            let imageMatches = MarkdownTextView.imageReferencePattern.matches(in: entry.searchableBody, range: fullRange)
            if imageMatches.contains(where: { (nsBody.substring(with: $0.range(at: 1)) as NSString).lastPathComponent == attachment.fileName }) {
                return true
            }
            let videoMatches = MarkdownTextView.videoReferencePattern.matches(in: entry.searchableBody, range: fullRange)
            return videoMatches.contains { (nsBody.substring(with: $0.range(at: 2)) as NSString).lastPathComponent == attachment.fileName }
        }
    }

    private static func isImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    private static func isVideoFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .movie)
    }
}
