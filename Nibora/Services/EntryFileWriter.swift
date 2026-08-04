//
//  EntryFileWriter.swift
//  Nibora
//

import Foundation

enum EntryFileWriter {
    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static func monthKey(for date: Date) -> String {
        monthKeyFormatter.string(from: date)
    }

    static func monthFolderURL(for date: Date, in vaultURL: URL) -> URL {
        vaultURL.appendingPathComponent(monthKey(for: date), isDirectory: true)
    }

    /// Creates a new day-entry file in the vault, handling same-day filename
    /// collisions with a numeric suffix, and returns the file's path relative
    /// to the vault root.
    @discardableResult
    static func createEntry(date: Date, title: String, body: String = "", in vaultURL: URL) throws -> String {
        let monthFolder = monthFolderURL(for: date, in: vaultURL)
        try FileManager.default.createDirectory(at: monthFolder, withIntermediateDirectories: true)

        let dayString = EntryFrontmatter.dayString(from: date)
        var candidateName = "\(dayString).md"
        var suffix = 1
        while FileManager.default.fileExists(atPath: monthFolder.appendingPathComponent(candidateName).path) {
            candidateName = "\(dayString)-\(suffix).md"
            suffix += 1
        }

        let fileURL = monthFolder.appendingPathComponent(candidateName)
        let now = Date()
        let frontmatter = EntryFrontmatter(
            id: UUID(),
            title: title,
            date: date,
            createdAt: now,
            modifiedAt: now,
            icon: nil,
            sortOrder: 0
        )

        try write(frontmatter: frontmatter, body: body, to: fileURL)

        return relativePath(of: fileURL, in: vaultURL)
    }

    static func write(frontmatter: EntryFrontmatter, body: String, to fileURL: URL) throws {
        let contents = MarkdownFrontmatterParser.serialize(fields: frontmatter.serializedFields(), body: body)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    static func relativePath(of fileURL: URL, in vaultURL: URL) -> String {
        let vaultPath = vaultURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        guard filePath.hasPrefix(vaultPath) else { return filePath }

        var relative = String(filePath.dropFirst(vaultPath.count))
        if relative.hasPrefix("/") {
            relative.removeFirst()
        }
        return relative
    }
}
