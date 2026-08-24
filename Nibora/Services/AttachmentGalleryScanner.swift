//
//  AttachmentGalleryScanner.swift
//  Nibora
//

import Foundation
import UniformTypeIdentifiers

struct GalleryAttachment: Identifiable {
    let url: URL
    /// Vault-relative path of the folder this attachment's Attachments/
    /// folder lives in ("" = vault root) — a Journal vault's month folder
    /// name, or a Freeform vault's (possibly nested) folder path.
    let folderRelativePath: String
    let fileName: String
    var id: URL { url }
}

/// Recursively finds every Attachments/ folder anywhere in the vault and
/// lists their image files — a plain one-level walk (Journal's month
/// folders only) would silently miss Freeform vaults' arbitrarily nested
/// Attachments folders.
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
                for fileURL in files where isImageFile(fileURL) {
                    results.append(GalleryAttachment(url: fileURL, folderRelativePath: relativePath, fileName: fileURL.lastPathComponent))
                }
            } else {
                let childRelativePath = relativePath.isEmpty ? itemURL.lastPathComponent : "\(relativePath)/\(itemURL.lastPathComponent)"
                walk(itemURL, relativePath: childRelativePath, results: &results)
            }
        }
    }

    /// Finds the entry (if any) whose body references this attachment via
    /// "![](Attachments/<filename>)". Scoped to entries in the same folder,
    /// since attachment references are always folder-relative (see
    /// EntryEditorView's attachmentsFolder computation).
    static func owningEntry(for attachment: GalleryAttachment, in entries: [JournalEntryRecord]) -> JournalEntryRecord? {
        entries.first { entry in
            guard (entry.relativePath as NSString).deletingLastPathComponent == attachment.folderRelativePath else { return false }
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
