//
//  WeatherPreferences.swift
//  Nibora
//

import Foundation

/// Optional — appends the current temperature to the timestamp hotkey's
/// insertion (e.g. "1054 - 74F "). Journal-only, enforced at the call site
/// (EntryEditorView), not here — this class just holds the two settings.
@Observable
final class WeatherPreferences {
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }
    var zipCode: String {
        didSet { UserDefaults.standard.set(zipCode, forKey: Keys.zipCode) }
    }

    private enum Keys {
        static let isEnabled = "weatherPreferences.isEnabled"
        static let zipCode = "weatherPreferences.zipCode"
    }

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.isEnabled)
        zipCode = UserDefaults.standard.string(forKey: Keys.zipCode) ?? ""
    }
}
