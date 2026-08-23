//
//  JournalAIProvider.swift
//  Nibora
//

import Foundation

/// Common interface so JournalQueryService can route a question to
/// whichever backend the user has selected (on-device, Claude, or
/// ChatGPT) without branching on provider type anywhere else.
protocol JournalAIProvider {
    func ask(question: String, context: String) async throws -> String
}

enum AIProviderError: LocalizedError {
    case missingAPIKey(String)
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider): return "No \(provider) API key set. Add one in Settings > AI."
        case .invalidResponse: return "Received an unexpected response."
        case .apiError(let message): return message
        }
    }
}

/// Builds the shared instructions every provider uses, so the three
/// backends can't drift into answering differently just because their
/// prompt wording differs.
enum JournalPromptBuilder {
    static func instructions(context: String) -> String {
        """
        You answer questions about the user's personal journal using ONLY the journal excerpts provided below. \
        If the excerpts don't contain the answer, say you don't see anything about that in the journal — never make something up.

        Journal excerpts:
        \(context)
        """
    }
}
