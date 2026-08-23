//
//  ChatGPTAIProvider.swift
//  Nibora
//

import Foundation

/// Sends the question and journal context to OpenAI's Chat Completions API
/// using the user's own API key — same tradeoff as ClaudeAIProvider:
/// journal excerpts leave this Mac over HTTPS, billed to the user's own
/// OpenAI account per use.
struct ChatGPTAIProvider: JournalAIProvider {
    let apiKey: String

    private static let model = "gpt-4o"
    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func ask(question: String, context: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AIProviderError.missingAPIKey("OpenAI")
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Self.model,
            "messages": [
                ["role": "system", "content": JournalPromptBuilder.instructions(context: context)],
                ["role": "user", "content": question]
            ]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let httpResponse = response as? HTTPURLResponse else { throw AIProviderError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (json?["error"] as? [String: Any])?["message"] as? String ?? "ChatGPT API error (\(httpResponse.statusCode))."
            throw AIProviderError.apiError(message)
        }
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw AIProviderError.invalidResponse
        }
        return text
    }
}
