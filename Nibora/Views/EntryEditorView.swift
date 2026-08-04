//
//  EntryEditorView.swift
//  Nibora
//

import SwiftUI
import SwiftData
import AppKit

struct EntryEditorView: View {
    let entry: JournalEntryRecord
    let vaultURL: URL

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var isLoaded = false

    private var fileURL: URL {
        vaultURL.appendingPathComponent(entry.relativePath)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $title)
                .textFieldStyle(.plain)
                .font(.title2)
                .padding([.horizontal, .top])
                .onChange(of: title) { scheduleSave() }

            Divider()
                .padding(.top, 8)

            MarkdownTextView(
                text: $bodyText,
                baseDirectory: fileURL.deletingLastPathComponent(),
                saveImage: saveDroppedImage,
                theme: themeManager
            )
            .onChange(of: bodyText) { scheduleSave() }

            AttachmentsStripView(text: bodyText, baseDirectory: fileURL.deletingLastPathComponent())
        }
        .task(id: entry.id) {
            load()
        }
        .onDisappear {
            saveTask?.cancel()
            saveNow()
        }
    }

    private func load() {
        isLoaded = false
        title = entry.title
        if let contents = try? String(contentsOf: fileURL, encoding: .utf8) {
            bodyText = MarkdownFrontmatterParser.parse(contents).body
        } else {
            bodyText = ""
        }
        isLoaded = true
    }

    private func scheduleSave() {
        guard isLoaded else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    private func saveNow() {
        guard isLoaded else { return }
        let frontmatter = EntryFrontmatter(
            id: entry.id,
            title: title,
            date: entry.date,
            createdAt: entry.createdAt,
            modifiedAt: Date(),
            icon: entry.icon,
            sortOrder: entry.sortOrder
        )

        try? EntryFileWriter.write(frontmatter: frontmatter, body: bodyText, to: fileURL)
        EntryIndexer(modelContext: modelContext).reindexSingleFile(at: fileURL, vaultURL: vaultURL)
    }

    private func saveDroppedImage(_ image: NSImage, suggestedName: String?) -> String? {
        let attachmentsFolder = fileURL.deletingLastPathComponent().appendingPathComponent("Attachments")
        return try? ImageAttachmentService.saveImage(image, originalName: suggestedName, in: attachmentsFolder).relativeMarkdownPath
    }
}
