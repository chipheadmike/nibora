//
//  OrphanedAttachmentsView.swift
//  Nibora
//

import SwiftUI

/// Review sheet for OrphanedAttachmentScanner's results. Deletes move files
/// to the Trash (same as entry deletion elsewhere in the app), never a
/// permanent remove — recoverable if the scan was wrong about something.
struct OrphanedAttachmentsView: View {
    @State var orphans: [OrphanedAttachmentScanner.OrphanedFile]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Orphaned Attachments")
                .font(.headline)
                .padding(16)

            Divider()

            if orphans.isEmpty {
                Text("No orphaned attachments found.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            } else {
                List {
                    ForEach(orphans) { orphan in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(orphan.fileName)
                                Text(orphan.folderRelativePath.isEmpty ? "Vault Root" : orphan.folderRelativePath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Move to Trash", role: .destructive) {
                                moveToTrash(orphan)
                            }
                        }
                    }
                }
                .frame(height: 240)
            }

            Divider()

            HStack {
                Spacer()
                if !orphans.isEmpty {
                    Button("Move All to Trash", role: .destructive) {
                        moveAllToTrash()
                    }
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 380)
    }

    private func moveToTrash(_ orphan: OrphanedAttachmentScanner.OrphanedFile) {
        try? FileManager.default.trashItem(at: orphan.url, resultingItemURL: nil)
        orphans.removeAll { $0.id == orphan.id }
    }

    private func moveAllToTrash() {
        for orphan in orphans {
            try? FileManager.default.trashItem(at: orphan.url, resultingItemURL: nil)
        }
        orphans = []
    }
}
