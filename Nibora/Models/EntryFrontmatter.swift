//
//  EntryFrontmatter.swift
//  Nibora
//

import Foundation

struct EntryFrontmatter: Equatable {
    var id: UUID
    var title: String
    var date: Date
    var createdAt: Date
    var modifiedAt: Date
    var icon: String?
    var sortOrder: Int

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func dayString(from date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func day(from string: String) -> Date? {
        dayFormatter.date(from: string)
    }

    static func timestampString(from date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    static func timestamp(from string: String) -> Date? {
        timestampFormatter.date(from: string)
    }

    /// Builds a frontmatter model from parsed raw fields, filling in defaults
    /// for anything missing or malformed (e.g. a file created outside
    /// Nibora). `healed` is true when a value had to be minted, signaling the
    /// caller should write the file back so it's self-contained going forward.
    static func make(from fields: [String: String], fallbackDate: Date) -> (frontmatter: EntryFrontmatter, healed: Bool) {
        var healed = false

        let id: UUID
        if let idString = fields["id"], let parsed = UUID(uuidString: idString) {
            id = parsed
        } else {
            id = UUID()
            healed = true
        }

        let date: Date
        if let dateString = fields["date"], let parsed = day(from: dateString) {
            date = parsed
        } else {
            date = fallbackDate
            healed = true
        }

        let parsedCreatedAt = fields["createdAt"].flatMap { timestamp(from: $0) }
        let parsedModifiedAt = fields["modifiedAt"].flatMap { timestamp(from: $0) }
        if parsedCreatedAt == nil { healed = true }
        if parsedModifiedAt == nil { healed = true }

        let createdAt = parsedCreatedAt ?? date
        let modifiedAt = parsedModifiedAt ?? createdAt
        let sortOrder = fields["sortOrder"].flatMap(Int.init) ?? 0
        let title = fields["title"] ?? ""
        let icon = (fields["icon"]?.isEmpty == false) ? fields["icon"] : nil

        let frontmatter = EntryFrontmatter(
            id: id,
            title: title,
            date: date,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            icon: icon,
            sortOrder: sortOrder
        )
        return (frontmatter, healed)
    }

    func serializedFields() -> [(String, String)] {
        var fields: [(String, String)] = [
            ("id", id.uuidString),
            ("title", title),
            ("date", Self.dayString(from: date)),
            ("createdAt", Self.timestampString(from: createdAt)),
            ("modifiedAt", Self.timestampString(from: modifiedAt)),
        ]
        if let icon {
            fields.append(("icon", icon))
        }
        fields.append(("sortOrder", String(sortOrder)))
        return fields
    }
}
