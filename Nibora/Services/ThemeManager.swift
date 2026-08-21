//
//  ThemeManager.swift
//  Nibora
//

import SwiftUI
import AppKit

/// User-customizable text colors: one for body text, one per markdown
/// heading level (# through ######), and one each for bold/italic spans.
/// Purely a display concern — the saved markdown file never encodes color,
/// only the on-screen rendering does.
@Observable
final class ThemeManager {
    var bodyColor: Color { didSet { persist(bodyColor, forKey: Keys.body) } }
    var h1Color: Color { didSet { persist(h1Color, forKey: Keys.h1) } }
    var h2Color: Color { didSet { persist(h2Color, forKey: Keys.h2) } }
    var h3Color: Color { didSet { persist(h3Color, forKey: Keys.h3) } }
    var h4Color: Color { didSet { persist(h4Color, forKey: Keys.h4) } }
    var h5Color: Color { didSet { persist(h5Color, forKey: Keys.h5) } }
    var h6Color: Color { didSet { persist(h6Color, forKey: Keys.h6) } }
    var boldColor: Color { didSet { persist(boldColor, forKey: Keys.bold) } }
    var italicColor: Color { didSet { persist(italicColor, forKey: Keys.italic) } }
    var linkColor: Color { didSet { persist(linkColor, forKey: Keys.link) } }

    private enum Keys {
        static let body = "theme.bodyColor"
        static let h1 = "theme.h1Color"
        static let h2 = "theme.h2Color"
        static let h3 = "theme.h3Color"
        static let h4 = "theme.h4Color"
        static let h5 = "theme.h5Color"
        static let h6 = "theme.h6Color"
        static let bold = "theme.boldColor"
        static let italic = "theme.italicColor"
        static let link = "theme.linkColor"
    }

    private static let defaultBody = Color.primary
    private static let defaultH1 = Color(red: 0.85, green: 0.32, blue: 0.30)
    private static let defaultH2 = Color(red: 0.85, green: 0.52, blue: 0.20)
    private static let defaultH3 = Color(red: 0.80, green: 0.68, blue: 0.15)
    private static let defaultH4 = Color(red: 0.32, green: 0.62, blue: 0.42)
    private static let defaultH5 = Color(red: 0.28, green: 0.52, blue: 0.78)
    private static let defaultH6 = Color(red: 0.52, green: 0.42, blue: 0.78)
    private static let defaultBold = Color.primary
    private static let defaultItalic = Color.primary
    private static let defaultLink = Color(red: 0.20, green: 0.47, blue: 0.85)

    init() {
        bodyColor = Self.load(Keys.body) ?? Self.defaultBody
        h1Color = Self.load(Keys.h1) ?? Self.defaultH1
        h2Color = Self.load(Keys.h2) ?? Self.defaultH2
        h3Color = Self.load(Keys.h3) ?? Self.defaultH3
        h4Color = Self.load(Keys.h4) ?? Self.defaultH4
        h5Color = Self.load(Keys.h5) ?? Self.defaultH5
        h6Color = Self.load(Keys.h6) ?? Self.defaultH6
        boldColor = Self.load(Keys.bold) ?? Self.defaultBold
        italicColor = Self.load(Keys.italic) ?? Self.defaultItalic
        linkColor = Self.load(Keys.link) ?? Self.defaultLink
    }

    func color(forHeadingLevel level: Int) -> Color {
        switch level {
        case 1: return h1Color
        case 2: return h2Color
        case 3: return h3Color
        case 4: return h4Color
        case 5: return h5Color
        default: return h6Color
        }
    }

    func resetToDefaults() {
        bodyColor = Self.defaultBody
        h1Color = Self.defaultH1
        h2Color = Self.defaultH2
        h3Color = Self.defaultH3
        h4Color = Self.defaultH4
        h5Color = Self.defaultH5
        h6Color = Self.defaultH6
        boldColor = Self.defaultBold
        italicColor = Self.defaultItalic
        linkColor = Self.defaultLink
    }

    private static func load(_ key: String) -> Color? {
        guard let hex = UserDefaults.standard.string(forKey: key) else { return nil }
        return Color(hexString: hex)
    }

    private func persist(_ color: Color, forKey key: String) {
        UserDefaults.standard.set(color.hexString, forKey: key)
    }
}

extension Color {
    init?(hexString: String) {
        guard let nsColor = NSColor(hexString: hexString) else { return nil }
        self = Color(nsColor)
    }

    var hexString: String {
        NSColor(self).hexString
    }
}

extension NSColor {
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
