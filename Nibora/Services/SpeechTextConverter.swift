//
//  SpeechTextConverter.swift
//  Nibora
//

import Foundation

/// Strips markdown syntax down to clean prose for text-to-speech — reuses
/// the same block-line classification (heading/blockquote/list/etc.) as
/// MarkdownPreviewView and the same inline-match extraction as
/// MarkdownTextView.inlineAttributedText, just without any styling, so a
/// listener never hears literal "asterisk asterisk" or "pound sign".
enum SpeechTextConverter {
    /// Matches this app's own timestamp-hotkey format (TimestampHotkeyPreferences
    /// inserts "HHmm - ", e.g. "1350 - ") so it can be swapped for a
    /// natural-sounding time before speaking — as bare digits it reads as
    /// "one thousand three hundred fifty" instead of a time.
    private static let timestampPattern = try! NSRegularExpression(pattern: #"\b([01][0-9]|2[0-3])([0-5][0-9]) - "#)

    static func plainText(from markdown: String) -> String {
        let stripped = markdown
            .components(separatedBy: "\n")
            .map { plainLine($0) }
            .joined(separator: "\n")
        return spokenTimestamps(in: stripped)
    }

    private static func plainLine(_ line: String) -> String {
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        if MarkdownTextView.horizontalRulePattern.firstMatch(in: line, range: fullRange) != nil {
            return ""
        }
        if let level = MarkdownTextView.headingLevel(of: line) {
            return stripInline(String(line.dropFirst(level + 1)))
        }
        if let match = MarkdownTextView.taskListPattern.firstMatch(in: line, range: fullRange) {
            let checkboxChar = nsLine.substring(with: match.range(at: 4))
            let content = nsLine.substring(with: match.range(at: 6))
            let prefix = checkboxChar.lowercased() == "x" ? "Done: " : "To do: "
            return prefix + stripInline(content)
        }
        if let match = MarkdownTextView.bulletListPattern.firstMatch(in: line, range: fullRange) {
            return stripInline(nsLine.substring(with: match.range(at: 4)))
        }
        if let match = MarkdownTextView.numberedListPattern.firstMatch(in: line, range: fullRange) {
            return stripInline(nsLine.substring(with: match.range(at: 5)))
        }
        if let match = MarkdownTextView.blockquotePattern.firstMatch(in: line, range: fullRange) {
            return stripInline(nsLine.substring(with: match.range(at: 4)))
        }
        return stripInline(line)
    }

    private static func stripInline(_ line: String) -> String {
        let nsLine = line as NSString
        var result = ""
        var cursor = 0

        for match in MarkdownTextView.previewInlinePattern.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            if match.range.location > cursor {
                result += nsLine.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            }
            result += MarkdownTextView.inlineMatchText(match, in: nsLine)
            cursor = match.range.location + match.range.length
        }

        result += nsLine.substring(from: cursor)
        return result
    }

    private static func spokenTimestamps(in text: String) -> String {
        let nsText = text as NSString
        var result = ""
        var cursor = 0

        for match in timestampPattern.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            result += nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let hour = Int(nsText.substring(with: match.range(at: 1))) ?? 0
            let minute = Int(nsText.substring(with: match.range(at: 2))) ?? 0
            result += spokenTime(hour: hour, minute: minute) + " - "
            cursor = match.range.location + match.range.length
        }

        result += nsText.substring(from: cursor)
        return result
    }

    private static func spokenTime(hour: Int, minute: Int) -> String {
        let period = hour < 12 ? "AM" : "PM"
        var displayHour = hour % 12
        if displayHour == 0 { displayHour = 12 }
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}
