//
//  SidebarView.swift
//  Nibora
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: JournalEntryRecord?
    let vaultURL: URL

    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: [
            SortDescriptor(\JournalEntryRecord.monthKey, order: .reverse),
            SortDescriptor(\JournalEntryRecord.sortOrder),
        ],
        sectionBy: \.monthKey
    )
    private var entries: [JournalEntryRecord]

    @State private var iconPickerEntry: JournalEntryRecord?
    @State private var entryPendingDeletion: JournalEntryRecord?

    var body: some View {
        List(selection: $selection) {
            ForEach(_entries.sections) { section in
                Section(monthTitle(for: section.id)) {
                    ForEach(section, id: \.id) { entry in
                        EntryRow(entry: entry)
                            .tag(entry)
                            .contextMenu {
                                Button("Choose Icon…") {
                                    iconPickerEntry = entry
                                }
                                Divider()
                                Button("Move Up") {
                                    moveEntry(entry, direction: .up)
                                }
                                .disabled(!canMove(entry, direction: .up))
                                Button("Move Down") {
                                    moveEntry(entry, direction: .down)
                                }
                                .disabled(!canMove(entry, direction: .down))
                                Divider()
                                Button("Delete…", role: .destructive) {
                                    entryPendingDeletion = entry
                                }
                            }
                    }
                }
            }
        }
        .popover(item: $iconPickerEntry) { entry in
            IconPickerView(selectedIcon: entry.icon) { newIcon in
                setIcon(newIcon, for: entry)
                iconPickerEntry = nil
            }
        }
        .alert(
            "Delete “\(entryPendingDeletion?.title.isEmpty == false ? entryPendingDeletion!.title : "Untitled Entry")”?",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { isPresented in if !isPresented { entryPendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let entry = entryPendingDeletion {
                    deleteEntry(entry)
                }
                entryPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                entryPendingDeletion = nil
            }
        } message: {
            Text("The entry's file will be moved to the Trash.")
        }
    }

    private func deleteEntry(_ entry: JournalEntryRecord) {
        let fileURL = vaultURL.appendingPathComponent(entry.relativePath)
        try? FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)

        if selection?.id == entry.id {
            selection = nil
        }

        modelContext.delete(entry)
        try? modelContext.save()
    }

    private enum MoveDirection { case up, down }

    private func setIcon(_ icon: String?, for entry: JournalEntryRecord) {
        entry.icon = icon
        persistEntryFrontmatter(entry)
        try? modelContext.save()
    }

    private func monthEntries(for entry: JournalEntryRecord) -> [JournalEntryRecord] {
        entries
            .filter { $0.monthKey == entry.monthKey }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func canMove(_ entry: JournalEntryRecord, direction: MoveDirection) -> Bool {
        let siblings = monthEntries(for: entry)
        guard let index = siblings.firstIndex(where: { $0.id == entry.id }) else { return false }
        return direction == .up ? index > 0 : index < siblings.count - 1
    }

    /// Swaps an entry with its neighbor within its own month, renumbers
    /// sortOrder sequentially, and persists to frontmatter.
    private func moveEntry(_ entry: JournalEntryRecord, direction: MoveDirection) {
        var siblings = monthEntries(for: entry)
        guard let currentIndex = siblings.firstIndex(where: { $0.id == entry.id }) else { return }
        let targetIndex = direction == .up ? currentIndex - 1 : currentIndex + 1
        guard siblings.indices.contains(targetIndex) else { return }

        siblings.swapAt(currentIndex, targetIndex)

        for (index, entry) in siblings.enumerated() where entry.sortOrder != index {
            entry.sortOrder = index
            persistEntryFrontmatter(entry)
        }

        try? modelContext.save()
    }

    /// Writes an entry's current cached frontmatter fields back to its file
    /// (body read fresh so it's never clobbered), then re-indexes it.
    private func persistEntryFrontmatter(_ entry: JournalEntryRecord) {
        let fileURL = vaultURL.appendingPathComponent(entry.relativePath)
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        let body = MarkdownFrontmatterParser.parse(contents).body
        let frontmatter = EntryFrontmatter(
            id: entry.id,
            title: entry.title,
            date: entry.date,
            createdAt: entry.createdAt,
            modifiedAt: entry.modifiedAt,
            icon: entry.icon,
            sortOrder: entry.sortOrder
        )
        try? EntryFileWriter.write(frontmatter: frontmatter, body: body, to: fileURL)
        EntryIndexer(modelContext: modelContext).reindexSingleFile(at: fileURL, vaultURL: vaultURL)
    }

    private func monthTitle(for monthKey: String) -> String {
        guard let date = Self.monthKeyFormatter.date(from: monthKey) else { return monthKey }
        return Self.displayFormatter.string(from: date)
    }

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

private struct EntryRow: View {
    let entry: JournalEntryRecord

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.icon ?? "doc.text")
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title.isEmpty ? "(untitled)" : entry.title)
                    .font(.body)
                    .lineLimit(1)
                if !entry.excerpt.isEmpty {
                    Text(entry.excerpt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
