//
//  AppAppearancePreferences.swift
//  Nibora
//

import SwiftUI

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// App-wide Light/Dark/System override — applied via .preferredColorScheme
/// on both the main window and Settings, so native chrome follows this
/// choice rather than only ever the system setting. Independent of
/// ThemeManager's per-element colors, which react to whatever ColorScheme
/// ends up active (system or this override) via ResolvedTheme.
@Observable
final class AppAppearancePreferences {
    var mode: AppAppearanceMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Keys.mode) }
    }

    private enum Keys {
        static let mode = "appAppearancePreferences.mode"
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.mode), let loaded = AppAppearanceMode(rawValue: raw) {
            mode = loaded
        } else {
            mode = .system
        }
    }
}
