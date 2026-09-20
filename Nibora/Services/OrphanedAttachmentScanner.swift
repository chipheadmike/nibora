//
//  OrphanedAttachmentScanner.swift
//  Nibora
//

import Foundation

/// Finds files under any Attachments/ folder, anywhere in the vault, that
/// aren't referenced by any entry's `![](...)` image markdown or
/// video-link markdown in that same folder — leftovers from deleted entries
/// (in-editor removal is now handled immediately at save time by
/// ImageAttachmentService.pruneRemovedImages / VideoAttachmentService.pruneRemovedVideos,
/// so this mainly catches whole-entry deletions and anything edited outside
/// the app). Reads bodies fresh from disk rather than the cached
/// searchableBody, since this feeds a delete action and needs to reflect
/// what's actually on disk right now. Recurses the whole tree rather than
/// assuming Journal's one-level month-folder layout, so it also works
/// correctly on a Freeform vault's nested folders.
enum OrphanedAttachmentScanner {
    struct OrphanedFile: Identifiable {
        let url: URL
        /// Vault-relative path of the folder this file's Attachments/
        /// folder lives in ("" = vault root).
        let folderRelativePath: String
        let fileName: String
        var id: URL { url }
    }

    static func scan(vaultURL: URL, entries: [JournalEntryRecord]) -> [OrphanedFile] {
        var referencedFileNamesByFolder: [String: Set<String>] = [:]

        for entry in entries {
            let fileURL = vaultURL.appendingPathComponent(entry.relativePath)
            guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let body = MarkdownFrontmatterParser.parse(contents).body
            let nsBody = body as NSString
            let folderRelativePath = (entry.relativePath as NSString).deletingLastPathComponent

            let imageMatches = MarkdownTextView.imageReferencePattern.matches(in: body, range: NSRange(location: 0, length: nsBody.length))
            for match in imageMatches {
                let relativeRef = nsBody.substring(with: match.range(at: 1))
                referencedFileNamesByFolder[folderRelativePath, default: []].insert((relativeRef as NSString).lastPathComponent)
            }

            let videoMatches = MarkdownTextView.videoReferencePattern.matches(in: body, range: NSRange(location: 0, length: nsBody.length))
            for match in videoMatches {
                let relativeRef = nsBody.substring(with: match.range(at: 2))
                referencedFileNamesByFolder[folderRelativePath, default: []].insert((relativeRef as NSString).lastPathComponent)
            }
        }

        var orphans: [OrphanedFile] = []
        walk(vaultURL, relativePath: "", referencedFileNamesByFolder: referencedFileNamesByFolder, orphans: &orphans)
        return orphans.sorted { $0.fileName < $1.fileName }
    }

    private static func walk(_ folderURL: URL, relativePath: String, referencedFileNamesByFolder: [String: Set<String>], orphans: inout [OrphanedFile]) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }

        for itemURL in contents {
            let isDirectory = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory else { continue }

            if itemURL.lastPathComponent == "Attachments" {
                guard let attachmentFiles = try? fileManager.contentsOfDirectory(at: itemURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                let referenced = referencedFileNamesByFolder[relativePath] ?? []
                for fileURL in attachmentFiles where !referenced.contains(fileURL.lastPathComponent) {
                    orphans.append(OrphanedFile(url: fileURL, folderRelativePath: relativePath, fileName: fileURL.lastPathComponent))
                }
            } else {
                let childRelativePath = relativePath.isEmpty ? itemURL.lastPathComponent : "\(relativePath)/\(itemURL.lastPathComponent)"
                walk(itemURL, relativePath: childRelativePath, referencedFileNamesByFolder: referencedFileNamesByFolder, orphans: &orphans)
            }
        }
    }
}
