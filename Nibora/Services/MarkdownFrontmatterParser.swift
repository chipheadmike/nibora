//
//  MarkdownFrontmatterParser.swift
//  Nibora
//

import Foundation

/// Splits/serializes the leading `---`-delimited YAML frontmatter block from
/// an entry's markdown body. Hand-rolled rather than a YAML dependency since
/// the schema is flat scalars only.
enum MarkdownFrontmatterParser {
    struct ParsedFile {
        var fields: [String: String]
        var body: String
    }

    static func parse(_ contents: String) -> ParsedFile {
        let lines = contents.components(separatedBy: "\n")

        guard lines.first == "---",
              let closingIndex = lines.dropFirst().firstIndex(of: "---") else {
            return ParsedFile(fields: [:], body: contents)
        }

        var fields: [String: String] = [:]
        for line in lines[1..<closingIndex] {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colonIndex].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            fields[key] = value
        }

        let bodyStartIndex = lines.index(after: closingIndex)
        let body = lines[bodyStartIndex...]
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)

        return ParsedFile(fields: fields, body: body)
    }

    static func serialize(fields: [(String, String)], body: String) -> String {
        var output = "---\n"
        for (key, value) in fields {
            if value.isEmpty || value.contains(":") || value.contains("#") {
                output += "\(key): \"\(value)\"\n"
            } else {
                output += "\(key): \(value)\n"
            }
        }
        output += "---\n"
        output += body
        return output
    }
}
