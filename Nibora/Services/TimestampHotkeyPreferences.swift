//
//  TimestampHotkeyPreferences.swift
//  Nibora
//

import Foundation
import AppKit

/// A single user-configurable keyboard shortcut that inserts a "HHmm - "
/// timestamp at the cursor in the entry editor. Persisted as a raw key code
/// + modifier mask rather than anything higher-level, since that's all a
/// local NSEvent monitor needs to match against.
@Observable
final class TimestampHotkeyPreferences: HotkeyPreferences {
    var keyCode: UInt16? {
        didSet { persist() }
    }
    var modifierFlags: NSEvent.ModifierFlags {
        didSet { persist() }
    }

    private enum Keys {
        static let keyCode = "timestampHotkey.keyCode"
        static let modifiers = "timestampHotkey.modifiers"
        static let hasStoredValue = "timestampHotkey.hasStoredValue"
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Keys.hasStoredValue) {
            let storedKeyCode = defaults.integer(forKey: Keys.keyCode)
            keyCode = storedKeyCode >= 0 ? UInt16(storedKeyCode) : nil
            modifierFlags = NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: Keys.modifiers)))
        } else {
            // Default: Cmd+Shift+T
            keyCode = 17
            modifierFlags = [.command, .shift]
        }
    }

    func setShortcut(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags.intersection(.deviceIndependentFlagsMask)
    }

    func clearShortcut() {
        keyCode = nil
    }

    func matches(_ event: NSEvent) -> Bool {
        KeyboardShortcutValue(keyCode: keyCode, modifierFlags: modifierFlags).matches(event)
    }

    var displayString: String {
        KeyboardShortcutValue(keyCode: keyCode, modifierFlags: modifierFlags).displayString
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Keys.hasStoredValue)
        let keyCodeValue: Int = keyCode.map { Int($0) } ?? -1
        defaults.set(keyCodeValue, forKey: Keys.keyCode)
        defaults.set(Int(modifierFlags.rawValue), forKey: Keys.modifiers)
    }
}
