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

struct WordFrequency: Identifiable {
    let id = UUID()
    let word: String
    let count: Int
}

struct HourlyActivity: Identifiable {
    let id: Int
    let hour: Int
    let count: Int
}

struct JournalStats {
    let totalEntries: Int
    let totalWords: Int
    let currentStreak: Int
    let longestStreak: Int
    let sentimentPoints: [SentimentPoint]
    let recentAverageSentiment: Double
    let topWords: [WordFrequency]
    let hourlyActivity: [HourlyActivity]

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
            recentAverageSentiment: recentAverageSentiment,
            topWords: computeTopWords(from: entries),
            hourlyActivity: computeHourlyActivity(from: entries)
        )
    }

    /// Frequency across the whole vault, common function words filtered
    /// out. Not stemmed/lemmatized — "walk" and "walking" count separately
    /// — a lightweight pass is enough for a glance-able cloud, not a
    /// linguistic analysis.
    private static func computeTopWords(from entries: [JournalEntryRecord], limit: Int = 30) -> [WordFrequency] {
        var counts: [String: Int] = [:]
        for entry in entries {
            let words = entry.searchableBody.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 && !wordCloudStopwords.contains($0) }
            for word in words {
                counts[word, default: 0] += 1
            }
        }
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map { WordFrequency(word: $0.key, count: $0.value) }
    }

    /// Buckets by the hour an entry was first created (not last modified —
    /// modifiedAt would skew toward whenever an entry was last touched,
    /// which is a weaker signal of "when do I actually sit down to write"
    /// than when it was started).
    private static func computeHourlyActivity(from entries: [JournalEntryRecord]) -> [HourlyActivity] {
        let calendar = Calendar.current
        var counts = [Int: Int]()
        for entry in entries {
            let hour = calendar.component(.hour, from: entry.createdAt)
            counts[hour, default: 0] += 1
        }
        return (0..<24).map { hour in HourlyActivity(id: hour, hour: hour, count: counts[hour] ?? 0) }
    }

    private static let wordCloudStopwords: Set<String> = [
        "the", "and", "for", "are", "was", "were", "been", "being", "have", "has",
        "had", "having", "this", "that", "these", "those", "with", "from", "into",
        "about", "against", "between", "through", "during", "before", "after",
        "above", "below", "again", "further", "then", "once", "here", "there",
        "when", "where", "why", "how", "all", "any", "both", "each", "few",
        "more", "most", "other", "some", "such", "nor", "not", "only", "own",
        "same", "than", "too", "very", "can", "will", "just", "should", "now",
        "did", "does", "doing", "what", "which", "who", "whom", "would", "could",
        "you", "your", "yours", "yourself", "he", "him", "his", "she", "her",
        "hers", "herself", "it", "its", "itself", "they", "them", "their",
        "theirs", "themselves", "who", "whom", "and", "but", "because", "until",
        "while", "off", "over", "under", "again", "out", "up", "down", "she's",
        "i'm", "i've", "i'd", "i'll", "you're", "you've", "that's", "there's",
        "don't", "didn't", "wasn't", "weren't", "isn't", "aren't", "haven't",
        "hasn't", "hadn't", "couldn't", "wouldn't", "shouldn't", "im", "ive",
        "id", "ill", "youre", "youve", "thats", "theres", "dont", "didnt",
        "wasnt", "werent", "isnt", "arent", "havent", "hasnt", "hadnt"
    ]
}
