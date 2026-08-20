//
//  PasswordLockPreferences.swift
//  Nibora
//

import Foundation
import CryptoKit
import Security

/// Password-lock configuration: the password itself is never stored in
/// plain text (UserDefaults or otherwise) — only a salted SHA-256 hash,
/// kept in Keychain. This is a privacy screen for the app's UI, not
/// encryption; entries on disk remain plain text regardless.
@Observable
final class PasswordLockPreferences {
    var lockAfterMinutes: Int {
        didSet { UserDefaults.standard.set(lockAfterMinutes, forKey: Keys.lockAfterMinutes) }
    }
    var lockOnMinimize: Bool {
        didSet { UserDefaults.standard.set(lockOnMinimize, forKey: Keys.lockOnMinimize) }
    }
    private(set) var hasPassword: Bool

    static let minutesRange = 1...60
    static let defaultLockAfterMinutes = 5

    private enum Keys {
        static let lockAfterMinutes = "passwordLock.lockAfterMinutes"
        static let lockOnMinimize = "passwordLock.lockOnMinimize"
    }

    private enum KeychainAccount {
        static let hash = "passwordHash"
        static let salt = "passwordSalt"
    }

    init() {
        let storedMinutes = UserDefaults.standard.integer(forKey: Keys.lockAfterMinutes)
        lockAfterMinutes = storedMinutes > 0 ? storedMinutes : Self.defaultLockAfterMinutes
        lockOnMinimize = UserDefaults.standard.object(forKey: Keys.lockOnMinimize) as? Bool ?? true
        hasPassword = KeychainHelper.load(account: KeychainAccount.hash) != nil
    }

    func setPassword(_ password: String) {
        let salt = Self.randomSalt()
        let hash = Self.hash(password: password, salt: salt)
        KeychainHelper.save(salt, account: KeychainAccount.salt)
        KeychainHelper.save(hash, account: KeychainAccount.hash)
        hasPassword = true
    }

    func verifyPassword(_ password: String) -> Bool {
        guard let salt = KeychainHelper.load(account: KeychainAccount.salt),
              let storedHash = KeychainHelper.load(account: KeychainAccount.hash) else {
            return false
        }
        return Self.hash(password: password, salt: salt) == storedHash
    }

    func clearPassword() {
        KeychainHelper.delete(account: KeychainAccount.hash)
        KeychainHelper.delete(account: KeychainAccount.salt)
        hasPassword = false
    }

    private static func hash(password: String, salt: Data) -> Data {
        var combined = Data(password.utf8)
        combined.append(salt)
        return Data(SHA256.hash(data: combined))
    }

    private static func randomSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}
