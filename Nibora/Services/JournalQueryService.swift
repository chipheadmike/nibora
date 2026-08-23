//
//  JournalQueryService.swift
//  Nibora
//

import Foundation

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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
