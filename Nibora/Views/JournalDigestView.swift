//
//  JournalDigestView.swift
//  Nibora
//

import SwiftUI
import Charts
import FoundationModels

/// A one-shot AI-generated recap of recent entries — reuses the same
/// provider plumbing as Ask Nibora, just with a fixed summarization prompt
/// and a date-range window instead of a user-typed question.
struct JournalDigestView: View {
    let entries: [JournalEntryRecord]

    @Environment(\.dismiss) private var dismiss
    @Environment(AIProviderPreferences.self) private var aiProviderPreferences
    @State private var period: DigestPeriod = .week
    @State private var digest: String?
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private var queryService: JournalQueryService {
        JournalQueryService(preferences: aiProviderPreferences)
    }

    private var unavailableReason: String? {
        queryService.checkAvailability()
    }

    private var entriesInRange: [JournalEntryRecord] {
        JournalQueryService.entriesInRange(entries, for: period)
    }

    private var periodStats: JournalStats {
        JournalStats.compute(from: entriesInRange)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Journal Digest")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if let unavailableReason {
                ContentUnavailableView(
                    "\(aiProviderPreferences.selectedProvider.label) Unavailable",
                    systemImage: "text.book.closed",
                    description: Text(unavailableReason)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Picker("Period", selection: $period) {
                    ForEach(DigestPeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: period) {
                    digest = nil
                    errorMessage = nil
                }

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !entriesInRange.isEmpty {
                            statsSummary

                            if periodStats.sentimentPoints.count > 1 {
                                Text("Mood Over This Period")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Chart(periodStats.sentimentPoints) { point in
                                    LineMark(x: .value("Date", point.date), y: .value("Sentiment", point.score))
                                        .foregroundStyle(.blue)
                                    AreaMark(x: .value("Date", point.date), y: .value("Sentiment", point.score))
                                        .foregroundStyle(.blue.opacity(0.12))
                                }
                                .chartYScale(domain: -1...1)
                                .chartYAxis(.hidden)
                                .chartXAxis(.hidden)
                                .frame(height: 70)
                            }

                            if !periodStats.topWords.isEmpty {
                                Text("Frequent Words")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                WordCloudView(words: periodStats.topWords)
                            }

                            Divider()
                        }

                        if let digest {
                            Text(digest)
                                .textSelection(.enabled)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                        }
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        if isGenerating {
                            ProgressView("Reading back through your journal…")
                        }
                        if digest == nil && errorMessage == nil && !isGenerating {
                            if entriesInRange.isEmpty {
                                Text("No entries in this period yet.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(providerPrivacyNote)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                HStack {
                    Spacer()
                    Button("Generate Digest") { generate() }
                        .disabled(entriesInRange.isEmpty || isGenerating)
                }
                .padding(12)
            }
        }
        .frame(width: 480, height: 600)
    }

    private var statsSummary: some View {
        HStack(spacing: 20) {
            statTile("Entries", "\(periodStats.totalEntries)")
            statTile("Words", Self.numberFormatter.string(from: NSNumber(value: periodStats.totalWords)) ?? "\(periodStats.totalWords)")
            statTile("Longest Streak", periodStats.longestStreak == 1 ? "1 day" : "\(periodStats.longestStreak) days")
        }
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private var providerPrivacyNote: String {
        switch aiProviderPreferences.selectedProvider {
        case .onDevice: return "Everything runs on-device; nothing leaves this Mac."
        case .claude: return "These entries will be sent to Anthropic's Claude API."
        case .chatGPT: return "These entries will be sent to OpenAI's ChatGPT API."
        }
    }

    private func generate() {
        isGenerating = true
        errorMessage = nil
        digest = nil
        Task {
            do {
                digest = try await queryService.summarize(entries: entriesInRange, period: period)
            } catch let error as LanguageModelSession.GenerationError {
                if case .guardrailViolation = error {
                    errorMessage = "The on-device model declined to summarize — its built-in safety filter triggered even on ordinary journal content. This is a known limitation of the current Apple Intelligence beta, not a Nibora issue. Try again later, or switch providers in Settings > AI."
                } else {
                    errorMessage = "Something went wrong generating the digest: \(error.localizedDescription)"
                }
            } catch {
                errorMessage = "Something went wrong generating the digest: \(error.localizedDescription)"
            }
            isGenerating = false
        }
    }
}
