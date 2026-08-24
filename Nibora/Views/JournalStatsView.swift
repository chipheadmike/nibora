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

            if stats.totalEntries > 0 {
                Divider()
                Text("When You Write")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Chart(stats.hourlyActivity) { item in
                    BarMark(x: .value("Hour", item.hour), y: .value("Entries", item.count))
                        .foregroundStyle(.blue)
                }
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18]) { value in
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(Self.hourLabel(hour))
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 80)
            }

            if !stats.topWords.isEmpty {
                Divider()
                Text("Frequent Words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                WordCloudView(words: stats.topWords)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private static func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12am"
        case 12: return "12pm"
        case 1..<12: return "\(hour)am"
        default: return "\(hour - 12)pm"
        }
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

/// A word-frequency cloud — shared between Journal Stats and the Journal
/// Digest's Year in Review, so both render it identically.
struct WordCloudView: View {
    let words: [WordFrequency]

    var body: some View {
        let maxCount = words.map(\.count).max() ?? 1
        FlowLayout(spacing: 6) {
            ForEach(words) { item in
                Text(item.word)
                    .font(.system(size: fontSize(for: item.count, max: maxCount), weight: .semibold))
                    .foregroundStyle(Color.blue.opacity(0.5 + (Double(item.count) / Double(maxCount)) * 0.5))
            }
        }
    }

    private func fontSize(for count: Int, max: Int) -> CGFloat {
        let ratio = max > 0 ? Double(count) / Double(max) : 0
        return 12 + CGFloat(ratio) * 16
    }
}

/// Left-to-right wrapping layout for the word cloud — words vary in size,
/// so a fixed grid doesn't fit; this packs each row as full as it'll go
/// before wrapping, like text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)
        return CGSize(width: maxWidth.isFinite ? maxWidth : totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
