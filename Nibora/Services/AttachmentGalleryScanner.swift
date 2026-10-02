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

    /// Finds the entry (if any) that references this attachment — via its
    /// frontmatter attachment list or an older inline line. Scoped to
    /// entries in the same folder, since attachment references are always
    /// folder-relative (see EntryEditorView's attachmentsFolder
    /// computation). Reads each candidate from disk rather than the cached
    /// searchableBody, since the list lives in frontmatter, which the index
    /// doesn't store.
    static func owningEntry(for attachment: GalleryAttachment, in entries: [JournalEntryRecord], vaultURL: URL) -> JournalEntryRecord? {
        entries.first { entry in
            guard (entry.relativePath as NSString).deletingLastPathComponent == attachment.folderRelativePath else { return false }
            guard let contents = try? String(contentsOf: vaultURL.appendingPathComponent(entry.relativePath), encoding: .utf8) else { return false }
            let parsed = MarkdownFrontmatterParser.parse(contents)
            return AttachmentReferences
                .fileNames(body: parsed.body, attachments: EntryFrontmatter.decodeAttachments(parsed.fields["attachments"]))
                .contains(attachment.fileName)
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
