//
//  VaultManager.swift
//  Nibora
//

import Foundation
import AppKit

/// One remembered vault folder — its security-scoped bookmark plus display
/// metadata. Kept Codable so the whole list round-trips through UserDefaults
/// as a single JSON blob; simpler than N separate keys and no different in
/// spirit from the single bookmark this replaced.
struct VaultInfo: Codable, Identifiable, Equatable {
    let id: UUID
    var bookmarkData: Data
    var displayPath: String
    var lastOpenedAt: Date

    var displayName: String {
        (displayPath as NSString).lastPathComponent
    }
}

/// Owns every vault folder the user has ever picked: security-scoped
/// bookmark persistence for each, panel-driven selection, switching between
/// them, and access lifecycle under App Sandbox (only one vault's bookmark
/// is ever "accessing" at a time — switching stops the old one first).
@Observable
final class VaultManager {
    private(set) var vaultURL: URL?
    private(set) var displayPath: String?
    private(set) var recentVaults: [VaultInfo] = []
    private(set) var currentVaultID: UUID?

    private let recentsDefaultsKey = "vaultRecents"
    private let currentVaultIDDefaultsKey = "currentVaultID"
    private let legacyBookmarkDefaultsKey = "vaultBookmarkData"
    private let legacyDisplayPathDefaultsKey = "vaultDisplayPath"

    private var isAccessingSecurityScope = false

    init() {
        loadRecents()
        if recentVaults.isEmpty {
            migrateLegacyVaultIfNeeded()
        }
        resolveCurrentVault()
    }

    deinit {
        if isAccessingSecurityScope {
            vaultURL?.stopAccessingSecurityScopedResource()
        }
    }

    func isCurrent(_ info: VaultInfo) -> Bool {
        info.id == currentVaultID
    }

    /// Opens the picker; if the chosen folder is already a known vault,
    /// switches to it instead of adding a duplicate entry.
    func pickVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Vault"
        panel.message = "Choose a folder where Nibora will store your journal entries."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        addOrSwitch(to: url)
    }

    func changeVault() {
        pickVault()
    }

    func switchToVault(_ info: VaultInfo) {
        guard info.id != currentVaultID else { return }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: info.bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            removeVault(info)
            return
        }
        guard url.startAccessingSecurityScopedResource() else {
            removeVault(info)
            return
        }

        stopAccessingIfNeeded()
        isAccessingSecurityScope = true
        vaultURL = url
        displayPath = info.displayPath
        currentVaultID = info.id
        UserDefaults.standard.set(info.id.uuidString, forKey: currentVaultIDDefaultsKey)

        if let index = recentVaults.firstIndex(where: { $0.id == info.id }) {
            recentVaults[index].lastOpenedAt = Date()
            if isStale, let refreshed = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                recentVaults[index].bookmarkData = refreshed
            }
            persistRecents()
        }
    }

    /// Forgets a vault from the list — does not touch anything on disk.
    /// Removing the active vault falls back to the next-most-recent one, or
    /// back to the vault picker if none remain.
    func removeVault(_ info: VaultInfo) {
        recentVaults.removeAll { $0.id == info.id }
        persistRecents()

        guard currentVaultID == info.id else { return }

        stopAccessingIfNeeded()
        vaultURL = nil
        displayPath = nil
        currentVaultID = nil
        UserDefaults.standard.removeObject(forKey: currentVaultIDDefaultsKey)

        if let next = recentVaults.max(by: { $0.lastOpenedAt < $1.lastOpenedAt }) {
            switchToVault(next)
        }
    }

    private func addOrSwitch(to url: URL) {
        let standardizedPath = url.standardizedFileURL.path

        if let existing = recentVaults.first(where: { $0.displayPath == standardizedPath }) {
            switchToVault(existing)
            return
        }

        guard url.startAccessingSecurityScopedResource() else { return }
        guard let bookmarkData = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            url.stopAccessingSecurityScopedResource()
            return
        }

        let info = VaultInfo(id: UUID(), bookmarkData: bookmarkData, displayPath: standardizedPath, lastOpenedAt: Date())
        recentVaults.append(info)
        persistRecents()

        stopAccessingIfNeeded()
        isAccessingSecurityScope = true
        vaultURL = url
        displayPath = standardizedPath
        currentVaultID = info.id
        UserDefaults.standard.set(info.id.uuidString, forKey: currentVaultIDDefaultsKey)
    }

    private func resolveCurrentVault() {
        guard let idString = UserDefaults.standard.string(forKey: currentVaultIDDefaultsKey),
              let id = UUID(uuidString: idString),
              let info = recentVaults.first(where: { $0.id == id }) else {
            return
        }
        switchToVault(info)
    }

    /// One-time upgrade from the old single-vault storage (two loose
    /// UserDefaults keys) into the new list format, preserving whatever
    /// vault was already open so existing users don't get dropped back to
    /// the picker on first launch after this update.
    private func migrateLegacyVaultIfNeeded() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: legacyBookmarkDefaultsKey) else { return }
        let displayPath = UserDefaults.standard.string(forKey: legacyDisplayPathDefaultsKey) ?? "Vault"

        let info = VaultInfo(id: UUID(), bookmarkData: bookmarkData, displayPath: displayPath, lastOpenedAt: Date())
        recentVaults = [info]
        persistRecents()
        UserDefaults.standard.set(info.id.uuidString, forKey: currentVaultIDDefaultsKey)

        UserDefaults.standard.removeObject(forKey: legacyBookmarkDefaultsKey)
        UserDefaults.standard.removeObject(forKey: legacyDisplayPathDefaultsKey)
    }

    private func loadRecents() {
        guard let data = UserDefaults.standard.data(forKey: recentsDefaultsKey),
              let decoded = try? JSONDecoder().decode([VaultInfo].self, from: data) else { return }
        recentVaults = decoded
    }

    private func persistRecents() {
        guard let data = try? JSONEncoder().encode(recentVaults) else { return }
        UserDefaults.standard.set(data, forKey: recentsDefaultsKey)
    }

    private func stopAccessingIfNeeded() {
        if isAccessingSecurityScope {
            vaultURL?.stopAccessingSecurityScopedResource()
            isAccessingSecurityScope = false
        }
    }
}
