//
//  AIProviderPreferences.swift
//  Nibora
//

import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case onDevice
    case claude
    case chatGPT

    var id: String { rawValue }

    var label: String {
        switch self {
        case .onDevice: return "On-Device (Apple Intelligence)"
        case .claude: return "Claude (Anthropic)"
        case .chatGPT: return "ChatGPT (OpenAI)"
        }
    }
}

/// Which AI backend Ask Nibora uses, plus the user's own API keys for the
/// cloud options — stored in Keychain, same as the password hash, never in
/// UserDefaults. Only On-Device is free and fully local; Claude and
/// ChatGPT send journal excerpts to that provider's servers and bill the
/// user's own account per use.
@Observable
final class AIProviderPreferences {
    var selectedProvider: AIProvider {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: Keys.selectedProvider) }
    }
    var claudeAPIKey: String {
        didSet { persist(claudeAPIKey, account: KeychainAccount.claudeKey) }
    }
    var openAIAPIKey: String {
        didSet { persist(openAIAPIKey, account: KeychainAccount.openAIKey) }
    }

    private enum Keys {
        static let selectedProvider = "aiProviderPreferences.selectedProvider"
    }
    private enum KeychainAccount {
        static let claudeKey = "aiClaudeAPIKey"
        static let openAIKey = "aiOpenAIAPIKey"
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.selectedProvider), let provider = AIProvider(rawValue: raw) {
            selectedProvider = provider
        } else {
            selectedProvider = .onDevice
        }
        claudeAPIKey = KeychainHelper.load(account: KeychainAccount.claudeKey).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        openAIAPIKey = KeychainHelper.load(account: KeychainAccount.openAIKey).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private func persist(_ key: String, account: String) {
        if key.isEmpty {
            KeychainHelper.delete(account: account)
        } else {
            KeychainHelper.save(Data(key.utf8), account: account)
        }
    }
}
