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

    /// Pixel-exact resize via a plain CGContext bitmap — deliberately not
    /// NSImage.lockFocus(), whose backing store silently renders at the
    /// *current screen's* Retina scale factor (2x on effectively every
    /// modern Mac) regardless of the target NSImage's nominal "size." That
    /// meant every attachment this app ever saved came out at roughly
    /// double the intended linear dimension — ~4x the pixel area of
    /// maxLongEdge, not maxLongEdge itself — independent of the source
    /// image's own characteristics (confirmed with a source built with no
    /// lockFocus involvement at all). A CGContext created with explicit
    /// pixel dimensions has no such ambiguity: what you ask for is exactly
    /// what you get, on every Mac.
    private static func resize(_ image: NSImage, maxLongEdge: CGFloat) -> NSImage {
        guard let tiffData = image.tiffRepresentation,
              let sourceBitmap = NSBitmapImageRep(data: tiffData),
              let sourceCGImage = sourceBitmap.cgImage else {
            return image
        }

        let pixelWidth = sourceCGImage.width
        let pixelHeight = sourceCGImage.height
        let longEdge = CGFloat(max(pixelWidth, pixelHeight))
        guard longEdge > maxLongEdge, longEdge > 0 else { return image }

        let scale = maxLongEdge / longEdge
        let targetWidth = max(1, Int((CGFloat(pixelWidth) * scale).rounded()))
        let targetHeight = max(1, Int((CGFloat(pixelHeight) * scale).rounded()))

        // Preserve the source's actual alpha-channel presence — encode()
        // below decides JPEG vs. PNG based on hasAlpha, and a context that
        // always allocates an alpha channel (even for an opaque photo)
        // would make every resized image report hasAlpha and silently
        // force every one of them — the exact ones large enough to need
        // resizing — onto PNG, which is dramatically larger than JPEG for
        // photographic content.
        let bitmapInfo: CGImageAlphaInfo = sourceBitmap.hasAlpha ? .premultipliedLast : .noneSkipLast
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(sourceCGImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let resizedCGImage = context.makeImage() else { return image }
        return NSImage(cgImage: resizedCGImage, size: NSSize(width: targetWidth, height: targetHeight))
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
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter
    }()
}
