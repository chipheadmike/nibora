//
//  ColorLegibility.swift
//  Nibora
//

import AppKit
import SwiftUI

extension NSColor {
    /// Nudges brightness (hue/saturation untouched) so a color stays
    /// legible against NSTextView's default background for the given
    /// color scheme — near-white in light mode, near-black/dark-gray in
    /// dark mode. Resolves any dynamic input color (e.g. from Color.primary)
    /// under the SAME scheme being adjusted for, via
    /// performAsCurrentDrawingAppearance, rather than trusting whatever
    /// appearance happens to be ambient when this runs outside a live draw.
    func legibilityAdjusted(for colorScheme: ColorScheme) -> NSColor {
        let appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0

        let resolve = {
            if let rgb = self.usingColorSpace(.deviceRGB) {
                rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            }
        }
        if let appearance {
            appearance.performAsCurrentDrawingAppearance(resolve)
        } else {
            resolve()
        }

        switch colorScheme {
        case .dark:
            brightness = max(brightness, 0.45)
        default:
            brightness = min(brightness, 0.75)
        }
        return NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
}

/// A snapshot of ThemeManager's colors, each nudged for legibility via
/// NSColor.legibilityAdjusted above — computed once per styling/render pass
/// and handed to every apply*/rendering helper, so none of them need to
/// know about color scheme resolution themselves. ThemeManager stays the
/// single source of truth (and the only thing Settings' pickers touch);
/// this is purely a derived, throwaway view onto it.
struct ResolvedTheme {
    let bodyColor: Color
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
    private let headingColors: [Color]

    init(_ theme: ThemeManager, for colorScheme: ColorScheme) {
        func adjusted(_ color: Color) -> Color {
            Color(NSColor(color).legibilityAdjusted(for: colorScheme))
        }
        bodyColor = adjusted(theme.bodyColor)
        boldColor = adjusted(theme.boldColor)
        italicColor = adjusted(theme.italicColor)
        linkColor = adjusted(theme.linkColor)
        codeColor = adjusted(theme.codeColor)
        strikethroughColor = adjusted(theme.strikethroughColor)
        highlightColor = adjusted(theme.highlightColor)
        blockquoteColor = adjusted(theme.blockquoteColor)
        horizontalRuleColor = adjusted(theme.horizontalRuleColor)
        tagColor = adjusted(theme.tagColor)
        wikilinkColor = adjusted(theme.wikilinkColor)
        headingColors = [
            adjusted(theme.h1Color), adjusted(theme.h2Color), adjusted(theme.h3Color),
            adjusted(theme.h4Color), adjusted(theme.h5Color), adjusted(theme.h6Color)
        ]
    }

    func color(forHeadingLevel level: Int) -> Color {
        let index = min(max(level - 1, 0), headingColors.count - 1)
        return headingColors[index]
    }
}
