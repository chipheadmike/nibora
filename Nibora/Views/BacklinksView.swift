//
//  BacklinksView.swift
//  Nibora
//

import SwiftUI

/// Entries that reference the current one via "[[Title]]" — the reverse
/// direction of MarkdownTextView's wikilink navigation. Computed fresh from
/// the already-loaded entry list each render (see EntryEditorView.
/// backlinkEntries); nothing new is indexed or cached for this, since
/// scanning cached searchableBody at render time is cheap enough for a
/// personal journal's entry count. Hidden entirely when there are none,
/// same as AttachmentsStripView.
struct BacklinksView: View {
    let entries: [JournalEntryRecord]
    let onSelect: (JournalEntryRecord) -> Void

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Linked From")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)

                ForEach(entries, id: \.id) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: entry.icon ?? "doc.text")
                                .foregroundStyle(.secondary)
                            Text(entry.title.isEmpty ? "(untitled)" : entry.title)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
        }
    }
}
