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

    /// Creates a new freeform entry, deriving its filename from the title
    /// (not a date) — collision handling mirrors createEntry's suffix loop.
    /// `folderRelativePath` is the vault-relative folder to create it in
    /// (nil/empty = vault root); created if it doesn't already exist.
    @discardableResult
    static func createFreeformEntry(title: String, folderRelativePath: String?, body: String = "", in vaultURL: URL) throws -> String {
        let targetFolder: URL
        if let folderRelativePath, !folderRelativePath.isEmpty {
            targetFolder = vaultURL.appendingPathComponent(folderRelativePath, isDirectory: true)
        } else {
            targetFolder = vaultURL
        }
        try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)

        let baseName = slugify(title)
        var candidateName = "\(baseName).md"
        var suffix = 1
        while FileManager.default.fileExists(atPath: targetFolder.appendingPathComponent(candidateName).path) {
            candidateName = "\(baseName)-\(suffix).md"
            suffix += 1
        }

        let fileURL = targetFolder.appendingPathComponent(candidateName)
        let now = Date()
        let frontmatter = EntryFrontmatter(
            id: UUID(),
            title: title,
            date: now,
            createdAt: now,
            modifiedAt: now,
            icon: nil,
            sortOrder: 0
        )

        try write(frontmatter: frontmatter, body: body, to: fileURL)

        return relativePath(of: fileURL, in: vaultURL)
    }

    /// Filesystem-safe filename stem from a title — collapses whitespace,
    /// strips characters that are unsafe/awkward in filenames, but keeps
    /// spaces and non-ASCII letters so titles stay human-readable on disk
    /// (e.g. "Q3 Planning" stays "Q3 Planning.md", not "q3-planning.md").
    private static func slugify(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled" }

        let disallowed = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = String(String.UnicodeScalarView(trimmed.unicodeScalars.map { disallowed.contains($0) ? " " : $0 }))

        let collapsed = cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return collapsed.isEmpty ? "Untitled" : String(collapsed.prefix(120))
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
