//
//  JournalEntryRecord.swift
//  Nibora
//

import Foundation
import SwiftData

/// Fast index/cache over the vault's markdown files. Never the source of truth —
/// entry body text always comes from disk. Rebuilt by EntryIndexer.
@Model
final class JournalEntryRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var date: Date
    var monthKey: String
    var sortOrder: Int
    var icon: String?
    var createdAt: Date
    var modifiedAt: Date
    var relativePath: String
    var excerpt: String
    var fileModificationDate: Date
    /// Full body text, cached solely so search can query it via SwiftData's
    /// predicate/SQLite path instead of scanning every file on disk per
    /// keystroke. Never used as a source for editing or display — the
    /// editor always reads the file fresh, same as before.
    var searchableBody: String = ""
    /// Comma-joined, lowercased, unique "#tag" names found in the body at
    /// index time (no "#"). Never edited directly — always derived from the
    /// body, same as excerpt/searchableBody.
    var tagsRaw: String = ""
    /// On-device NLTagger sentiment score for the body, from -1 (negative)
    /// to 1 (positive), computed at index time. Never edited directly.
    var sentimentScore: Double = 0

    init(
        id: UUID,
        title: String,
        date: Date,
        monthKey: String,
        sortOrder: Int,
        icon: String?,
        createdAt: Date,
        modifiedAt: Date,
        relativePath: String,
        excerpt: String,
        fileModificationDate: Date,
        searchableBody: String = "",
        tagsRaw: String = "",
        sentimentScore: Double = 0
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.monthKey = monthKey
        self.sortOrder = sortOrder
        self.icon = icon
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.relativePath = relativePath
        self.excerpt = excerpt
        self.fileModificationDate = fileModificationDate
        self.searchableBody = searchableBody
        self.tagsRaw = tagsRaw
        self.sentimentScore = sentimentScore
    }
}
