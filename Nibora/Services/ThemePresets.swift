//
//  ThemePresets.swift
//  Nibora
//

import SwiftUI

/// A full bundle of ThemeManager's ~17 individual colors, so applying a
/// look is one click instead of tuning every picker by hand. Purely a
/// convenience on top of the same colors already exposed individually —
/// applying a preset just sets each of ThemeManager's existing properties,
/// so fine-tuning afterward with the regular pickers still works exactly
/// as before.
struct ThemePresetDefinition: Identifiable {
    let id: String
    let name: String
    let bodyColor: Color
    let h1Color: Color
    let h2Color: Color
    let h3Color: Color
    let h4Color: Color
    let h5Color: Color
    let h6Color: Color
    let boldColor: Color
    let italicColor: Color
    let linkColor: Color
    let codeColor: Color
    let strikethroughColor: Color
    let highlightColor: Color
    let blockquoteColor: Color
    let horizontalRuleColor: Color
    let tagColor: Color
    let wikilinkColor: Color

    /// A handful of representative swatches for the preset's picker
    /// button — not every color, just enough to suggest the palette.
    var previewSwatches: [Color] {
        [h1Color, linkColor, tagColor, highlightColor]
    }
}

enum ThemePresets {
    static let all: [ThemePresetDefinition] = [defaultPreset, sepia, midnight, ocean, forest, highContrast]

    static let defaultPreset = ThemePresetDefinition(
        id: "default", name: "Default",
        bodyColor: .primary,
        h1Color: Color(red: 0.85, green: 0.32, blue: 0.30),
        h2Color: Color(red: 0.85, green: 0.52, blue: 0.20),
        h3Color: Color(red: 0.80, green: 0.68, blue: 0.15),
        h4Color: Color(red: 0.32, green: 0.62, blue: 0.42),
        h5Color: Color(red: 0.28, green: 0.52, blue: 0.78),
        h6Color: Color(red: 0.52, green: 0.42, blue: 0.78),
        boldColor: .primary,
        italicColor: .primary,
        linkColor: Color(red: 0.20, green: 0.47, blue: 0.85),
        codeColor: Color(red: 0.75, green: 0.30, blue: 0.55),
        strikethroughColor: Color(red: 0.55, green: 0.55, blue: 0.55),
        highlightColor: Color(red: 0.85, green: 0.70, blue: 0.25),
        blockquoteColor: Color(red: 0.45, green: 0.50, blue: 0.58),
        horizontalRuleColor: Color(red: 0.55, green: 0.55, blue: 0.55),
        tagColor: Color(red: 0.30, green: 0.62, blue: 0.55),
        wikilinkColor: Color(red: 0.58, green: 0.40, blue: 0.80)
    )

    static let sepia = ThemePresetDefinition(
        id: "sepia", name: "Sepia",
        bodyColor: Color(red: 0.30, green: 0.22, blue: 0.14),
        h1Color: Color(red: 0.60, green: 0.20, blue: 0.12),
        h2Color: Color(red: 0.70, green: 0.38, blue: 0.10),
        h3Color: Color(red: 0.62, green: 0.48, blue: 0.10),
        h4Color: Color(red: 0.42, green: 0.32, blue: 0.14),
        h5Color: Color(red: 0.35, green: 0.28, blue: 0.20),
        h6Color: Color(red: 0.50, green: 0.35, blue: 0.20),
        boldColor: Color(red: 0.25, green: 0.16, blue: 0.08),
        italicColor: Color(red: 0.40, green: 0.30, blue: 0.18),
        linkColor: Color(red: 0.65, green: 0.35, blue: 0.10),
        codeColor: Color(red: 0.55, green: 0.25, blue: 0.30),
        strikethroughColor: Color(red: 0.55, green: 0.45, blue: 0.35),
        highlightColor: Color(red: 0.85, green: 0.70, blue: 0.35),
        blockquoteColor: Color(red: 0.50, green: 0.40, blue: 0.30),
        horizontalRuleColor: Color(red: 0.55, green: 0.45, blue: 0.35),
        tagColor: Color(red: 0.45, green: 0.40, blue: 0.15),
        wikilinkColor: Color(red: 0.55, green: 0.30, blue: 0.15)
    )

    static let midnight = ThemePresetDefinition(
        id: "midnight", name: "Midnight",
        bodyColor: Color(red: 0.80, green: 0.82, blue: 0.90),
        h1Color: Color(red: 0.90, green: 0.40, blue: 0.55),
        h2Color: Color(red: 0.85, green: 0.55, blue: 0.35),
        h3Color: Color(red: 0.85, green: 0.80, blue: 0.40),
        h4Color: Color(red: 0.45, green: 0.80, blue: 0.60),
        h5Color: Color(red: 0.45, green: 0.65, blue: 0.95),
        h6Color: Color(red: 0.70, green: 0.55, blue: 0.95),
        boldColor: Color(red: 0.95, green: 0.95, blue: 1.0),
        italicColor: Color(red: 0.75, green: 0.78, blue: 0.90),
        linkColor: Color(red: 0.45, green: 0.65, blue: 0.95),
        codeColor: Color(red: 0.90, green: 0.55, blue: 0.75),
        strikethroughColor: Color(red: 0.55, green: 0.58, blue: 0.65),
        highlightColor: Color(red: 0.95, green: 0.80, blue: 0.35),
        blockquoteColor: Color(red: 0.55, green: 0.60, blue: 0.75),
        horizontalRuleColor: Color(red: 0.45, green: 0.48, blue: 0.58),
        tagColor: Color(red: 0.40, green: 0.80, blue: 0.70),
        wikilinkColor: Color(red: 0.70, green: 0.55, blue: 0.95)
    )

