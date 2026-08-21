//
//  EntryTemplatePreferences.swift
//  Nibora
//

import Foundation

/// Optional skeleton body text applied to every new entry when it's
/// created. Disabled by default (isEnabled: false) — a fresh vault starts
/// blank, matching the app's existing behavior.
@Observable
final class EntryTemplatePreferences {
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }
    var templateText: String {
        didSet { UserDefaults.standard.set(templateText, forKey: Keys.templateText) }
    }

    private enum Keys {
        static let isEnabled = "entryTemplatePreferences.isEnabled"
        static let templateText = "entryTemplatePreferences.templateText"
    }

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.isEnabled)
        templateText = UserDefaults.standard.string(forKey: Keys.templateText) ?? ""
    }

    /// Substitutes "{{weekday}}" in a template with the full weekday name
    /// (e.g. "Monday") for the given date. Applied at entry-creation time,
    /// not stored literally — the placeholder itself lives only in the
    /// template text in Settings.
    static func rendering(_ template: String, for date: Date) -> String {
        template.replacingOccurrences(of: "{{weekday}}", with: weekdayFormatter.string(from: date))
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
