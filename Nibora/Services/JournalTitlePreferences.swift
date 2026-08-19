//
//  JournalTitlePreferences.swift
//  Nibora
//

import Foundation

/// User-configurable title shown in the window's title bar (e.g. "Mike's
/// Journal"). Empty means no custom title — the title bar stays hidden,
/// matching the app's default look.
@Observable
final class JournalTitlePreferences {
    var title: String {
        didSet { UserDefaults.standard.set(title, forKey: Keys.title) }
    }

    private enum Keys {
        static let title = "journalTitlePreferences.title"
    }

    init() {
        title = UserDefaults.standard.string(forKey: Keys.title) ?? ""
    }
}
