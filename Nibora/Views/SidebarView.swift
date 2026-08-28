//
//  SidebarView.swift
//  Nibora
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: JournalEntryRecord?
    let vaultURL: URL
    let sortMode: EntrySortMode
    let sortDirection: EntrySortDirection
    let searchText: String

    @Environment(\.modelContext) private var modelContext
    @Environment(TagColorPreferences.self) private var tagColorPreferences

    @Query private var entries: [JournalEntryRecord]

    @State private var iconPickerEntry: JournalEntryRecord?
    @State private var entryPendingDeletion: JournalEntryRecord?
    @State private var collapsedMonths: Set<String> = []
    @State private var selectedTag: String?
    @State private var tagPendingRename: String?
    @State private var renameText = ""
    @State private var tagColorPickerTag: String?
    @State private var tagPendingDeletion: String?

    /// Custom init so the within-month sort descriptor can vary with
    /// `sortMode` — SwiftData re-evaluates the fetch whenever this view is
    /// reconstructed with a new value, per Apple's documented dynamic-query
    /// pattern for @Query. Grouping into month sections happens manually in
    /// `groupedEntries` rather than via Query's `sectionBy:` — this beta's
    /// SDK updated mid-session and its `sectionBy` overload resolution
    /// shifted under us (confirmed via a from-scratch build against the
    /// same source), so it's not something to keep depending on. Search is
    /// likewise a plain client-side filter, not a SwiftData predicate.
    init(selection: Binding<JournalEntryRecord?>, vaultURL: URL, sortMode: EntrySortMode, sortDirection: EntrySortDirection, searchText: String) {
        self._selection = selection
        self.vaultURL = vaultURL
        self.sortMode = sortMode
        self.sortDirection = sortDirection
        self.searchText = searchText

        let secondarySort: SortDescriptor<JournalEntryRecord>
        switch sortMode {
        case .manual:
            secondarySort = SortDescriptor(\JournalEntryRecord.sortOrder)
        case .entryDate:
            secondarySort = SortDescriptor(\JournalEntryRecord.date, order: sortDirection.sortOrder)
        case .createdDate:
            secondarySort = SortDescriptor(\JournalEntryRecord.createdAt, order: sortDirection.sortOrder)
        case .modifiedDate:
            secondarySort = SortDescriptor(\JournalEntryRecord.modifiedAt, order: sortDirection.sortOrder)
        }

        _entries = Query(sort: [SortDescriptor(\JournalEntryRecord.monthKey, order: .reverse), secondarySort])
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Nibora")
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            tagFilterRow

            list
        }
    }

    /// All distinct "#tag" names used anywhere in the vault, derived from
    /// each entry's cached tagsRaw (itself computed at index time from the
    /// body — see EntryIndexer.extractTags). Hidden entirely when no entry
    /// uses any tags.
    private var allTags: [String] {
        var tags = Set<String>()
        for entry in entries where !entry.tagsRaw.isEmpty {
            tags.formUnion(entry.tagsRaw.split(separator: ",").map(String.init))
        }
        return tags.sorted()
    }

    private func pillBackground(for tag: String) -> Color {
        let custom = tagColorPreferences.color(for: tag)
        if selectedTag == tag {
            return custom ?? Color.accentColor
        }
        return custom?.opacity(0.2) ?? Color.secondary.opacity(0.15)
    }

    private func pillForeground(for tag: String) -> Color {
        if selectedTag == tag {
            return .white
        }
        return tagColorPreferences.color(for: tag) ?? Color.primary
    }

    /// A plain ColorPicker placed directly inside a .contextMenu renders
    /// but isn't interactive — NSMenu-backed context menus only reliably
    /// support simple buttons, not rich controls. A popover (already
    /// working for the icon picker below) is the proven pattern here.
    @ViewBuilder
    private func tagColorPicker(for tag: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ColorPicker("Color for #\(tag)", selection: Binding(
                get: { tagColorPreferences.color(for: tag) ?? Color.secondary },
                set: { tagColorPreferences.setColor($0, for: tag) }
            ), supportsOpacity: false)
            if tagColorPreferences.color(for: tag) != nil {
                Button("Reset to Default") {
                    tagColorPreferences.setColor(nil, for: tag)
                }
            }
        }
        .padding()
        .frame(width: 240)
    }

    /// Wraps to additional lines instead of a horizontal scroll — with a
    /// single-line ScrollView, tags past the sidebar's width were simply
    /// cut off with no visible indication there was more to scroll to.
    @ViewBuilder
    private var tagFilterRow: some View {
        if !allTags.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(allTags, id: \.self) { tag in
                    Button {
                        selectedTag = (selectedTag == tag) ? nil : tag
                    } label: {
                        Text("#\(tag)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(pillBackground(for: tag))
                            )
                            .foregroundStyle(pillForeground(for: tag))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: Binding(
                        get: { tagColorPickerTag == tag },
                        set: { isPresented in if !isPresented { tagColorPickerTag = nil } }
                    )) {
                        tagColorPicker(for: tag)
                    }
                    .contextMenu {
                        Button("Set Color…") {
                            tagColorPickerTag = tag
                        }
                        if tagColorPreferences.color(for: tag) != nil {
                            Button("Reset Color") {
                                tagColorPreferences.setColor(nil, for: tag)
                            }
                        }
                        Divider()
                        Button("Rename or Merge…") {
                            renameText = tag
                            tagPendingRename = tag
                        }
                        Button("Delete Tag", role: .destructive) {
                            tagPendingDeletion = tag
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }

    /// Manual month grouping, since SwiftData's sectionBy is where the beta
    /// churn hit. `entries` is already sorted month-desc then by the active
    /// sortMode, and Dictionary(grouping:) preserves that relative order
    /// within each group, so no re-sorting is needed here.
    private var groupedEntries: [(monthKey: String, entries: [JournalEntryRecord])] {
        let groups = Dictionary(grouping: entries, by: \.monthKey)
        return groups.keys.sorted(by: >).map { key in (key, groups[key] ?? []) }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(groupedEntries, id: \.monthKey) { group in
                let visibleEntries = matchingEntries(in: group.entries)
                if !visibleEntries.isEmpty {
                    Section(isExpanded: isExpandedBinding(for: group.monthKey)) {
                        ForEach(visibleEntries, id: \.id) { entry in
                            EntryRow(entry: entry, searchText: searchText)
                                .tag(entry)
                                .contextMenu {
                                    Button("Choose Icon…") {
                                        iconPickerEntry = entry
                                    }
                                    if sortMode == .manual {
                                        Divider()
                                        Button("Move Up") {
                                            moveEntry(entry, direction: .up)
                                        }
                                        .disabled(!canMove(entry, direction: .up))
                                        Button("Move Down") {
                                            moveEntry(entry, direction: .down)
                                        }
                                        .disabled(!canMove(entry, direction: .down))
                                    }
                                    Divider()
                                    Button("Delete…", role: .destructive) {
                                        entryPendingDeletion = entry
                                    }
                                }
                        }
                    } header: {
                        Text(monthTitle(for: group.monthKey))
                    }
                }
            }
        }
        .listStyle(.sidebar)
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
        .alert(
            "Rename “#\(tagPendingRename ?? "")”",
            isPresented: Binding(
                get: { tagPendingRename != nil },
                set: { isPresented in if !isPresented { tagPendingRename = nil } }
            )
        ) {
            TextField("New tag name", text: $renameText)
            Button("Rename") {
                if let tag = tagPendingRename {
                    renameTag(tag, to: renameText)
                }
                tagPendingRename = nil
            }
            Button("Cancel", role: .cancel) {
                tagPendingRename = nil
            }
        } message: {
            Text("Applies across every entry that uses this tag. Renaming to a tag that already exists merges the two.")
        }
        .alert(
            "Delete “#\(tagPendingDeletion ?? "")”?",
            isPresented: Binding(
                get: { tagPendingDeletion != nil },
                set: { isPresented in if !isPresented { tagPendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let tag = tagPendingDeletion {
                    deleteTag(tag)
                }
                tagPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                tagPendingDeletion = nil
            }
        } message: {
            Text("Removes “#\(tagPendingDeletion ?? "")” from every entry that uses it. The rest of each entry is left untouched.")
        }
    }

    private func deleteEntry(_ entry: JournalEntryRecord) {
        let fileURL = vaultURL.appendingPathComponent(entry.relativePath)
        try? FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)

        // Delete from the model (and save) before clearing selection — this
        // is what tears down EntryEditorView, whose onDisappear does an
        // unconditional flush-save of any pending edit. That guards itself
        // against a deleted entry by checking entry.modelContext == nil, so
        // the model deletion needs to be visible before selection changes,
        // not after — otherwise the flush can resurrect the just-trashed
        // file and its record.
        SpotlightIndexer.remove(id: entry.id)
        modelContext.delete(entry)
        try? modelContext.save()

        if selection?.id == entry.id {
            selection = nil
        }
    }

    private func renameTag(_ tag: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        TagManagementService.rename(tag: tag, to: trimmed, entries: entries, vaultURL: vaultURL, modelContext: modelContext)
        tagColorPreferences.handleRename(from: tag, to: trimmed)
        if selectedTag == tag {
            selectedTag = trimmed.lowercased()
        }
    }

    private func deleteTag(_ tag: String) {
        TagManagementService.delete(tag: tag, entries: entries, vaultURL: vaultURL, modelContext: modelContext)
        tagColorPreferences.handleDelete(tag)
        if selectedTag == tag {
            selectedTag = nil
        }
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
        // force: true — we just wrote this file ourselves, so we already
        // know it changed. The mtime-skip check reindexSingleFile normally
        // does exists for the passive full-vault rescan; here it's actively
        // wrong, since some filesystems (this app's own vault has run on a
        // network volume) round timestamps coarsely enough that two writes
        // moments apart can land on the same reported mtime, making the
        // check silently skip indexing this real change.
        EntryIndexer(modelContext: modelContext).reindexSingleFile(at: fileURL, vaultURL: vaultURL, force: true)
    }

    private func monthTitle(for monthKey: String) -> String {
        guard let date = Self.monthKeyFormatter.date(from: monthKey) else { return monthKey }
        return Self.displayFormatter.string(from: date)
    }

    private func matchingEntries(in section: some Sequence<JournalEntryRecord>) -> [JournalEntryRecord] {
        var results = Array(section)
        if let selectedTag {
            results = results.filter { $0.tagsRaw.split(separator: ",").map(String.init).contains(selectedTag) }
        }
        guard !searchText.isEmpty else { return results }
        return results.filter {
            $0.title.localizedStandardContains(searchText) || $0.searchableBody.localizedStandardContains(searchText)
        }
    }

    /// While actively searching or filtering by tag, sections always show
    /// expanded (so a match inside a collapsed month isn't hidden) —
    /// otherwise reflects and updates the per-month collapsed state.
    private func isExpandedBinding(for monthKey: String) -> Binding<Bool> {
        guard searchText.isEmpty, selectedTag == nil else { return .constant(true) }
        return Binding(
            get: { !collapsedMonths.contains(monthKey) },
            set: { expanded in
                if expanded {
                    collapsedMonths.remove(monthKey)
                } else {
                    collapsedMonths.insert(monthKey)
                }
            }
        )
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
    let searchText: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.icon ?? "doc.text")
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(highlighted(entry.title.isEmpty ? "(untitled)" : entry.title))
                    .font(.body)
                    .lineLimit(1)
                let snippet = displaySnippet()
                if !snippet.isEmpty {
                    Text(highlighted(snippet, baseColor: .secondary))
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// Normally just the cached excerpt (first ~120 characters of the
    /// body). While searching, always windows the shown text around the
    /// match rather than just returning the excerpt as-is — with
    /// `.lineLimit(1)` in a narrow sidebar column, a match sitting past
    /// what fits on one visible line gets truncated away before it's ever
    /// rendered, so the highlight attribute is technically there but never
    /// seen. Centering the window on the match is what actually fixes that
    /// (this was previously only done when the match fell outside the
    /// excerpt entirely, which missed the common case of a match further
    /// into an excerpt than the row's visible width).
    private func displaySnippet() -> String {
        guard !searchText.isEmpty else { return entry.excerpt }
        if let matchRange = entry.excerpt.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) {
            return contextSnippet(from: entry.excerpt, around: matchRange)
        }
        guard let matchRange = entry.searchableBody.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return entry.excerpt
        }
        return contextSnippet(from: entry.searchableBody, around: matchRange)
    }

    private func contextSnippet(from text: String, around range: Range<String.Index>) -> String {
        let contextLength = 40
        let start = text.index(range.lowerBound, offsetBy: -contextLength, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: contextLength, limitedBy: text.endIndex) ?? text.endIndex

        var snippet = String(text[start..<end]).replacingOccurrences(of: "\n", with: " ")
        if start != text.startIndex { snippet = "…" + snippet }
        if end != text.endIndex { snippet += "…" }
        return snippet
    }

    /// Highlights every case-insensitive occurrence of `searchText` with a
    /// background fill. Uses `String.range(of:options:)` directly on the
    /// original text (not a separately-lowercased copy) so the resulting
    /// ranges always map cleanly onto the AttributedString built from that
    /// same string. `baseColor`, when given, is baked into the
    /// AttributedString itself rather than left to a wrapping
    /// `.foregroundStyle()` modifier — that modifier can override
    /// per-range AttributedString attributes (including the highlight),
    /// which is why the title (no such modifier) highlighted correctly
    /// while the secondary-styled excerpt/snippet didn't.
    private func highlighted(_ text: String, baseColor: Color? = nil) -> AttributedString {
        var attributed = AttributedString(text)
        if let baseColor {
            attributed.foregroundColor = baseColor
        }
        guard !searchText.isEmpty else { return attributed }

        var searchRange = text.startIndex..<text.endIndex
        while let foundRange = text.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
            if let attributedRange = Range(foundRange, in: attributed) {
                attributed[attributedRange].backgroundColor = .yellow.opacity(0.4)
                attributed[attributedRange].foregroundColor = .black
            }
            searchRange = foundRange.upperBound..<text.endIndex
        }
        return attributed
    }
}
