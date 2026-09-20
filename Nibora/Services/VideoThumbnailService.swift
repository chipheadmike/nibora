//
//  VideoThumbnailService.swift
//  Nibora
//

import AppKit
import AVFoundation

/// Generates a poster-frame thumbnail (first frame) for a video file —
/// shared by AttachmentsStripView (per-entry strip) and AttachmentsGalleryView
/// (whole-vault grid) so there's one implementation of the AVFoundation call.
enum VideoThumbnailService {
    static func posterFrame(for url: URL, maxDimension: CGFloat = 160) async -> NSImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        guard let result = try? await generator.image(at: .zero) else { return nil }
        return NSImage(cgImage: result.image, size: NSSize(width: result.image.width, height: result.image.height))
    }
}
