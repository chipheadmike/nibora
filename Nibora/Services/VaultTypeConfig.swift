//
//  VaultTypeConfig.swift
//  Nibora
//

import Foundation

enum VaultType: String, Codable {
    /// One page per day, filenames driven by date, month-grouped sidebar —
    /// everything Nibora has always done.
    case journal
    /// Unlimited entries with user-chosen titles, organized into
    /// user-created folders — no daily-cadence assumptions.
    case freeform
}

/// A vault's type lives inside the vault folder itself, not UserDefaults —
/// it's a property of the vault's data, so it needs to travel with the
/// folder (another Mac, re-adding it after removing it from the recent
/// list), unlike VaultInfo's per-machine bookmark cache.
enum VaultTypeConfig {
    private struct Contents: Codable {
        var type: VaultType
    }

    private static func configURL(for vaultURL: URL) -> URL {
        vaultURL.appendingPathComponent(".nibora", isDirectory: true).appendingPathComponent("vault.json")
    }

    /// Defaults — and heals, by writing the file — to .journal. Every vault
    /// that predates this feature has no vault.json and should keep
    /// behaving exactly as it always has, transparently.
    @discardableResult
    static func read(from vaultURL: URL) -> VaultType {
        let url = configURL(for: vaultURL)
        if let data = try? Data(contentsOf: url),
           let contents = try? JSONDecoder().decode(Contents.self, from: data) {
            return contents.type
        }
        write(.journal, to: vaultURL)
        return .journal
    }

    static func write(_ type: VaultType, to vaultURL: URL) {
        let url = configURL(for: vaultURL)
        guard let data = try? JSONEncoder().encode(Contents(type: type)) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }

    /// True only for a folder that isn't already a vault and has nothing in
    /// it yet — decides whether to ask Journal-vs-Freeform at all, since an
    /// already-populated vault's type is fixed (silently .journal if it
    /// predates this feature).
    static func isFreshFolder(_ vaultURL: URL) -> Bool {
        guard !FileManager.default.fileExists(atPath: configURL(for: vaultURL).path) else { return false }
        guard let contents = try? FileManager.default.contentsOfDirectory(at: vaultURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return true
        }
        return contents.isEmpty
    }
}
