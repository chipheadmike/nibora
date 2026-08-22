//
//  JournalStats.swift
//  Nibora
//

import Foundation

/// Vault-wide stats computed on demand from the already-loaded SwiftData
/// index — nothing here touches disk. Streaks are measured in unique
/// calendar days with at least one entry, not entry count, so multiple
/// same-day entries don't inflate a streak.
struct SentimentPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double
}

struct JournalStats {
    let totalEntries: Int
    let totalWords: Int
    let currentStreak: Int
    let longestStreak: Int
    let sentimentPoints: [SentimentPoint]
    let recentAverageSentiment: Double

    static func compute(from entries: [JournalEntryRecord]) -> JournalStats {
        let totalEntries = entries.count
        let totalWords = entries.reduce(0) { $0 + $1.searchableBody.split(whereSeparator: \.isWhitespace).count }

        let sentimentPoints = entries
            .sorted { $0.date < $1.date }
            .map { SentimentPoint(date: $0.date, score: $0.sentimentScore) }

        // "Recent" mood, not all-time average — the last 10 entries by date
        // reads as "how have I been lately," which is the more useful
        // question for a mood indicator than a lifetime average would be.
        let recentSample = entries.sorted { $0.date > $1.date }.prefix(10)
        let recentAverageSentiment = recentSample.isEmpty ? 0 : recentSample.reduce(0.0) { $0 + $1.sentimentScore } / Double(recentSample.count)

        let calendar = Calendar.current
        let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        let sortedDays = uniqueDays.sorted()

        var longestStreak = 0
        var runLength = 0
        var previousDay: Date?
        for day in sortedDays {
            if let previousDay, let expected = calendar.date(byAdding: .day, value: 1, to: previousDay), expected == day {
                runLength += 1
            } else {
                runLength = 1
            }
            longestStreak = max(longestStreak, runLength)
            previousDay = day
        }

        // Counts backward from today; if today has no entry yet, starts
        // from yesterday instead so an active streak still shows before
        // today's entry is written.
        var currentStreak = 0
        let today = calendar.startOfDay(for: Date())
        var cursor = uniqueDays.contains(today) ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        while uniqueDays.contains(cursor) {
            currentStreak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return JournalStats(
            totalEntries: totalEntries,
            totalWords: totalWords,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            sentimentPoints: sentimentPoints,
            recentAverageSentiment: recentAverageSentiment
        )
    }
}
