//
//  ImportService.swift
//  Nibora
//

import Foundation
import SwiftData

/// Imports a folder of plain markdown/text files (e.g. from Ulysses'
/// Export → Markdown) into the vault as new entries. Ulysses' own library
/// format is proprietary and not read directly — this only works with the
/// plain-text files Ulysses itself exports.
enum ImportService {
    struct ImportResult {
        var importedCount: Int
        var skippedCount: Int
    }

    private static let supportedExtensions: Set<String> = ["md", "markdown", "txt"]
    private static let datePrefixPattern = try! NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}"#)

    /// Recursively imports every markdown/text file found under `folderURL`.
    /// Title comes from a leading "# " heading if present, else the
    /// filename. Date comes from a leading `YYYY-MM-DD` in the filename if
    /// present, else the file's on-disk creation/modification date.
    static func importFiles(from folderURL: URL, into vaultURL: URL, modelContext: ModelContext) -> ImportResult {
        let fileManager = FileManager.default
        let indexer = EntryIndexer(modelContext: modelContext)

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ImportResult(importedCount: 0, skippedCount: 0)
        }

        var importedCount = 0
        var skippedCount = 0

        for case let fileURL as URL in enumerator {
            guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }

            guard let rawContents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                skippedCount += 1
                continue
            }

            let fallbackName = fileURL.deletingPathExtension().lastPathComponent
            let (title, body) = extractTitleAndBody(from: rawContents, fallbackTitle: fallbackName)
            let date = inferDate(from: fileURL, filenameWithoutExtension: fallbackName)

            if let relativePath = try? EntryFileWriter.createEntry(date: date, title: title, body: body, in: vaultURL) {
                indexer.reindexSingleFile(at: vaultURL.appendingPathComponent(relativePath), vaultURL: vaultURL)
                importedCount += 1
            } else {
                skippedCount += 1
            }
        }

        return ImportResult(importedCount: importedCount, skippedCount: skippedCount)
    }

    private static func extractTitleAndBody(from contents: String, fallbackTitle: String) -> (title: String, body: String) {
        let lines = contents.components(separatedBy: "\n")
        if let firstLine = lines.first, firstLine.hasPrefix("# ") {
            let title = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .newlines)
            return (title.isEmpty ? fallbackTitle : title, body)
        }
        return (fallbackTitle, contents.trimmingCharacters(in: .newlines))
    }

    private static func inferDate(from fileURL: URL, filenameWithoutExtension: String) -> Date {
        let nsFilename = filenameWithoutExtension as NSString
        if let match = datePrefixPattern.firstMatch(in: filenameWithoutExtension, range: NSRange(location: 0, length: nsFilename.length)) {
            let dateString = nsFilename.substring(with: match.range)
            if let date = EntryFrontmatter.day(from: dateString) {
                return date
            }
        }

        if let values = try? fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) {
            return values.creationDate ?? values.contentModificationDate ?? Date()
        }
        return Date()
    }
}
