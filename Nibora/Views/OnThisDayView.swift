//
//  OnThisDayView.swift
//  Nibora
//

import SwiftUI

/// Surfaces past entries dated on today's month/day across previous years —
/// a personal-journal callback feature (Day One-style "On This Day"). Pure
/// date-part matching against the entries already cached in the SwiftData
/// index — no extra parsing or disk reads.
struct OnThisDayView: View {
    let entries: [JournalEntryRecord]
    let onSelect: (JournalEntryRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("On This Day")
                .font(.headline)
                .padding(12)

            Divider()

            if entries.isEmpty {
                Text("No past entries from this day.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(entries, id: \.id) { entry in
                            Button {
                                onSelect(entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Self.yearFormatter.string(from: entry.date))
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    Text(entry.title.isEmpty ? "(untitled)" : entry.title)
                                        .foregroundStyle(.primary)
                                    if !entry.excerpt.isEmpty {
                                        Text(entry.excerpt)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
        .frame(width: 360)
    }

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter
    }()
}
