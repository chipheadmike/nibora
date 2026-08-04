//
//  EntrySortPreferences.swift
//  Nibora
//

import Foundation

enum EntrySortMode: String, CaseIterable, Identifiable {
    case manual
    case createdDate
    case modifiedDate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: return "Manual"
        case .createdDate: return "Creation Date"
        case .modifiedDate: return "Modified Date"
        }
    }
}

/// Persists how entries are ordered within a month section. "Manual" uses
/// the drag/Move Up/Down-assigned sortOrder; the date modes ignore it and
/// sort live off the frontmatter timestamps instead.
@Observable
final class EntrySortPreferences {
    var mode: EntrySortMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Keys.mode) }
    }

    private enum Keys {
        static let mode = "sortPreferences.mode"
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.mode), let loaded = EntrySortMode(rawValue: raw) {
            mode = loaded
        } else {
            mode = .manual
        }
    }
}
