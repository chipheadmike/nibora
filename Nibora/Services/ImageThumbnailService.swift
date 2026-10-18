//
//  ImageThumbnailService.swift
//  Nibora
//

import AppKit
import ImageIO

/// Generates a downsampled thumbnail directly from an image file via
/// ImageIO, decoding only to the requested pixel size rather than loading
/// the full-resolution image into memory first (what `NSImage(contentsOf:)`
/// does) — that full decode, repeated on every SwiftUI re-render with no
/// caching, was the dominant cost behind both the vault-wide gallery and
/// the per-entry strip feeling slow. Runs off the main thread since
/// ImageIO's thumbnail API is synchronous. Shared by AttachmentsStripView
/// and AttachmentsGalleryView, same spirit as VideoThumbnailService.
enum ImageThumbnailService {
    static func thumbnail(for url: URL, maxDimension: CGFloat = 160) async -> NSImage? {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }.value
    }
}
