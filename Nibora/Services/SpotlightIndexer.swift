//
//  SpotlightIndexer.swift
//  Nibora
//

import CoreSpotlight
import Foundation

/// Indexes journal entries into macOS system-wide search via CoreSpotlight —
/// same public, on-device, sandbox-legal API any Mail/Notes-style app uses.
/// No network call, no change to how entries are actually stored; this is
/// purely a searchability layer on top of the existing SwiftData index.
enum SpotlightIndexer {
    static let domainIdentifier = "com.nibora.entries"

    static func index(_ entry: JournalEntryRecord) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = entry.title.isEmpty ? "(untitled)" : entry.title
        attributeSet.contentDescription = entry.excerpt
        attributeSet.keywords = entry.tagsRaw.isEmpty ? nil : entry.tagsRaw.split(separator: ",").map(String.init)
        attributeSet.contentCreationDate = entry.createdAt
        attributeSet.contentModificationDate = entry.modifiedAt

        let item = CSSearchableItem(uniqueIdentifier: entry.id.uuidString, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
        CSSearchableIndex.default().indexSearchableItems([item])
    }

    static func remove(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString])
    }

    /// Called when switching vaults — the old vault's entries shouldn't
    /// stay searchable once Nibora is pointed somewhere else.
    static func removeAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
    }
}
