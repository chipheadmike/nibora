//
//  JournalStatsView.swift
//  Nibora
//

import SwiftUI

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
        }
        .padding(16)
        .frame(width: 240)
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

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}