    static let ocean = ThemePresetDefinition(
        id: "ocean", name: "Ocean",
        bodyColor: Color(red: 0.10, green: 0.20, blue: 0.25),
        h1Color: Color(red: 0.05, green: 0.35, blue: 0.55),
        h2Color: Color(red: 0.10, green: 0.50, blue: 0.60),
        h3Color: Color(red: 0.15, green: 0.60, blue: 0.55),
        h4Color: Color(red: 0.20, green: 0.55, blue: 0.45),
        h5Color: Color(red: 0.15, green: 0.45, blue: 0.65),
        h6Color: Color(red: 0.30, green: 0.40, blue: 0.65),
        boldColor: Color(red: 0.05, green: 0.20, blue: 0.30),
        italicColor: Color(red: 0.20, green: 0.35, blue: 0.45),
        linkColor: Color(red: 0.10, green: 0.55, blue: 0.75),
        codeColor: Color(red: 0.15, green: 0.45, blue: 0.55),
        strikethroughColor: Color(red: 0.45, green: 0.55, blue: 0.58),
        highlightColor: Color(red: 0.65, green: 0.85, blue: 0.80),
        blockquoteColor: Color(red: 0.30, green: 0.50, blue: 0.55),
        horizontalRuleColor: Color(red: 0.40, green: 0.55, blue: 0.58),
        tagColor: Color(red: 0.10, green: 0.55, blue: 0.50),
        wikilinkColor: Color(red: 0.20, green: 0.40, blue: 0.70)
    )

    static let forest = ThemePresetDefinition(
        id: "forest", name: "Forest",
        bodyColor: Color(red: 0.18, green: 0.22, blue: 0.12),
        h1Color: Color(red: 0.45, green: 0.25, blue: 0.10),
        h2Color: Color(red: 0.55, green: 0.40, blue: 0.10),
        h3Color: Color(red: 0.50, green: 0.48, blue: 0.10),
        h4Color: Color(red: 0.20, green: 0.45, blue: 0.20),
        h5Color: Color(red: 0.15, green: 0.40, blue: 0.30),
        h6Color: Color(red: 0.35, green: 0.35, blue: 0.20),
        boldColor: Color(red: 0.12, green: 0.18, blue: 0.08),
        italicColor: Color(red: 0.25, green: 0.32, blue: 0.18),
        linkColor: Color(red: 0.20, green: 0.50, blue: 0.30),
        codeColor: Color(red: 0.45, green: 0.35, blue: 0.15),
        strikethroughColor: Color(red: 0.45, green: 0.48, blue: 0.38),
        highlightColor: Color(red: 0.75, green: 0.80, blue: 0.40),
        blockquoteColor: Color(red: 0.35, green: 0.42, blue: 0.28),
        horizontalRuleColor: Color(red: 0.42, green: 0.45, blue: 0.35),
        tagColor: Color(red: 0.30, green: 0.50, blue: 0.20),
        wikilinkColor: Color(red: 0.40, green: 0.45, blue: 0.15)
    )

    static let highContrast = ThemePresetDefinition(
        id: "highContrast", name: "High Contrast",
        bodyColor: .black,
        h1Color: Color(red: 0.80, green: 0.0, blue: 0.0),
        h2Color: Color(red: 0.80, green: 0.40, blue: 0.0),
        h3Color: Color(red: 0.55, green: 0.45, blue: 0.0),
        h4Color: Color(red: 0.0, green: 0.45, blue: 0.0),
        h5Color: Color(red: 0.0, green: 0.30, blue: 0.75),
        h6Color: Color(red: 0.45, green: 0.0, blue: 0.65),
        boldColor: .black,
        italicColor: Color(red: 0.20, green: 0.20, blue: 0.20),
        linkColor: Color(red: 0.0, green: 0.30, blue: 0.80),
        codeColor: Color(red: 0.65, green: 0.0, blue: 0.40),
        strikethroughColor: Color(red: 0.40, green: 0.40, blue: 0.40),
        highlightColor: Color(red: 1.0, green: 0.85, blue: 0.0),
        blockquoteColor: Color(red: 0.25, green: 0.25, blue: 0.25),
        horizontalRuleColor: .black,
        tagColor: Color(red: 0.0, green: 0.45, blue: 0.35),
        wikilinkColor: Color(red: 0.45, green: 0.0, blue: 0.65)
    )
}
