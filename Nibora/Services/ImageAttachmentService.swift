//
//  ImageAttachmentService.swift
//  Nibora
//

import Foundation
import AppKit

enum ImageAttachmentError: Error {
    case encodingFailed
}

enum ImageAttachmentService {
    struct SavedAttachment {
        /// Path relative to the entry's own file (e.g. "Attachments/foo.jpg"),
        /// suitable for a `![]()` markdown reference.
        let relativeMarkdownPath: String
        let fileURL: URL
    }

    private static let maxLongEdge: CGFloat = 2000
    private static let jpegQuality: CGFloat = 0.85

    /// Downscales and saves a dropped image into the given Attachments
    /// folder, returning a vault-portable relative path. The caller must
    /// pass the folder derived from the entry's actual on-disk location
    /// (not its frontmatter date, which can diverge from where the file
    /// really lives — e.g. a self-healed entry with a fallback date).
    static func saveImage(_ image: NSImage, originalName: String?, in attachmentsFolder: URL) throws -> SavedAttachment {
        try FileManager.default.createDirectory(at: attachmentsFolder, withIntermediateDirectories: true)

        let (data, ext) = try encode(resize(image, maxLongEdge: maxLongEdge))
        let filename = "\(timestampFormatter.string(from: Date()))-\(sanitize(originalName)).\(ext)"
        let fileURL = attachmentsFolder.appendingPathComponent(filename)
        try data.write(to: fileURL)

        return SavedAttachment(relativeMarkdownPath: "Attachments/\(filename)", fileURL: fileURL)
    }

    private static func encode(_ image: NSImage) throws -> (Data, String) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ImageAttachmentError.encodingFailed
        }

        if bitmap.hasAlpha {
            guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
                throw ImageAttachmentError.encodingFailed
            }
            return (pngData, "png")
        } else {
            guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality]) else {
                throw ImageAttachmentError.encodingFailed
            }
            return (jpegData, "jpg")
        }
    }

    private static func resize(_ image: NSImage, maxLongEdge: CGFloat) -> NSImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxLongEdge, longEdge > 0 else { return image }

        let scale = maxLongEdge / longEdge
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()
        return resized
    }

    private static func sanitize(_ name: String?) -> String {
        let base = ((name ?? "image") as NSString).deletingPathExtension
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = String(base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        return cleaned.isEmpty ? "image" : cleaned
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
