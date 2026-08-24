//
//  EntryTemplatePreferences.swift
//  Nibora
//

import Foundation

struct EntryTemplate: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var text: String
}

/// Named skeleton bodies you can pick from when creating a new entry
/// (daily, travel, gratitude, etc.), instead of a single fixed template.
/// Disabled by default — a fresh vault starts blank, matching the app's
/// original behavior. With exactly one template, "New Entry" applies it
/// automatically with no extra step; with more than one, it becomes a menu.
@Observable
final class EntryTemplatePreferences {
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }

    var templates: [EntryTemplate] = [] {
        didSet {
            guard let data = try? JSONEncoder().encode(templates) else { return }
            UserDefaults.standard.set(data, forKey: Keys.templates)
        }
    }

    var defaultTemplateID: UUID? {
        didSet { UserDefaults.standard.set(defaultTemplateID?.uuidString, forKey: Keys.defaultTemplateID) }
    }

    private enum Keys {
        static let isEnabled = "entryTemplatePreferences.isEnabled"
        static let templates = "entryTemplatePreferences.templates"
        static let defaultTemplateID = "entryTemplatePreferences.defaultTemplateID"
        static let legacyTemplateText = "entryTemplatePreferences.templateText"
    }

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.isEnabled)

        if let data = UserDefaults.standard.data(forKey: Keys.templates),
           let decoded = try? JSONDecoder().decode([EntryTemplate].self, from: data) {
            templates = decoded
        }

        // One-time upgrade from the old single-template storage.
        if templates.isEmpty,
           let legacyText = UserDefaults.standard.string(forKey: Keys.legacyTemplateText),
           !legacyText.isEmpty {
            templates = [EntryTemplate(id: UUID(), name: "Default", text: legacyText)]
            UserDefaults.standard.removeObject(forKey: Keys.legacyTemplateText)
        }

        if let idString = UserDefaults.standard.string(forKey: Keys.defaultTemplateID), let id = UUID(uuidString: idString) {
            defaultTemplateID = id
        }
        if defaultTemplateID == nil || !templates.contains(where: { $0.id == defaultTemplateID }) {
            defaultTemplateID = templates.first?.id
        }
    }

    /// Used by contexts that can't offer a picker (Quick Capture, Siri) —
    /// falls back to the first template if the stored default was removed.
    var defaultTemplate: EntryTemplate? {
        templates.first { $0.id == defaultTemplateID } ?? templates.first
    }

    func addTemplate() {
        let template = EntryTemplate(id: UUID(), name: "New Template", text: "")
        templates.append(template)
        if defaultTemplateID == nil {
            defaultTemplateID = template.id
        }
    }

    func removeTemplate(_ template: EntryTemplate) {
        templates.removeAll { $0.id == template.id }
        if defaultTemplateID == template.id {
            defaultTemplateID = templates.first?.id
        }
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
