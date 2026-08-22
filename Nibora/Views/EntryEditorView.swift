//
//  EntryEditorView.swift
//  Nibora
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct EntryEditorView: View {
    let entry: JournalEntryRecord
    let vaultURL: URL
    let allEntries: [JournalEntryRecord]
    let onNavigateToEntry: (String) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(TimestampHotkeyPreferences.self) private var hotkeyPreferences
    @Environment(FontPreferences.self) private var fontPreferences

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var isLoaded = false
    @State private var isFocusModeEnabled = false
    @State private var isPreviewEnabled = false
    @State private var isHistoryPresented = false

    private var fileURL: URL {
        vaultURL.appendingPathComponent(entry.relativePath)
    }

    private var wordCount: Int {
        bodyText.split(whereSeparator: \.isWhitespace).count
    }

    /// Other entries whose body contains a "[[Title]]" matching this
    /// entry's title, case-insensitively. Reuses MarkdownTextView's own
    /// wikilinkPattern so a string only ever counts as a link in one place.
    private var backlinkEntries: [JournalEntryRecord] {
        let titleLower = entry.title.trimmingCharacters(in: .whitespaces).lowercased()
        guard !titleLower.isEmpty else { return [] }
        return allEntries.filter { candidate in
            guard candidate.id != entry.id else { return false }
            return wikilinkTitles(in: candidate.searchableBody).contains(titleLower)
        }
    }

    private func wikilinkTitles(in body: String) -> Set<String> {
        let nsBody = body as NSString
        let matches = MarkdownTextView.wikilinkPattern.matches(in: body, range: NSRange(location: 0, length: nsBody.length))
        return Set(matches.map { nsBody.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespaces).lowercased() })
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

            HStack(spacing: 0) {
                MarkdownTextView(
                    text: $bodyText,
                    baseDirectory: fileURL.deletingLastPathComponent(),
                    saveImage: saveDroppedImage,
                    theme: themeManager,
                    hotkeyPreferences: hotkeyPreferences,
                    fontPreferences: fontPreferences,
                    isFocusModeEnabled: isFocusModeEnabled,
                    onWikilinkClick: onNavigateToEntry
                )
                .onChange(of: bodyText) { scheduleSave() }

                if isPreviewEnabled {
                    Divider()
                    MarkdownPreviewView(
                        markdownText: bodyText,
                        theme: themeManager,
                        fontPreferences: fontPreferences,
                        onWikilinkClick: onNavigateToEntry
                    )
                    .frame(maxWidth: .infinity)
                }
            }

            AttachmentsStripView(text: bodyText, baseDirectory: fileURL.deletingLastPathComponent())

            BacklinksView(entries: backlinkEntries) { linkedEntry in
                onNavigateToEntry(linkedEntry.title)
            }

            Divider()
            HStack {
                Spacer()
                Text("\(wordCount) words · \(bodyText.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .task(id: entry.id) {
            load()
        }
        .onDisappear {
            saveTask?.cancel()
            saveNow()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    isFocusModeEnabled.toggle()
                } label: {
                    Image(systemName: isFocusModeEnabled ? "eye.fill" : "eye")
                }
                .help(isFocusModeEnabled ? "Turn Off Focus Mode" : "Turn On Focus Mode")
            }
            ToolbarItem {
                Button {
                    isPreviewEnabled.toggle()
                } label: {
                    Image(systemName: isPreviewEnabled ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                }
                .help(isPreviewEnabled ? "Hide Preview" : "Show Preview")
            }
            ToolbarItem {
                Button("Export to PDF", systemImage: "square.and.arrow.up") {
                    exportToPDF()
                }
            }
            ToolbarItem {
                Button("Version History", systemImage: "clock.arrow.circlepath") {
                    isHistoryPresented = true
                }
                .popover(isPresented: $isHistoryPresented) {
                    EntryHistoryView(fileURL: fileURL) { restoredBody in
                        bodyText = restoredBody
                    }
                }
            }
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
        EntryHistoryService.snapshotIfNeeded(fileURL: fileURL)
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

    private func exportToPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = title.isEmpty ? "Entry" : title
        guard panel.runModal() == .OK, let url = panel.url else { return }
        EntryPDFExporter.export(title: title, body: bodyText, theme: themeManager, fontPreferences: fontPreferences, to: url)
    }

    private func saveDroppedImage(_ image: NSImage, suggestedName: String?) -> String? {
        let attachmentsFolder = fileURL.deletingLastPathComponent().appendingPathComponent("Attachments")
        return try? ImageAttachmentService.saveImage(image, originalName: suggestedName, in: attachmentsFolder).relativeMarkdownPath
    }
}
