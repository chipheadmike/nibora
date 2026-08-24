//
//  EntryIndexer.swift
//  Nibora
//

import Foundation
import SwiftData

/// Walks the vault on disk and keeps the SwiftData index in sync with it.
/// The index is a cache only — frontmatter/body always come from the file.
final class EntryIndexer {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Full walk of the vault: upserts changed/new entries, deletes index
    /// rows whose backing file is gone. Call on launch and on vault change.
    /// `force` reparses every file regardless of cached modification date —
    /// used by the manual "Rescan Vault" action so it also backfills fields
    /// added after an entry was last indexed (e.g. tags), not just structural
    /// changes.
    func rescanFullVault(at vaultURL: URL, force: Bool = false) {
        switch VaultTypeConfig.read(from: vaultURL) {
        case .journal:
            rescanJournalVault(at: vaultURL, force: force)
        case .freeform:
            rescanFreeformVault(at: vaultURL, force: force)
        }
    }

    private func rescanJournalVault(at vaultURL: URL, force: Bool) {
        let fileManager = FileManager.default
        var seenRelativePaths = Set<String>()

        guard let monthFolders = try? fileManager.contentsOfDirectory(
            at: vaultURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for monthFolder in monthFolders where isMonthFolder(monthFolder) {
            guard let entryFiles = try? fileManager.contentsOfDirectory(
                at: monthFolder,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for fileURL in entryFiles where fileURL.pathExtension == "md" {
                seenRelativePaths.insert(EntryFileWriter.relativePath(of: fileURL, in: vaultURL))
                reindexSingleFile(at: fileURL, vaultURL: vaultURL, force: force)
            }
        }

        pruneMissingEntries(keeping: seenRelativePaths)
        try? modelContext.save()
    }

    /// Unlike the Journal walk (exactly one level: month folders, then
    /// files), Freeform entries can live at any depth in any user-created
    /// folder structure, so this walks the whole tree. Attachments folders
    /// are skipped so a dropped image never gets mistaken for an entry;
    /// .skipsHiddenFiles already excludes .nibora.
    ///
    /// Deliberately NOT FileManager.enumerator(at:) — confirmed via a
    /// standalone unsandboxed test that the enumeration logic itself is
    /// correct, but under App Sandbox it silently stopped after the first
    /// subdirectory and returned zero files, with no thrown error to catch.
    /// That method's default error handler (nil) aborts the whole walk on
    /// its first hiccup rather than skipping just the problem item. Manual
    /// recursion via contentsOfDirectory — the same call the Journal walk
    /// above already uses successfully under sandbox, one level at a time —
    /// sidesteps that entirely.
    private func rescanFreeformVault(at vaultURL: URL, force: Bool) {
        var seenRelativePaths = Set<String>()
        walkFreeformFolder(vaultURL, vaultURL: vaultURL, seenRelativePaths: &seenRelativePaths, force: force)
        pruneMissingEntries(keeping: seenRelativePaths)
        try? modelContext.save()
    }

    private func walkFreeformFolder(_ folderURL: URL, vaultURL: URL, seenRelativePaths: inout Set<String>, force: Bool) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for itemURL in contents {
            let isDirectory = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                guard itemURL.lastPathComponent != "Attachments" else { continue }
                walkFreeformFolder(itemURL, vaultURL: vaultURL, seenRelativePaths: &seenRelativePaths, force: force)
            } else if itemURL.pathExtension == "md" {
                seenRelativePaths.insert(EntryFileWriter.relativePath(of: itemURL, in: vaultURL))
                reindexSingleFile(at: itemURL, vaultURL: vaultURL, force: force)
            }
        }
    }

    /// Re-indexes one file, skipping the parse if its on-disk modification
    /// date matches what's already cached — unless `force` is set.
    func reindexSingleFile(at fileURL: URL, vaultURL: URL, force: Bool = false) {
        guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
              let modificationDate = resourceValues.contentModificationDate else { return }

        let relativePath = EntryFileWriter.relativePath(of: fileURL, in: vaultURL)

        let descriptor = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate { $0.relativePath == relativePath }
        )
        let existing = try? modelContext.fetch(descriptor).first

        if !force, let existing, existing.fileModificationDate == modificationDate {
            return
        }

        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        let parsed = MarkdownFrontmatterParser.parse(contents)
        let (frontmatter, healed) = EntryFrontmatter.make(from: parsed.fields, fallbackDate: modificationDate)

        if healed {
            try? EntryFileWriter.write(frontmatter: frontmatter, body: parsed.body, to: fileURL)
        }

        let monthKey = EntryFileWriter.monthKey(for: frontmatter.date)
        let excerpt = String(parsed.body.prefix(120))
        let tagsRaw = Self.extractTags(from: parsed.body)
        let sentimentScore = SentimentAnalyzer.score(for: parsed.body)

        let record: JournalEntryRecord
        if let existing {
            existing.title = frontmatter.title
            existing.date = frontmatter.date
            existing.monthKey = monthKey
            existing.sortOrder = frontmatter.sortOrder
            existing.icon = frontmatter.icon
            existing.createdAt = frontmatter.createdAt
            existing.modifiedAt = frontmatter.modifiedAt
            existing.excerpt = excerpt
            existing.fileModificationDate = modificationDate
            existing.searchableBody = parsed.body
            existing.tagsRaw = tagsRaw
            existing.sentimentScore = sentimentScore
            record = existing
        } else {
            let newRecord = JournalEntryRecord(
                id: frontmatter.id,
                title: frontmatter.title,
                date: frontmatter.date,
                monthKey: monthKey,
                sortOrder: frontmatter.sortOrder,
                icon: frontmatter.icon,
                createdAt: frontmatter.createdAt,
                modifiedAt: frontmatter.modifiedAt,
                relativePath: relativePath,
                excerpt: excerpt,
                fileModificationDate: modificationDate,
                searchableBody: parsed.body,
                tagsRaw: tagsRaw,
                sentimentScore: sentimentScore
            )
            modelContext.insert(newRecord)
            record = newRecord
        }

        try? modelContext.save()
        SpotlightIndexer.index(record)
    }

    /// Reuses the editor's own "#tag" pattern (MarkdownTextView.tagPattern)
    /// so a string only ever counts as a tag in one place — no separate
    /// definition to drift out of sync with what actually renders as a tag.
    private static func extractTags(from body: String) -> String {
        let nsBody = body as NSString
        let matches = MarkdownTextView.tagPattern.matches(in: body, range: NSRange(location: 0, length: nsBody.length))
        var tags = Set<String>()
        for match in matches {
            let tagText = nsBody.substring(with: match.range)
            tags.insert(String(tagText.dropFirst()).lowercased())
        }
        return tags.sorted().joined(separator: ",")
    }

    private func pruneMissingEntries(keeping seenRelativePaths: Set<String>) {
        guard let allRecords = try? modelContext.fetch(FetchDescriptor<JournalEntryRecord>()) else { return }
        for record in allRecords where !seenRelativePaths.contains(record.relativePath) {
            SpotlightIndexer.remove(id: record.id)
            modelContext.delete(record)
        }
    }

    private func isMonthFolder(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        guard name.count == 7 else { return false }
        let parts = name.split(separator: "-")
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2 else { return false }
        return parts[0].allSatisfy(\.isNumber) && parts[1].allSatisfy(\.isNumber)
    }
}
