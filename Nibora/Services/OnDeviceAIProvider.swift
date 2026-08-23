//
//  OnDeviceAIProvider.swift
//  Nibora
//

import Foundation
import FoundationModels

/// Wraps Apple's on-device Foundation Models framework — no network, fully
/// local, free. Includes a guardrail-violation fallback: the on-device
/// model's safety filter has been observed tripping on entirely ordinary
/// journal content in this beta, so a violation triggers one retry with no
/// journal context at all rather than a dead end.
struct OnDeviceAIProvider: JournalAIProvider {
    static func checkAvailability() -> String? {
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

    func ask(question: String, context: String) async throws -> String {
        let instructions = JournalPromptBuilder.instructions(context: context)
        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: question)
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error {
                let bareSession = LanguageModelSession()
                if let bareResponse = try? await bareSession.respond(to: question) {
                    return bareResponse.content + "\n\n(Answered without journal context — including your journal excerpts triggered the on-device model's safety filter this time.)"
                }
            }
            throw error
        }
    }
}
