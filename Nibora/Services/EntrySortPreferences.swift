//
//  EntrySortPreferences.swift
//  Nibora
//

import Foundation

enum EntrySortMode: String, CaseIterable, Identifiable {
    case manual
    case entryDate
    case createdDate
    case modifiedDate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: return "Manual"
        case .entryDate: return "Entry Date"
        case .createdDate: return "Creation Date"
        case .modifiedDate: return "Modified Date"
        }
    }
}

/// Only meaningful for the date-based sort modes — "Manual" order is
/// already exactly what the user arranged via drag/Move Up/Down, so a
/// separate direction doesn't apply to it.
enum EntrySortDirection: String, CaseIterable, Identifiable {
    case ascending
    case descending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ascending: return "Oldest First"
        case .descending: return "Newest First"
        }
    }

    var sortOrder: SortOrder {
        switch self {
        case .ascending: return .forward
        case .descending: return .reverse
        }
    }
}

/// Persists how entries are ordered within a month section. "Manual" uses
/// the drag/Move Up/Down-assigned sortOrder; the date modes ignore it and
/// sort live off the frontmatter timestamps instead, in the direction set
/// by `direction`.
@Observable
final class EntrySortPreferences {
    var mode: EntrySortMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Keys.mode) }
    }
    var direction: EntrySortDirection {
        didSet { UserDefaults.standard.set(direction.rawValue, forKey: Keys.direction) }
    }

    private enum Keys {
        static let mode = "sortPreferences.mode"
        static let direction = "sortPreferences.direction"
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.mode), let loaded = EntrySortMode(rawValue: raw) {
            mode = loaded
        } else {
            mode = .entryDate
        }
        if let raw = UserDefaults.standard.string(forKey: Keys.direction), let loaded = EntrySortDirection(rawValue: raw) {
            direction = loaded
        } else {
            direction = .descending
        }
    }
}
