//
//  SentimentAnalyzer.swift
//  Nibora
//

import Foundation
import NaturalLanguage

/// Wraps NLTagger's on-device sentiment analysis — no network call, no
/// third-party service, entirely local like everything else in this app.
/// Scores range from -1 (negative) to 1 (positive); 0 for empty text or
/// text NLTagger can't score.
enum SentimentAnalyzer {
    static func score(for text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = trimmed

        var scores: [Double] = []
        tagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .paragraph, scheme: .sentimentScore, options: []) { tag, _ in
            if let tag, let value = Double(tag.rawValue) {
                scores.append(value)
            }
            return true
        }

        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
}
