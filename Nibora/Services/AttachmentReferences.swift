//
//  AttachmentReferences.swift
//  Nibora
//

import Foundation

/// Everything that needs to know which photos/videos an entry references.
/// New attachments live in the entry's frontmatter `attachments` list;
/// entries from before that existed may still carry inline `![]()` (image)
/// or `[label](path.mov)` (video) lines in the body, which are still read
/// here so those keep working until moved out of the text.
enum AttachmentReferences {
    enum Kind {
        case image
        case video
    }

    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v"]

    static func kind(of relativePath: String) -> Kind {
        videoExtensions.contains((relativePath as NSString).pathExtension.lowercased()) ? .video : .image
    }

    /// Paths of every inline reference in `body`, in document order,
    /// without duplicates.
    static func inlinePaths(in body: String) -> [String] {
        let nsBody = body as NSString
        let fullRange = NSRange(location: 0, length: nsBody.length)
        var located: [(Int, String)] = []

        for match in MarkdownTextView.imageReferencePattern.matches(in: body, range: fullRange) {
            located.append((match.range.location, nsBody.substring(with: match.range(at: 1))))
        }
        for match in MarkdownTextView.videoReferencePattern.matches(in: body, range: fullRange) {
            located.append((match.range.location, nsBody.substring(with: match.range(at: 2))))
        }

        var seen = Set<String>()
        return located
            .sorted { $0.0 < $1.0 }
            .map(\.1)
            .filter { seen.insert($0).inserted }
    }

    /// Every attachment an entry references, frontmatter list first, then
    /// any inline-only ones — each path once.
    static func allPaths(body: String, attachments: [String]) -> [String] {
        var seen = Set<String>()
        return (attachments + inlinePaths(in: body)).filter { seen.insert($0).inserted }
    }

    /// Bare filenames (what actually sits in an Attachments folder) of
    /// everything referenced — the unit cleanup and scanners compare on.
    static func fileNames(body: String, attachments: [String]) -> Set<String> {
        Set(allPaths(body: body, attachments: attachments).map { ($0 as NSString).lastPathComponent })
    }

    /// Removes inline references whose path satisfies `shouldRemove`. A line
    /// left empty is dropped entirely, and so is one blank line beside it so
    /// removal doesn't leave a double gap behind.
    static func removeInlineReferences(from body: String, where shouldRemove: (String) -> Bool) -> String {
        let lines = body.components(separatedBy: "\n")
        var output: [String] = []
        var skipNextBlank = false

        for line in lines {
            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)
            var ranges: [NSRange] = []

            for match in MarkdownTextView.imageReferencePattern.matches(in: line, range: fullRange)
            where shouldRemove(nsLine.substring(with: match.range(at: 1))) {
                ranges.append(match.range)
            }
            for match in MarkdownTextView.videoReferencePattern.matches(in: line, range: fullRange)
            where shouldRemove(nsLine.substring(with: match.range(at: 2))) {
                ranges.append(match.range)
            }

            if ranges.isEmpty {
                if skipNextBlank && line.trimmingCharacters(in: .whitespaces).isEmpty {
                    skipNextBlank = false
                    continue
                }
                skipNextBlank = false
                output.append(line)
                continue
            }

            var edited = line as NSString
            for range in ranges.sorted(by: { $0.location > $1.location }) {
                edited = edited.replacingCharacters(in: range, with: "") as NSString
            }

            if (edited as String).trimmingCharacters(in: .whitespaces).isEmpty {
                // Whole line was references. If a blank line sits on both
                // sides, one of them is now redundant.
                if output.last?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
                    skipNextBlank = true
                }
            } else {
                output.append(edited as String)
                skipNextBlank = false
            }
        }

        return output.joined(separator: "\n")
    }

    static func removeAllInlineReferences(from body: String) -> String {
        removeInlineReferences(from: body) { _ in true }
    }

    /// Trashes any attachment file that was referenced before a save but
    /// isn't now. Compares full reference sets (frontmatter list plus
    /// inline) rather than just the body, so moving a reference out of the
    /// text into the list — or removing one from the strip — is handled by
    /// the same rule: a file is only trashed when nothing references it.
    static func pruneRemoved(oldFileNames: Set<String>, newFileNames: Set<String>, attachmentsFolder: URL) {
        for fileName in oldFileNames.subtracting(newFileNames) {
            try? FileManager.default.trashItem(at: attachmentsFolder.appendingPathComponent(fileName), resultingItemURL: nil)
        }
    }
}
