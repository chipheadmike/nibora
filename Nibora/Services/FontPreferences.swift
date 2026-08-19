//
//  FontPreferences.swift
//  Nibora
//

import Foundation
import AppKit

/// User-configurable editor font family + size. `systemMonospacedSentinel`
/// represents the default (NSFont.monospacedSystemFont), distinct from any
/// real installed font family name.
@Observable
final class FontPreferences {
    var fontName: String { didSet { persist() } }
    var fontSize: Double { didSet { persist() } }

    static let systemMonospacedSentinel = "System Monospaced"
    static let defaultFontSize: Double = 13
    static let sizeRange: ClosedRange<Double> = 9...28

    private enum Keys {
        static let fontName = "fontPreferences.fontName"
        static let fontSize = "fontPreferences.fontSize"
    }

    init() {
        fontName = UserDefaults.standard.string(forKey: Keys.fontName) ?? Self.systemMonospacedSentinel
        let storedSize = UserDefaults.standard.double(forKey: Keys.fontSize)
        fontSize = storedSize > 0 ? storedSize : Self.defaultFontSize
    }

    func resetToDefaults() {
        fontName = Self.systemMonospacedSentinel
        fontSize = Self.defaultFontSize
    }

    private func persist() {
        UserDefaults.standard.set(fontName, forKey: Keys.fontName)
        UserDefaults.standard.set(fontSize, forKey: Keys.fontSize)
    }
}
