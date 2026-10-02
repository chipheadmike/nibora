//
//  AttachmentsStripView.swift
//  Nibora
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Horizontal strip of thumbnails for an entry's photos and videos — the
/// frontmatter `attachments` list, in the order added, followed by any
/// older inline `![]()` / video-link references still sitting in the body
/// text. Click an image for a full-size preview popover; click a video to
/// open it in the default player. Right-click any item to reveal it in
/// Finder or remove it (which moves its file to the Trash). Files can also
/// be dropped straight onto the strip.
/// Exists because click-detection inside the plain-text NSTextView editor
/// isn't reliable in this beta SDK — plain SwiftUI buttons are the fallback.
struct AttachmentsStripView: View {
    /// The entry body — only read for older inline references.
    let text: String
    /// The entry's frontmatter attachment list.
    let attachments: [String]
    let baseDirectory: URL
    let onRemove: (String) -> Void
    let onMoveInlineOut: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    @Environment(ImageAttachmentPreferences.self) private var imageAttachmentPreferences
    @State private var previewPath: String?
    @State private var videoPosterFrames: [String: NSImage] = [:]

    private var inlineOnlyPaths: [String] {
        let listed = Set(attachments)
        return AttachmentReferences.inlinePaths(in: text).filter { !listed.contains($0) }
    }

    private var allPaths: [String] {
        var seen = Set<String>()
        return (attachments + inlineOnlyPaths).filter { seen.insert($0).inserted }
    }

    var body: some View {
        if !allPaths.isEmpty {
            HorizontalScroller {
                HStack(spacing: 8) {
                    if !inlineOnlyPaths.isEmpty {
                        moveOutButton
                    }
                    ForEach(allPaths, id: \.self) { relativePath in
                        Group {
                            switch AttachmentReferences.kind(of: relativePath) {
                            case .image:
                                imageThumbnail(for: relativePath)
                            case .video:
                                videoThumbnail(for: relativePath)
                            }
                        }
                        .contextMenu {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([baseDirectory.appendingPathComponent(relativePath)])
                            }
                            Divider()
                            Button("Remove", role: .destructive) {
                                onRemove(relativePath)
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(height: 96)
            .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
                onDrop(providers)
            }
        }
    }

    /// Entries from before attachments moved out of the text still have
    /// `![]()` lines in the body — shown here, and cleaned out on request
    /// (never automatically, since it rewrites the entry's text).
    private var moveOutButton: some View {
        Button {
            onMoveInlineOut()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "text.badge.minus")
                    .font(.title3)
                Text("Move \(inlineOnlyPaths.count) out of text")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 84, height: 80)
        }
        .buttonStyle(.bordered)
        .help("Remove these photo/video lines from the entry's text. They stay in the strip.")
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

/// A horizontal-only NSScrollView hosting plain SwiftUI content. Unlike
/// SwiftUI's own `ScrollView(.horizontal)` — which only responds to a
/// trackpad's two-finger horizontal swipe or a Shift+wheel, leaving a plain
/// vertical mouse wheel completely dead on a horizontal-only strip — a real
/// NSScrollView with no vertical content automatically lets a plain wheel
/// scroll it horizontally, the same way Finder and Photos filmstrips work.
private struct HorizontalScroller<Content: View>: NSViewRepresentable {
    @ViewBuilder let content: () -> Content

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none

        let hosting = NSHostingView(rootView: content())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hosting

        // Pin top/bottom/leading and a fixed height to the clip view, but
        // deliberately leave the trailing edge unconstrained — that's what
        // lets the hosting view's width grow to its SwiftUI content's
        // natural (ideal) width instead of being squeezed to the visible
        // area, which is what actually makes there be something to scroll.
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hosting.heightAnchor.constraint(equalTo: scrollView.contentView.heightAnchor)
        ])

        context.coordinator.hostingView = hosting
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.hostingView?.rootView = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var hostingView: NSHostingView<Content>?
    }
}
