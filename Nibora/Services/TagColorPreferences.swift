//
//  TagColorPreferences.swift
//  Nibora
//

import SwiftUI

/// Optional per-tag color overrides, keyed by lowercased tag name — layered
/// on top of ThemeManager's single uniform tagColor (see
/// ResolvedTheme.color(forTag:)), not a replacement for it. A tag with no
/// entry here just uses the uniform color, same as before this existed.
@Observable
final class TagColorPreferences {
    private(set) var assignments: [String: String] = [:]

    private let key = "tagColorPreferences.assignments"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            assignments = decoded
        }
    }

    func color(for tag: String) -> Color? {
        assignments[tag.lowercased()].flatMap { Color(hexString: $0) }
    }

    func setColor(_ color: Color?, for tag: String) {
        let key = tag.lowercased()
        if let color {
            assignments[key] = color.hexString
        } else {
            assignments.removeValue(forKey: key)
        }
        persist()
    }

    /// Keeps a custom color attached to its tag through TagManagementService's
    /// rename/merge, rather than silently orphaning it under the old name.
    /// A merge (renaming into an existing tag) just keeps that tag's own
    /// color, discarding the one that was being merged away.
    func handleRename(from oldTag: String, to newTag: String) {
        guard let hex = assignments.removeValue(forKey: oldTag.lowercased()) else { return }
        if assignments[newTag.lowercased()] == nil {
            assignments[newTag.lowercased()] = hex
        }
        persist()
    }

    func handleDelete(_ tag: String) {
        guard assignments.removeValue(forKey: tag.lowercased()) != nil else { return }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(assignments) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
