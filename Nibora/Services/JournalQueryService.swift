//
//  JournalQueryService.swift
//  Nibora
//

import Foundation
import FoundationModels

/// Answers questions about the user's own journal using Apple's on-device
/// Foundation Models framework — no network call, no subscription, nothing
/// leaves the machine. Only works when Apple Intelligence is enabled and
/// available on this Mac; checkAvailability() surfaces why when it isn't.
@Observable
final class JournalQueryService {
    func checkAvailability() -> String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This Mac doesn't support on-device Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in System Settings > Apple Intelligence & Siri to use this."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading or preparing — try again shortly."
        case .unavailable:
            return "On-device AI isn't available right now."
        }
    }

    /// Feeds the model a small, keyword-relevant slice of the journal
    /// rather than everything — the on-device model's context window is
    /// limited, and this is a much closer approximation of "search my
    /// journal" than either dumping the whole vault in or only looking at
    /// recent entries. Kept deliberately small (5 excerpts, 400 chars each)
    /// since a smaller payload is also somewhat less likely to trip the
    /// model's on-device safety guardrail, which has been observed
    /// triggering on entirely ordinary journal content in this beta.
    func ask(_ question: String, entries: [JournalEntryRecord]) async throws -> String {
        let relevant = Self.relevantEntries(for: question, in: entries, limit: 5)
        let context = relevant.map { entry in
            "[\(Self.dateFormatter.string(from: entry.date))] \(entry.title): \(entry.searchableBody.prefix(400))"
        }.joined(separator: "\n\n")

        let instructions = """
        You answer questions about the user's personal journal using ONLY the journal excerpts provided below. \
        If the excerpts don't contain the answer, say you don't see anything about that in the journal — never make something up.

        Journal excerpts:
        \(context)
        """

        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: question)
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error {
                // The guardrail can trip on the injected journal content
                // rather than the question itself — retry once with no
                // journal context at all, so a genuinely ordinary question
                // still gets some answer instead of a dead end.
                let bareSession = LanguageModelSession()
                if let bareResponse = try? await bareSession.respond(to: question) {
                    return bareResponse.content + "\n\n(Answered without journal context — including your journal excerpts triggered the on-device model's safety filter this time.)"
                }
            }
            throw error
        }
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
