//
//  QuickCaptureService.swift
//  Nibora
//

import Foundation
import SwiftData

/// Appends a quick note to today's entry, creating it first (mirroring the
/// sidebar's "New Entry" — same title format, same template) if it doesn't
/// exist yet. Used by the menu bar quick-capture window, which is purely a
/// click-triggered popover — no global input monitoring, after an earlier
/// attempt at that broke system-wide keyboard input.
enum QuickCaptureService {
    @discardableResult
    static func capture(_ text: String, vaultURL: URL, modelContext: ModelContext, entryTemplatePreferences: EntryTemplatePreferences) throws -> String {
        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)
        let timestampedLine = "\(timestampFormatter.string(from: now)) - \(text)"
        let relativePath: String

        let descriptor = FetchDescriptor<JournalEntryRecord>(predicate: #Predicate { $0.date == todayStart })
        if let existing = try modelContext.fetch(descriptor).first {
            relativePath = existing.relativePath
            let fileURL = vaultURL.appendingPathComponent(relativePath)
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            let parsed = MarkdownFrontmatterParser.parse(contents)
            var (frontmatter, _) = EntryFrontmatter.make(from: parsed.fields, fallbackDate: todayStart)
            frontmatter.modifiedAt = now

            let newBody = parsed.body.isEmpty ? timestampedLine : parsed.body + "\n\n" + timestampedLine
            try EntryFileWriter.write(frontmatter: frontmatter, body: newBody, to: fileURL)
        } else {
            let title = titleDateFormatter.string(from: now)
            let templateBody = entryTemplatePreferences.isEnabled
                ? EntryTemplatePreferences.rendering(entryTemplatePreferences.templateText, for: now)
                : ""
            let body = templateBody.isEmpty ? timestampedLine : templateBody + "\n\n" + timestampedLine
            relativePath = try EntryFileWriter.createEntry(date: now, title: title, body: body, in: vaultURL)
        }

        let fileURL = vaultURL.appendingPathComponent(relativePath)
        EntryIndexer(modelContext: modelContext).reindexSingleFile(at: fileURL, vaultURL: vaultURL)
        return relativePath
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let titleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
