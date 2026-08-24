//
//  AttachmentsGalleryView.swift
//  Nibora
//

import SwiftUI
import AppKit

/// Every image across the whole vault, chronologically, browsable outside
/// the context of any single entry — distinct from AttachmentsStripView,
/// which only shows one entry's images inline below its editor.
struct AttachmentsGalleryView: View {
    let vaultURL: URL
    let entries: [JournalEntryRecord]
    let onSelectEntry: (JournalEntryRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var attachments: [GalleryAttachment] = []
    @State private var previewAttachment: GalleryAttachment?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Attachments")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if attachments.isEmpty {
                ContentUnavailableView(
                    "No Attachments",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Images you drag or paste into entries will show up here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(attachments) { attachment in
                            thumbnail(for: attachment)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 640, height: 520)
        .onAppear {
            attachments = AttachmentGalleryScanner.scan(vaultURL: vaultURL)
        }
        .popover(item: $previewAttachment) { attachment in
            previewContent(for: attachment)
        }
    }

    @ViewBuilder
    private func thumbnail(for attachment: GalleryAttachment) -> some View {
        if let image = NSImage(contentsOf: attachment.url) {
            Button {
                previewAttachment = attachment
            } label: {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 110, height: 110)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }

    private func previewContent(for attachment: GalleryAttachment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = NSImage(contentsOf: attachment.url) {
                let maxDimension: CGFloat = 400
                let scale = min(1, maxDimension / max(image.size.width, image.size.height, 1))
                Image(nsImage: image)
                    .resizable()
                    .frame(width: image.size.width * scale, height: image.size.height * scale)
            }

            Text(attachment.folderRelativePath.isEmpty ? "Vault Root" : attachment.folderRelativePath)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if let owner = AttachmentGalleryScanner.owningEntry(for: attachment, in: entries) {
                    Button("Go to Entry") {
                        onSelectEntry(owner)
                        previewAttachment = nil
                        dismiss()
                    }
                }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([attachment.url])
                }
            }
        }
        .padding(12)
    }
}
