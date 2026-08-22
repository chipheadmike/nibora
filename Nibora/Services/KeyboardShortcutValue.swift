//
//  KeyboardShortcutValue.swift
//  Nibora
//

import AppKit

/// A single user-configurable keyboard shortcut, stored as a raw key code +
/// modifier mask — all a local NSEvent monitor needs to match against —
/// plus the shared matching/display logic, factored out so any future
/// recordable-shortcut preference can reuse it via HotkeyPreferences below
/// instead of duplicating this lookup table and formatting logic.
struct KeyboardShortcutValue: Equatable {
    var keyCode: UInt16?
    var modifierFlags: NSEvent.ModifierFlags

    func matches(_ event: NSEvent) -> Bool {
        guard let keyCode else { return false }
        let relevantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == keyCode && relevantFlags == modifierFlags
    }

    var displayString: String {
        guard let keyCode else { return "None" }
        var display = ""
        if modifierFlags.contains(.control) { display += "⌃" }
        if modifierFlags.contains(.option) { display += "⌥" }
        if modifierFlags.contains(.shift) { display += "⇧" }
        if modifierFlags.contains(.command) { display += "⌘" }
        display += Self.keyCodeToString(keyCode)
        return display
    }

    private static let keyCodeNames: [UInt16: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
        34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
        12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
        16: "Y", 6: "Z",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
    ]

    private static func keyCodeToString(_ keyCode: UInt16) -> String {
        keyCodeNames[keyCode] ?? "Key \(keyCode)"
    }
}

/// Conformed to by any preference object that owns exactly one recordable
/// shortcut, so ShortcutRecorderView can work with either without knowing
/// which action the shortcut is for.
protocol HotkeyPreferences: AnyObject, Observable {
    var keyCode: UInt16? { get set }
    var modifierFlags: NSEvent.ModifierFlags { get set }
    var displayString: String { get }
    func setShortcut(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags)
    func clearShortcut()
}
