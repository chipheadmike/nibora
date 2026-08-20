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

    func unlock(with password: String) -> Bool {
        guard preferences.verifyPassword(password) else { return false }
        isLocked = false
        return true
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
