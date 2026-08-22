//
//  CalendarHeatmapView.swift
//  Nibora
//

import SwiftUI

/// GitHub-contributions-style writing frequency grid over the past year —
/// one column per week, one cell per day, shaded by word count that day.
/// Complements the streak numbers already in Journal Stats with an
/// at-a-glance view of the whole year.
struct CalendarHeatmapView: View {
    let entries: [JournalEntryRecord]
    let onSelectDate: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Writing Calendar")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 3) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, column in
                            Text(monthLabel(for: column) ?? "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: cellSize)
                        }
                    }

                    HStack(alignment: .top, spacing: 3) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, column in
                            VStack(spacing: 3) {
                                ForEach(Array(column.enumerated()), id: \.offset) { _, date in
                                    cell(for: date)
                                }
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        Text("Less")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(0..<5) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(forLevel: level))
                                .frame(width: cellSize, height: cellSize)
                        }
                        Text("More")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
        .frame(width: 820, height: 320)
    }

    private let cellSize: CGFloat = 13

    @ViewBuilder
    private func cell(for date: Date?) -> some View {
        if let date {
            let count = dailyWordCounts[date] ?? 0
            Button {
                onSelectDate(date)
            } label: {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: count))
                    .frame(width: cellSize, height: cellSize)
            }
            .buttonStyle(.plain)
            .help("\(Self.dayFormatter.string(from: date)): \(count) word\(count == 1 ? "" : "s")")
        } else {
            Color.clear.frame(width: cellSize, height: cellSize)
        }
    }

    /// Total word count per calendar day, summed across every entry dated
    /// that day (a day can have more than one entry via the "-1" filename
    /// suffix).
    private var dailyWordCounts: [Date: Int] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            let words = entry.searchableBody.split(whereSeparator: \.isWhitespace).count
            counts[day, default: 0] += words
        }
        return counts
    }

    /// 52-53 columns of 7 days (Sunday-start), covering the past year up
    /// through today. The final column is padded with nil for days beyond
    /// today; the first column is padded with nil for days before the
    /// one-year-back start date.
    private var weeks: [[Date?]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let oneYearAgo = calendar.date(byAdding: .day, value: -364, to: today) else { return [] }
        let startWeekday = calendar.component(.weekday, from: oneYearAgo)
        guard let gridStart = calendar.date(byAdding: .day, value: -(startWeekday - 1), to: oneYearAgo) else { return [] }

        var columns: [[Date?]] = []
        var cursor = gridStart
        while cursor <= today {
            var column: [Date?] = []
            for _ in 0..<7 {
                if cursor >= gridStart && cursor <= today {
                    column.append(cursor)
                } else {
                    column.append(nil)
                }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
            columns.append(column)
        }
        return columns
    }

    /// Labels a column with its month abbreviation only when that column
    /// contains the first few days of a new month, so labels roughly line
    /// up with where each month actually starts rather than repeating.
    private func monthLabel(for column: [Date?]) -> String? {
        guard let firstDate = column.compactMap({ $0 }).first else { return nil }
        guard Calendar.current.component(.day, from: firstDate) <= 7 else { return nil }
        return Self.monthFormatter.string(from: firstDate)
    }

    private func color(for wordCount: Int) -> Color {
        switch wordCount {
        case 0: return color(forLevel: 0)
        case 1..<100: return color(forLevel: 1)
        case 100..<300: return color(forLevel: 2)
        case 300..<600: return color(forLevel: 3)
        default: return color(forLevel: 4)
        }
    }

    private func color(forLevel level: Int) -> Color {
        switch level {
        case 0: return Color.secondary.opacity(0.12)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.5)
        case 3: return Color.green.opacity(0.75)
        default: return Color.green
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
