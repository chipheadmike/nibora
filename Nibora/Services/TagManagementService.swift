//
//  TagManagementService.swift
//  Nibora
//

import Foundation
import SwiftData

/// Tags exist only as "#word" tokens inside entry bodies — there's no
/// separate tag table — so renaming/merging/deleting one means rewriting
/// every entry file that uses it, on disk, then reindexing. Renaming to a
/// tag name that already exists elsewhere is exactly a merge; no separate
/// code path is needed for that case.
enum TagManagementService {
    @discardableResult
    static func rename(tag oldTag: String, to newTag: String, entries: [JournalEntryRecord], vaultURL: URL, modelContext: ModelContext) -> Int {
        let trimmedNew = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNew.isEmpty, trimmedNew.lowercased() != oldTag.lowercased() else { return 0 }
        return apply(to: oldTag, entries: entries, vaultURL: vaultURL, modelContext: modelContext) { body in
            replacing(tag: oldTag, in: body) { _ in "#\(trimmedNew)" }
        }
    }

    @discardableResult
    static func delete(tag: String, entries: [JournalEntryRecord], vaultURL: URL, modelContext: ModelContext) -> Int {
        apply(to: tag, entries: entries, vaultURL: vaultURL, modelContext: modelContext) { body in
            replacing(tag: tag, in: body) { _ in nil }
        }
    }

    private static func apply(to tag: String, entries: [JournalEntryRecord], vaultURL: URL, modelContext: ModelContext, transform: (String) -> String) -> Int {
        let affected = entries.filter { $0.tagsRaw.split(separator: ",").map(String.init).contains(tag.lowercased()) }
        for entry in affected {
            let fileURL = vaultURL.appendingPathComponent(entry.relativePath)
            guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let parsed = MarkdownFrontmatterParser.parse(contents)
            let newBody = transform(parsed.body)
            guard newBody != parsed.body else { continue }

            var (frontmatter, _) = EntryFrontmatter.make(from: parsed.fields, fallbackDate: entry.date)
            frontmatter.modifiedAt = Date()
            try? EntryFileWriter.write(frontmatter: frontmatter, body: newBody, to: fileURL)
            // force: true — see the identical comment in SidebarView's
            // persistEntryFrontmatter; we just wrote this file ourselves.
            EntryIndexer(modelContext: modelContext).reindexSingleFile(at: fileURL, vaultURL: vaultURL, force: true)
        }
        return affected.count
    }

    /// Replaces every "#tag" token (case-insensitive match against `tag`)
    /// with whatever `replacement` returns — nil deletes the token, along
    /// with one adjacent space if there is one, to avoid a leftover double
    /// space. Walks matches in reverse so earlier ranges (computed once,
    /// up front) stay valid as later ones get rewritten.
    private static func replacing(tag: String, in body: String, replacement: (String) -> String?) -> String {
        let originalBody = body as NSString
        let matches = MarkdownTextView.tagPattern.matches(in: body, range: NSRange(location: 0, length: originalBody.length))
        var result = body as NSString

        for match in matches.reversed() {
            let tagText = originalBody.substring(with: match.range)
            guard String(tagText.dropFirst()).lowercased() == tag.lowercased() else { continue }

            if let newText = replacement(tagText) {
                result = result.replacingCharacters(in: match.range, with: newText) as NSString
            } else {
                var deleteRange = match.range
                if deleteRange.location + deleteRange.length < result.length,
                   result.substring(with: NSRange(location: deleteRange.location + deleteRange.length, length: 1)) == " " {
                    deleteRange.length += 1
                } else if deleteRange.location > 0,
                          result.substring(with: NSRange(location: deleteRange.location - 1, length: 1)) == " " {
                    deleteRange.location -= 1
                    deleteRange.length += 1
                }
                result = result.replacingCharacters(in: deleteRange, with: "") as NSString
            }
        }

        return result as String
    }
}
