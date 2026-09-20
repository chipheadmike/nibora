//
//  AttachmentsStripView.swift
//  Nibora
//

import SwiftUI
import AppKit

/// Horizontal strip of thumbnails for every `![]()` image and video-link
/// reference in the current entry's text, in the order they appear. Click
/// an image thumbnail for a full-size preview popover; click a video
/// thumbnail to open it in the default video player (QuickTime, typically)
/// — no in-app playback, kept as simple/low-risk as the image popover.
/// Exists because click-detection inside the plain-text NSTextView editor
/// isn't reliable in this beta SDK — plain SwiftUI buttons are the fallback.
struct AttachmentsStripView: View {
    let text: String
    let baseDirectory: URL

    @Environment(ImageAttachmentPreferences.self) private var imageAttachmentPreferences
    @State private var previewPath: String?
    @State private var videoPosterFrames: [String: NSImage] = [:]

    private enum Attachment {
        case image(String)
        case video(String)
    }

    /// Both reference kinds located and merged in document order, so a
    /// video dropped between two photos shows up where it was dropped
    /// rather than all videos trailing all images.
    private var attachments: [Attachment] {
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        var located: [(Int, Attachment)] = []

        for match in MarkdownTextView.imageReferencePattern.matches(in: text, range: fullRange) {
            located.append((match.range.location, .image(nsString.substring(with: match.range(at: 1)))))
        }
        for match in MarkdownTextView.videoReferencePattern.matches(in: text, range: fullRange) {
            located.append((match.range.location, .video(nsString.substring(with: match.range(at: 2)))))
        }

        return located.sorted { $0.0 < $1.0 }.map(\.1)
    }

    var body: some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(attachments.enumerated()), id: \.offset) { _, attachment in
                        switch attachment {
                        case .image(let relativePath):
                            imageThumbnail(for: relativePath)
                        case .video(let relativePath):
                            videoThumbnail(for: relativePath)
                        }
                    }
                }
                .padding(8)
            }
            .frame(height: 96)
        }
    }

    @ViewBuilder
    private func imageThumbnail(for relativePath: String) -> some View {
        let fileURL = baseDirectory.appendingPathComponent(relativePath)
        if let nsImage = NSImage(contentsOf: fileURL) {
            Button {
                previewPath = relativePath
            } label: {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .popover(isPresented: Binding(
                get: { previewPath == relativePath },
                set: { isPresented in if !isPresented { previewPath = nil } }
            )) {
                previewContent(for: nsImage)
            }
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }

    @ViewBuilder
    private func videoThumbnail(for relativePath: String) -> some View {
        let fileURL = baseDirectory.appendingPathComponent(relativePath)
        Button {
            NSWorkspace.shared.open(fileURL)
        } label: {
            ZStack {
                if let poster = videoPosterFrames[relativePath] {
                    Image(nsImage: poster)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 80, height: 80)
                }
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white, .black.opacity(0.45))
            }
        }
        .buttonStyle(.plain)
        .help("Open in default video player")
        .task(id: relativePath) {
            guard videoPosterFrames[relativePath] == nil else { return }
            videoPosterFrames[relativePath] = await VideoThumbnailService.posterFrame(for: fileURL)
        }
    }

    private func previewContent(for image: NSImage) -> some View {
        let maxDimension = CGFloat(imageAttachmentPreferences.previewMaxDimension)
        let scale = min(1, maxDimension / max(image.size.width, image.size.height, 1))
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        return Image(nsImage: image)
            .resizable()
            .frame(width: size.width, height: size.height)
            .padding(8)
    }
}
