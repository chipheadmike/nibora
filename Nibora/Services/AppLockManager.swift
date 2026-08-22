//
//  AppLockManager.swift
//  Nibora
//

import Foundation
import AppKit

/// Live lock state, driven by app/window lifecycle notifications. Starts
/// locked on launch whenever a password is set — otherwise quitting and
/// reopening the app would trivially bypass the whole feature.
@Observable
final class AppLockManager: NSObject {
    var isLocked: Bool = false

    private let preferences: PasswordLockPreferences
    private var resignedAt: Date?

    init(preferences: PasswordLockPreferences) {
        self.preferences = preferences
        super.init()
        isLocked = preferences.hasPassword
        registerObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var hasRecoveryCode: Bool { preferences.hasRecoveryCode }
    var hasRecoveryEmail: Bool { !preferences.recoveryEmail.trimmingCharacters(in: .whitespaces).isEmpty }
    var recoveryEmail: String { preferences.recoveryEmail }

    func unlock(with password: String) -> Bool {
        guard preferences.verifyPassword(password) else { return false }
        isLocked = false
        return true
    }

    func verifyRecoveryCode(_ code: String) -> Bool {
        preferences.verifyRecoveryCode(code)
    }

    @discardableResult
    func generateTemporaryCode() -> String {
        preferences.generateTemporaryCode()
    }

    func verifyTemporaryCode(_ code: String) -> Bool {
        preferences.verifyTemporaryCode(code)
    }

    /// Finishes a recovery unlock (either the saved recovery code or an
    /// emailed temporary code): the old (forgotten) password is replaced,
    /// whichever code was used is consumed so it can't be reused, and the
    /// app unlocks. Recovery only ever ends here — verifying a code alone
    /// isn't enough, since leaving the old, unremembered password in place
    /// would just recreate the same lockout next time. Only the code that
    /// was actually used gets cleared — recovering via email doesn't burn
    /// a separately-saved recovery code, and vice versa.
    func completeRecovery(newPassword: String, usingTemporaryCode: Bool) {
        preferences.setPassword(newPassword)
        if usingTemporaryCode {
            preferences.clearTemporaryCode()
        } else {
            preferences.clearRecoveryCode()
        }
        isLocked = false
    }

    private func registerObservers() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleResignActive), name: NSApplication.didResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(handleBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(handleMiniaturize), name: NSWindow.didMiniaturizeNotification, object: nil)
    }

    /// Records when the app left the foreground, so becomeActive can check
    /// how long it's been away against the idle-lock threshold.
    @objc private func handleResignActive() {
        guard preferences.hasPassword else { return }
        resignedAt = Date()
    }

    @objc private func handleBecomeActive() {
        guard preferences.hasPassword, let resignedAt else { return }
        let elapsedMinutes = Date().timeIntervalSince(resignedAt) / 60
        if elapsedMinutes >= Double(preferences.lockAfterMinutes) {
            isLocked = true
        }
        self.resignedAt = nil
    }

    /// Minimizing doesn't resign app-active status by itself (the app can
    /// stay frontmost with its only window minimized), so this needs its
    /// own notification distinct from resign/become-active above. Locks
    /// immediately (not on restore) so isLocked is already true if the
    /// user opens Settings — a separate window — while minimized, rather
    /// than only locking once the main window itself is un-minimized.
    @objc private func handleMiniaturize() {
        guard preferences.hasPassword, preferences.lockOnMinimize else { return }
        isLocked = true
    }
}
