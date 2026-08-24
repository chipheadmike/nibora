//
//  FreeformSidebarView.swift
//  Nibora
//

import SwiftUI
import SwiftData

/// Sidebar for a Freeform vault — a folder tree instead of Journal's month
/// sections. The tree is built by walking the filesystem directly (not
/// derived from indexed entries), so a folder the user just created shows
/// up immediately even before anything's filed into it.
struct FreeformSidebarView: View {
    @Binding var selection: JournalEntryRecord?
    let vaultURL: URL
    let searchText: String

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\JournalEntryRecord.title)]) private var entries: [JournalEntryRecord]

    /// Bumped after any folder create/rename/delete to force `tree` to
    /// recompute — folder-only changes don't touch `entries`, so nothing
    /// else would trigger a re-render.
    @State private var refreshTrigger = 0

    @State private var entryPendingDeletion: JournalEntryRecord?
    @State private var folderPendingNewEntry: FreeformNode?
    @State private var newEntryTitle = ""
    @State private var folderPendingNewFolder: FreeformNode?
    @State private var newFolderName = ""
    @State private var folderPendingRename: FreeformNode?
    @State private var renameFolderName = ""
    @State private var folderPendingDeletion: FreeformNode?
    @State private var folderDeletionError: String?

    private var tree: FreeformNode {
        _ = refreshTrigger
        return Self.buildTree(at: vaultURL, relativePath: "", vaultURL: vaultURL, allEntries: entries)
    }

    private var filteredEntries: [JournalEntryRecord] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) || $0.searchableBody.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Nibora")
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !searchText.isEmpty {
                List(selection: Binding(get: { selection }, set: { selection = $0 })) {
                    ForEach(filteredEntries) { entry in
                        entryRow(entry)
                    }
                }
                .listStyle(.sidebar)
            } else if tree.entries.isEmpty && tree.subfolders.isEmpty {
                ContentUnavailableView(
                    "No Entries Yet",
                    systemImage: "folder",
                    description: Text("Click New Entry above to get started, or right-click here to create a folder first.")
                )
                .contextMenu {
                    Button("New Entry") { folderPendingNewEntry = tree; newEntryTitle = "" }
                    Button("New Folder") { folderPendingNewFolder = tree; newFolderName = "" }
                }
            } else {
                List {
                    ForEach(tree.entries) { entry in
                        entryRow(entry)
                    }
                    ForEach(tree.subfolders) { folder in
                        FreeformFolderRow(
                            node: folder,
                            selection: $selection,
                            onNewEntry: { folderPendingNewEntry = $0; newEntryTitle = "" },
                            onNewFolder: { folderPendingNewFolder = $0; newFolderName = "" },
                            onRename: { folderPendingRename = $0; renameFolderName = $0.name },
                            onDelete: { folderPendingDeletion = $0 },
                            onDeleteEntry: { entryPendingDeletion = $0 },
                            onMoveEntry: { moveEntry($0, toFolder: $1) },
                            onMoveEntryToRoot: { moveEntry($0, toFolder: nil) }
                        )
                    }
                }
                .listStyle(.sidebar)
                .contextMenu {
                    Button("New Entry") { folderPendingNewEntry = tree; newEntryTitle = "" }
                    Button("New Folder") { folderPendingNewFolder = tree; newFolderName = "" }
                }
            }
        }
        .alert(
            "New Entry",
            isPresented: Binding(
                get: { folderPendingNewEntry != nil },
                set: { if !$0 { folderPendingNewEntry = nil } }
            )
        ) {
            TextField("Title", text: $newEntryTitle)
            Button("Create") {
                if let folder = folderPendingNewEntry {
                    createEntry(title: newEntryTitle, in: folder)
                }
                folderPendingNewEntry = nil
            }
            Button("Cancel", role: .cancel) { folderPendingNewEntry = nil }
        }
        .alert(
            "New Folder",
            isPresented: Binding(
                get: { folderPendingNewFolder != nil },
                set: { if !$0 { folderPendingNewFolder = nil } }
            )
        ) {
            TextField("Folder Name", text: $newFolderName)
            Button("Create") {
                if let parent = folderPendingNewFolder {
                    createFolder(named: newFolderName, in: parent)
                }
                folderPendingNewFolder = nil
            }
            Button("Cancel", role: .cancel) { folderPendingNewFolder = nil }
        }
        .alert(
            "Rename “\(folderPendingRename?.name ?? "")”",
            isPresented: Binding(
                get: { folderPendingRename != nil },
                set: { if !$0 { folderPendingRename = nil } }
            )
        ) {
            TextField("Folder Name", text: $renameFolderName)
            Button("Rename") {
                if let folder = folderPendingRename {
                    renameFolder(folder, to: renameFolderName)
                }
                folderPendingRename = nil
            }
            Button("Cancel", role: .cancel) { folderPendingRename = nil }
        }
        .alert(
            "Delete “\(folderPendingDeletion?.name ?? "")”?",
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { if !$0 { folderPendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let folder = folderPendingDeletion {
                    deleteFolder(folder)
                }
                folderPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { folderPendingDeletion = nil }
        } message: {
            Text("The folder must be empty. Move or delete its contents first.")
        }
        .alert(
            "Couldn't Delete Folder",
            isPresented: Binding(
                get: { folderDeletionError != nil },
                set: { if !$0 { folderDeletionError = nil } }
            )
        ) {
            Button("OK") { folderDeletionError = nil }
        } message: {
            Text(folderDeletionError ?? "")
        }
        .alert(
            "Delete “\(entryPendingDeletion?.title.isEmpty == false ? entryPendingDeletion!.title : "Untitled Entry")”?",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let entry = entryPendingDeletion {
                    deleteEntry(entry)
                }
                entryPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { entryPendingDeletion = nil }
        } message: {
            Text("The entry's file will be moved to the Trash.")
        }
    }

    private func entryRow(_ entry: JournalEntryRecord) -> some View {
        Button {
            selection = entry
        } label: {
            HStack(spacing: 8) {
                Image(systemName: entry.icon ?? "doc.text")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title.isEmpty ? "Untitled" : entry.title)
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
        .buttonStyle(.plain)
        .listRowBackground(selection?.id == entry.id ? Color.accentColor.opacity(0.25) : Color.clear)
        .contextMenu {
            Button("Move to Root") { moveEntry(entry, toFolder: nil) }
            Divider()
            Button("Delete…", role: .destructive) { entryPendingDeletion = entry }
        }
        .draggable(entry.id.uuidString)
    }

    private func createEntry(title: String, in folder: FreeformNode) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let relativePath = try? EntryFileWriter.createFreeformEntry(title: trimmed, folderRelativePath: folder.relativePath.isEmpty ? nil : folder.relativePath, in: vaultURL) else { return }
        let fileURL = vaultURL.appendingPathComponent(relativePath)
        EntryIndexer(modelContext: modelContext).reindexSingleFile(at: fileURL, vaultURL: vaultURL, force: true)

        let descriptor = FetchDescriptor<JournalEntryRecord>(predicate: #Predicate { $0.relativePath == relativePath })
        selection = try? modelContext.fetch(descriptor).first
    }

    private func createFolder(named name: String, in parent: FreeformNode) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let parentURL = parent.relativePath.isEmpty ? vaultURL : vaultURL.appendingPathComponent(parent.relativePath, isDirectory: true)
        try? FileManager.default.createDirectory(at: parentURL.appendingPathComponent(trimmed, isDirectory: true), withIntermediateDirectories: true)
        refreshTrigger += 1
    }

    private func renameFolder(_ folder: FreeformNode, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != folder.name else { return }
        let oldURL = vaultURL.appendingPathComponent(folder.relativePath, isDirectory: true)
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(trimmed, isDirectory: true)
        guard (try? FileManager.default.moveItem(at: oldURL, to: newURL)) != nil else { return }
        EntryIndexer(modelContext: modelContext).rescanFullVault(at: vaultURL, force: true)
        refreshTrigger += 1
    }

    private func deleteFolder(_ folder: FreeformNode) {
        guard folder.entries.isEmpty, folder.subfolders.isEmpty else {
            folderDeletionError = "“\(folder.name)” still has entries or folders inside it."
            return
        }
        let folderURL = vaultURL.appendingPathComponent(folder.relativePath, isDirectory: true)
        try? FileManager.default.trashItem(at: folderURL, resultingItemURL: nil)
        refreshTrigger += 1
    }

    /// Moving a file changes its relativePath, so its SwiftData record
    /// (matched by relativePath) needs a full rescan rather than a targeted
    /// reindex — that single pass both upserts the new path and prunes the
    /// stale old one, reusing the same logic a manual Rescan Vault would.
    private func moveEntry(_ entry: JournalEntryRecord, toFolder folder: FreeformNode?) {
        let oldURL = vaultURL.appendingPathComponent(entry.relativePath)
        let targetFolderURL = (folder?.relativePath).map { $0.isEmpty ? vaultURL : vaultURL.appendingPathComponent($0, isDirectory: true) } ?? vaultURL
        guard targetFolderURL != oldURL.deletingLastPathComponent() else { return }

        try? FileManager.default.createDirectory(at: targetFolderURL, withIntermediateDirectories: true)
        let newURL = targetFolderURL.appendingPathComponent(oldURL.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: newURL.path) else { return }
        guard (try? FileManager.default.moveItem(at: oldURL, to: newURL)) != nil else { return }

        EntryIndexer(modelContext: modelContext).rescanFullVault(at: vaultURL, force: true)
        refreshTrigger += 1
    }

    private func deleteEntry(_ entry: JournalEntryRecord) {
        let fileURL = vaultURL.appendingPathComponent(entry.relativePath)
        try? FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)

        // Same ordering as SidebarView.deleteEntry — delete from the model
        // before clearing selection, since selection change tears down
        // EntryEditorView, whose flush-save guards itself against a
        // deleted entry by checking entry.modelContext == nil.
        modelContext.delete(entry)
        try? modelContext.save()

        if selection?.id == entry.id {
            selection = nil
        }
    }

    /// Walks the filesystem (not SwiftData) so an empty folder the user
    /// just created shows up immediately. Attachments folders are excluded
    /// so they never appear as a browsable folder in the tree.
    static func buildTree(at folderURL: URL, relativePath: String, vaultURL: URL, allEntries: [JournalEntryRecord]) -> FreeformNode {
        var subfolders: [FreeformNode] = []

        if let contents = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for itemURL in contents.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
                let isDirectory = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard isDirectory, itemURL.lastPathComponent != "Attachments" else { continue }
                let childRelativePath = relativePath.isEmpty ? itemURL.lastPathComponent : "\(relativePath)/\(itemURL.lastPathComponent)"
                subfolders.append(buildTree(at: itemURL, relativePath: childRelativePath, vaultURL: vaultURL, allEntries: allEntries))
            }
        }

        let ownEntries = allEntries.filter { entry in
            (entry.relativePath as NSString).deletingLastPathComponent == relativePath
        }

        return FreeformNode(id: relativePath, name: folderURL.lastPathComponent, relativePath: relativePath, subfolders: subfolders, entries: ownEntries)
    }
}

