//
//  JournalQueryService.swift
//  Nibora
//

import Foundation

/// A rolling window (not a calendar week/month) so the digest is always
/// meaningful regardless of what day it is — no partial-week edge cases.
enum DigestPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return "Past 7 Days"
        case .month: return "Past 30 Days"
        case .year: return "Past Year"
        }
    }

    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

/// Routes a journal question to whichever AI backend the user has selected
/// (see AIProviderPreferences) — the relevant-excerpt retrieval below is
/// shared across all three providers; only the "send it to a model" step
/// differs, and that's each provider's own concern via JournalAIProvider.
@Observable
final class JournalQueryService {
    private let preferences: AIProviderPreferences

    init(preferences: AIProviderPreferences) {
        self.preferences = preferences
    }

    func checkAvailability() -> String? {
        switch preferences.selectedProvider {
        case .onDevice:
            return OnDeviceAIProvider.checkAvailability()
        case .claude:
            return preferences.claudeAPIKey.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Add your Anthropic API key in Settings > AI to use Claude."
                : nil
        case .chatGPT:
            return preferences.openAIAPIKey.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Add your OpenAI API key in Settings > AI to use ChatGPT."
                : nil
        }
    }

    func ask(_ question: String, entries: [JournalEntryRecord]) async throws -> String {
        let context = Self.contextBlock(for: question, entries: entries)
        return try await makeProvider().ask(question: question, context: context)
    }

    /// Unlike `ask`, this feeds the model every entry in range (chronological,
    /// not keyword-scored) since a digest needs the whole period, not just
    /// the parts that match a query.
    static func entriesInRange(_ entries: [JournalEntryRecord], for period: DigestPeriod) -> [JournalEntryRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -period.dayCount, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return entries.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    func summarize(entries: [JournalEntryRecord], period: DigestPeriod) async throws -> String {
        let prompt = "Summarize my journal entries from the \(period.label.lowercased()). Identify recurring themes, notable events, and how my mood seemed to shift, in a few short paragraphs. Write directly to me, in second person, as a reflective summary — not a list of dates."
        let context = Self.digestContextBlock(for: entries)
        return try await makeProvider().ask(question: prompt, context: context)
    }

    private func makeProvider() -> JournalAIProvider {
        switch preferences.selectedProvider {
        case .onDevice: return OnDeviceAIProvider()
        case .claude: return ClaudeAIProvider(apiKey: preferences.claudeAPIKey)
        case .chatGPT: return ChatGPTAIProvider(apiKey: preferences.openAIAPIKey)
        }
    }

    /// Feeds the model a small, keyword-relevant slice of the journal
    /// rather than everything — every provider here has a limited context
    /// window one way or another, and this is a much closer approximation
    /// of "search my journal" than either dumping the whole vault in or
    /// only looking at recent entries.
    private static func contextBlock(for question: String, entries: [JournalEntryRecord], limit: Int = 5) -> String {
        relevantEntries(for: question, in: entries, limit: limit)
            .map { entry in "[\(dateFormatter.string(from: entry.date))] \(entry.title): \(entry.searchableBody.prefix(400))" }
            .joined(separator: "\n\n")
    }

    private static func relevantEntries(for question: String, in entries: [JournalEntryRecord], limit: Int) -> [JournalEntryRecord] {
        let stopwords: Set<String> = [
            "the", "a", "an", "is", "are", "was", "were", "what", "when", "where", "how",
            "did", "do", "does", "i", "my", "me", "about", "in", "on", "of", "to", "have", "has", "had"
        ]
        let keywords = question.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) }

        guard !keywords.isEmpty else {
            return Array(entries.sorted { $0.date > $1.date }.prefix(limit))
        }

        let scored = entries.map { entry -> (entry: JournalEntryRecord, score: Int) in
            let bodyLower = entry.searchableBody.lowercased()
            let score = keywords.reduce(0) { $0 + (bodyLower.contains($1) ? 1 : 0) }
            return (entry, score)
        }
        let matched = scored.filter { $0.score > 0 }.sorted { $0.score > $1.score }
        guard !matched.isEmpty else {
            return Array(entries.sorted { $0.date > $1.date }.prefix(limit))
        }
        return Array(matched.prefix(limit).map(\.entry))
    }

    /// Entries here are already date-range-filtered (via entriesInRange), so
    /// unlike contextBlock this doesn't also score/limit by keyword — it
    /// includes everything in the period, just truncated per-entry to keep
    /// the total prompt size reasonable.
    private static func digestContextBlock(for entries: [JournalEntryRecord], characterLimitPerEntry: Int = 600, maxEntries: Int = 50) -> String {
        Self.sampled(entries, maxCount: maxEntries)
            .map { entry in "[\(dateFormatter.string(from: entry.date))] \(entry.title): \(entry.searchableBody.prefix(characterLimitPerEntry))" }
            .joined(separator: "\n\n")
    }

    /// Evenly spaced across the full range rather than just the most recent
    /// — a year's worth of daily entries would otherwise blow well past any
    /// provider's context window (on-device especially), so long periods
    /// like Year in Review get representative coverage instead of everything.
    private static func sampled(_ entries: [JournalEntryRecord], maxCount: Int) -> [JournalEntryRecord] {
        guard entries.count > maxCount else { return entries }
        let stride = Double(entries.count) / Double(maxCount)
        return (0..<maxCount).compactMap { i in
            let index = Int(Double(i) * stride)
            return index < entries.count ? entries[index] : nil
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.autoupdatingCurrent
        return formatter
    }()
}
