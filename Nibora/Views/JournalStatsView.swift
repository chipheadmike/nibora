//
//  JournalStatsView.swift
//  Nibora
//

import SwiftUI
import Charts

struct JournalStatsView: View {
    let stats: JournalStats

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Journal Stats")
                .font(.headline)

            statRow(label: "Total Entries", value: "\(stats.totalEntries)")
            statRow(label: "Total Words", value: Self.numberFormatter.string(from: NSNumber(value: stats.totalWords)) ?? "\(stats.totalWords)")
            statRow(label: "Current Streak", value: streakText(stats.currentStreak))
            statRow(label: "Longest Streak", value: streakText(stats.longestStreak))
            statRow(label: "Recent Mood", value: "\(moodEmoji(for: stats.recentAverageSentiment)) \(moodLabel(for: stats.recentAverageSentiment))")

            if stats.sentimentPoints.count > 1 {
                Divider()
                Text("Mood Over Time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Chart(stats.sentimentPoints) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Sentiment", point.score))
                        .foregroundStyle(.blue)
                    AreaMark(x: .value("Date", point.date), y: .value("Sentiment", point.score))
                        .foregroundStyle(.blue.opacity(0.12))
                }
                .chartYScale(domain: -1...1)
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 90)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }

    private func streakText(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }

    /// On-device sentiment (SentimentAnalyzer) ranges roughly -1 to 1;
    /// these thresholds are a rough, not statistically tuned, split into
    /// three bands for a quick-glance indicator.
    private func moodEmoji(for score: Double) -> String {
        if score > 0.3 { return "😊" }
        if score < -0.3 { return "🙁" }
        return "😐"
    }

    private func moodLabel(for score: Double) -> String {
        if score > 0.3 { return "Upbeat" }
        if score < -0.3 { return "Rough" }
        return "Steady"
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}