struct FreeformNode: Identifiable {
    let id: String
    let name: String
    let relativePath: String
    var subfolders: [FreeformNode]
    var entries: [JournalEntryRecord]
}

private struct FreeformFolderRow: View {
    let node: FreeformNode
    @Binding var selection: JournalEntryRecord?
    let onNewEntry: (FreeformNode) -> Void
    let onNewFolder: (FreeformNode) -> Void
    let onRename: (FreeformNode) -> Void
    let onDelete: (FreeformNode) -> Void
    let onDeleteEntry: (JournalEntryRecord) -> Void
    let onMoveEntry: (JournalEntryRecord, FreeformNode) -> Void
    let onMoveEntryToRoot: (JournalEntryRecord) -> Void

    @State private var isExpanded = true
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [JournalEntryRecord]

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(node.subfolders) { child in
                FreeformFolderRow(
                    node: child,
                    selection: $selection,
                    onNewEntry: onNewEntry,
                    onNewFolder: onNewFolder,
                    onRename: onRename,
                    onDelete: onDelete,
                    onDeleteEntry: onDeleteEntry,
                    onMoveEntry: onMoveEntry,
                    onMoveEntryToRoot: onMoveEntryToRoot
                )
            }
            ForEach(node.entries) { entry in
                Button {
                    selection = entry
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: entry.icon ?? "doc.text")
                            .foregroundStyle(.secondary)
                        Text(entry.title.isEmpty ? "Untitled" : entry.title)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(selection?.id == entry.id ? Color.accentColor.opacity(0.25) : Color.clear)
                .contextMenu {
                    Button("Move to Root") { onMoveEntryToRoot(entry) }
                    Divider()
                    Button("Delete…", role: .destructive) { onDeleteEntry(entry) }
                }
                .draggable(entry.id.uuidString)
            }
        } label: {
            // The context menu is scoped to just this label, not the whole
            // DisclosureGroup — attaching it to the group itself swallowed
            // the entries' own context menus underneath (right-clicking an
            // entry inside a folder opened the folder's Delete instead).
            Label(node.name, systemImage: "folder")
                .contextMenu {
                    Button("New Entry") { onNewEntry(node) }
                    Button("New Folder") { onNewFolder(node) }
                    Divider()
                    Button("Rename…") { onRename(node) }
                    Button("Delete…", role: .destructive) { onDelete(node) }
                }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first, let id = UUID(uuidString: idString) else { return false }
            guard let entry = allEntries.first(where: { $0.id == id }) else { return false }
            onMoveEntry(entry, node)
            return true
        }
    }
}
