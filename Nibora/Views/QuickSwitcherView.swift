//
//  QuickSwitcherView.swift
//  Nibora
//

import SwiftUI

/// Cmd+K palette for jumping straight to any entry by title or date,
/// without touching the sidebar's own search. Matching is a plain
/// case-insensitive substring check against title/date — same style as the
/// sidebar's existing search — not true fuzzy matching.
struct QuickSwitcherView: View {
    let entries: [JournalEntryRecord]
    let onSelect: (JournalEntryRecord) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredEntries: [JournalEntryRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? entries : entries.filter {
            $0.title.localizedStandardContains(trimmed) || Self.dateFormatter.string(from: $0.date).localizedStandardContains(trimmed)
        }
        return Array(source.sorted { $0.date > $1.date }.prefix(50))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Jump to entry…", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { selectTopMatch() }
            }
            .padding(12)

            Divider()

            if filteredEntries.isEmpty {
                Text("No matching entries")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredEntries, id: \.id) { entry in
                            Button {
                                onSelect(entry)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: entry.icon ?? "doc.text")
                                        .frame(width: 20)
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.title.isEmpty ? "(untitled)" : entry.title)
                                            .foregroundStyle(.primary)
                                        Text(Self.dateFormatter.string(from: entry.date))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 420)
        .onAppear { isSearchFocused = true }
        .onExitCommand { onDismiss() }
    }

    private func selectTopMatch() {
        guard let first = filteredEntries.first else { return }
        onSelect(first)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter
    }()
}
