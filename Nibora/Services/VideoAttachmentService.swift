//
//  VideoAttachmentService.swift
//  Nibora
//

import Foundation

enum VideoAttachmentService {
    struct SavedAttachment {
        /// Path relative to the entry's own file (e.g. "Attachments/foo.mov"),
        /// suitable for a `[label](...)` markdown link.
        let relativeMarkdownPath: String
        let fileURL: URL
    }

    /// Copies a dropped/pasted video file as-is into the given Attachments
    /// folder — no re-encoding (unlike ImageAttachmentService, which
    /// downscales/recompresses; doing that to video is a much heavier,
    /// riskier operation and not attempted here), returning a
    /// vault-portable relative path. Same caller contract as
    /// ImageAttachmentService.saveImage: pass the folder derived from the
    /// entry's actual on-disk location.
    static func saveVideo(from sourceURL: URL, originalName: String?, in attachmentsFolder: URL) throws -> SavedAttachment {
        try FileManager.default.createDirectory(at: attachmentsFolder, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension.lowercased()
        let stem = "\(timestampFormatter.string(from: Date()))-\(sanitize(originalName))"
        // Same file dropped twice in one second would otherwise collide
        // (copyItem refuses to overwrite) and silently insert nothing.
        var filename = "\(stem).\(ext)"
        var suffix = 2
        while FileManager.default.fileExists(atPath: attachmentsFolder.appendingPathComponent(filename).path) {
            filename = "\(stem)-\(suffix).\(ext)"
            suffix += 1
        }
        let fileURL = attachmentsFolder.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: sourceURL, to: fileURL)

        return SavedAttachment(relativeMarkdownPath: "Attachments/\(filename)", fileURL: fileURL)
    }

    /// Trashes any attachment file that was referenced in `oldBody` but no
    /// longer appears in `newBody` — same cleanup ImageAttachmentService
    /// does for images, called alongside it on every save.
    static func pruneRemovedVideos(oldBody: String, newBody: String, attachmentsFolder: URL) {
        let removedFileNames = referencedFileNames(in: oldBody).subtracting(referencedFileNames(in: newBody))
        guard !removedFileNames.isEmpty else { return }

        for fileName in removedFileNames {
            let fileURL = attachmentsFolder.appendingPathComponent(fileName)
            try? FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
        }
    }

    private static func referencedFileNames(in body: String) -> Set<String> {
        let nsBody = body as NSString
        let matches = MarkdownTextView.videoReferencePattern.matches(in: body, range: NSRange(location: 0, length: nsBody.length))
        var names = Set<String>()
        for match in matches {
            let relativeRef = nsBody.substring(with: match.range(at: 2))
            names.insert((relativeRef as NSString).lastPathComponent)
        }
        return names
    }

    private static func sanitize(_ name: String?) -> String {
        let base = ((name ?? "video") as NSString).deletingPathExtension
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = String(base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        return cleaned.isEmpty ? "video" : cleaned
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter
    }()
}
