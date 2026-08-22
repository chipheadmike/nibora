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
    /// A one-time-use recovery code, shown to the user exactly once at
    /// generation and never stored in retrievable form afterward — only
    /// its salted hash, same as the password itself.
    private(set) var hasRecoveryCode: Bool
    /// Where a temporary access code can optionally be sent — never a
    /// secret itself, just an address, so it's plain UserDefaults like the
    /// rest of this app's non-sensitive settings rather than Keychain.
    var recoveryEmail: String {
        didSet { UserDefaults.standard.set(recoveryEmail, forKey: Keys.recoveryEmail) }
    }

    static let minutesRange = 1...60
    static let defaultLockAfterMinutes = 5
    static let temporaryCodeValidityInterval: TimeInterval = 15 * 60

    private enum Keys {
        static let lockAfterMinutes = "passwordLock.lockAfterMinutes"
        static let lockOnMinimize = "passwordLock.lockOnMinimize"
        static let recoveryEmail = "passwordLock.recoveryEmail"
        static let temporaryCodeExpiry = "passwordLock.temporaryCodeExpiry"
    }

    private enum KeychainAccount {
        static let hash = "passwordHash"
        static let salt = "passwordSalt"
        static let recoveryHash = "recoveryCodeHash"
        static let recoverySalt = "recoveryCodeSalt"
        static let temporaryHash = "temporaryCodeHash"
        static let temporarySalt = "temporaryCodeSalt"
    }

    init() {
        let storedMinutes = UserDefaults.standard.integer(forKey: Keys.lockAfterMinutes)
        lockAfterMinutes = storedMinutes > 0 ? storedMinutes : Self.defaultLockAfterMinutes
        lockOnMinimize = UserDefaults.standard.object(forKey: Keys.lockOnMinimize) as? Bool ?? true
        recoveryEmail = UserDefaults.standard.string(forKey: Keys.recoveryEmail) ?? ""
        hasPassword = KeychainHelper.load(account: KeychainAccount.hash) != nil
        hasRecoveryCode = KeychainHelper.load(account: KeychainAccount.recoveryHash) != nil
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
        clearRecoveryCode()
        clearTemporaryCode()
    }

    /// Generates and stores a fresh recovery code, returning the plaintext
    /// exactly once — only its hash is retained. Overwrites any previous
    /// code (there's only ever one live recovery code at a time).
    @discardableResult
    func generateRecoveryCode() -> String {
        let code = Self.randomRecoveryCode()
        let salt = Self.randomSalt()
        let hash = Self.hash(password: code, salt: salt)
        KeychainHelper.save(salt, account: KeychainAccount.recoverySalt)
        KeychainHelper.save(hash, account: KeychainAccount.recoveryHash)
        hasRecoveryCode = true
        return code
    }

    func verifyRecoveryCode(_ code: String) -> Bool {
        guard let salt = KeychainHelper.load(account: KeychainAccount.recoverySalt),
              let storedHash = KeychainHelper.load(account: KeychainAccount.recoveryHash) else {
            return false
        }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return Self.hash(password: normalized, salt: salt) == storedHash
    }

    /// Recovery codes are single-use: call this once one has been consumed
    /// to unlock, so a stale code can't be reused.
    func clearRecoveryCode() {
        KeychainHelper.delete(account: KeychainAccount.recoveryHash)
        KeychainHelper.delete(account: KeychainAccount.recoverySalt)
        hasRecoveryCode = false
    }

    /// Generates a fresh, time-limited temporary code for the "email me a
    /// code" recovery path — separate storage from the persistent recovery
    /// code so using one never invalidates the other. Deliberately never
    /// exposed anywhere in Nibora's own UI after this call returns (only
    /// the caller, which puts it straight into a Mail.app draft, ever sees
    /// the plaintext) — showing it on-screen at the lock screen would let
    /// anyone with physical access skip needing the actual email at all.
    @discardableResult
    func generateTemporaryCode() -> String {
        let code = Self.randomRecoveryCode()
        let salt = Self.randomSalt()
        let hash = Self.hash(password: code, salt: salt)
        KeychainHelper.save(salt, account: KeychainAccount.temporarySalt)
        KeychainHelper.save(hash, account: KeychainAccount.temporaryHash)
        UserDefaults.standard.set(Date().addingTimeInterval(Self.temporaryCodeValidityInterval), forKey: Keys.temporaryCodeExpiry)
        return code
    }

    func verifyTemporaryCode(_ code: String) -> Bool {
        guard let expiry = UserDefaults.standard.object(forKey: Keys.temporaryCodeExpiry) as? Date, Date() < expiry,
              let salt = KeychainHelper.load(account: KeychainAccount.temporarySalt),
              let storedHash = KeychainHelper.load(account: KeychainAccount.temporaryHash) else {
            return false
        }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return Self.hash(password: normalized, salt: salt) == storedHash
    }

    func clearTemporaryCode() {
        KeychainHelper.delete(account: KeychainAccount.temporaryHash)
        KeychainHelper.delete(account: KeychainAccount.temporarySalt)
        UserDefaults.standard.removeObject(forKey: Keys.temporaryCodeExpiry)
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

    /// Four groups of four characters from an alphabet with visually
    /// ambiguous characters (0/O, 1/I) removed, since this is meant to be
    /// hand-copied or read back by the person who saved it.
    private static func randomRecoveryCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let groups = (0..<4).map { _ in
            String((0..<4).map { _ in alphabet.randomElement()! })
        }
        return groups.joined(separator: "-")
    }
}
