//
//  ClaudeAIProvider.swift
//  Nibora
//

import Foundation

/// Sends the question and journal context to Anthropic's Messages API
/// using the user's own API key — a deliberate, explicit tradeoff versus
/// OnDeviceAIProvider: journal excerpts leave this Mac over HTTPS, billed
/// to the user's own Anthropic account per use.
struct ClaudeAIProvider: JournalAIProvider {
    let apiKey: String

    private static let model = "claude-sonnet-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func ask(question: String, context: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AIProviderError.missingAPIKey("Anthropic")
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Self.model,
            "max_tokens": 1024,
            "system": JournalPromptBuilder.instructions(context: context),
            "messages": [["role": "user", "content": question]]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let httpResponse = response as? HTTPURLResponse else { throw AIProviderError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (json?["error"] as? [String: Any])?["message"] as? String ?? "Claude API error (\(httpResponse.statusCode))."
            throw AIProviderError.apiError(message)
        }
        guard let content = json?["content"] as? [[String: Any]], let text = content.first?["text"] as? String else {
            throw AIProviderError.invalidResponse
        }
        return text
    }
}
