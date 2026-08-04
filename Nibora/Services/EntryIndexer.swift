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
    func rescanFullVault(at vaultURL: URL) {
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
                reindexSingleFile(at: fileURL, vaultURL: vaultURL)
            }
        }

        pruneMissingEntries(keeping: seenRelativePaths)
        try? modelContext.save()
    }

    /// Re-indexes one file, skipping the parse if its on-disk modification
    /// date matches what's already cached.
    func reindexSingleFile(at fileURL: URL, vaultURL: URL) {
        guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
              let modificationDate = resourceValues.contentModificationDate else { return }

        let relativePath = EntryFileWriter.relativePath(of: fileURL, in: vaultURL)

        let descriptor = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate { $0.relativePath == relativePath }
        )
        let existing = try? modelContext.fetch(descriptor).first

        if let existing, existing.fileModificationDate == modificationDate {
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
        } else {
            let record = JournalEntryRecord(
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
                fileModificationDate: modificationDate
            )
            modelContext.insert(record)
        }

        try? modelContext.save()
    }

    private func pruneMissingEntries(keeping seenRelativePaths: Set<String>) {
        guard let allRecords = try? modelContext.fetch(FetchDescriptor<JournalEntryRecord>()) else { return }
        for record in allRecords where !seenRelativePaths.contains(record.relativePath) {
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
