//
//  AttachmentsStripView.swift
//  Nibora
//

import SwiftUI
import AppKit

/// Horizontal strip of thumbnails for every `![]()` image reference in the
/// current entry's text. Click a thumbnail for a full-size preview popover.
/// Exists because click-detection inside the plain-text NSTextView editor
/// isn't reliable in this beta SDK — plain SwiftUI buttons are the fallback.
struct AttachmentsStripView: View {
    let text: String
    let baseDirectory: URL

    @State private var previewPath: String?

    private var relativePaths: [String] {
        let pattern = MarkdownTextView.imageReferencePattern
        let nsString = text as NSString
        let matches = pattern.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        return matches.map { nsString.substring(with: $0.range(at: 1)) }
    }

    var body: some View {
        if !relativePaths.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(relativePaths, id: \.self) { relativePath in
                        thumbnail(for: relativePath)
                    }
                }
                .padding(8)
            }
            .frame(height: 96)
        }
    }

    @ViewBuilder
    private func thumbnail(for relativePath: String) -> some View {
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

    private func previewContent(for image: NSImage) -> some View {
        let maxDimension: CGFloat = 400
        let scale = min(1, maxDimension / max(image.size.width, image.size.height, 1))
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        return Image(nsImage: image)
            .resizable()
            .frame(width: size.width, height: size.height)
            .padding(8)
    }
}
