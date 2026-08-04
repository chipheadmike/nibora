//
//  VaultManager.swift
//  Nibora
//

import Foundation
import AppKit

/// Owns the user-picked vault folder: security-scoped bookmark persistence,
/// panel-driven selection, and access lifecycle under App Sandbox.
@Observable
final class VaultManager {
    private(set) var vaultURL: URL?
    private(set) var displayPath: String?

    private let bookmarkDefaultsKey = "vaultBookmarkData"
    private let displayPathDefaultsKey = "vaultDisplayPath"

    private var isAccessingSecurityScope = false

    init() {
        resolveStoredVault()
    }

    deinit {
        if isAccessingSecurityScope {
            vaultURL?.stopAccessingSecurityScopedResource()
        }
    }

    func pickVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Vault"
        panel.message = "Choose a folder where Nibora will store your journal entries."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        setVault(url)
    }

    func changeVault() {
        stopAccessingIfNeeded()
        pickVault()
    }

    private func resolveStoredVault() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkDefaultsKey) else {
            return
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard url.startAccessingSecurityScopedResource() else {
                clearStoredVault()
                return
            }
            isAccessingSecurityScope = true

            if isStale {
                persistBookmark(for: url)
            }

            vaultURL = url
            displayPath = UserDefaults.standard.string(forKey: displayPathDefaultsKey) ?? url.path
        } catch {
            clearStoredVault()
        }
    }

    private func setVault(_ url: URL) {
        stopAccessingIfNeeded()

        guard url.startAccessingSecurityScopedResource() else { return }
        isAccessingSecurityScope = true

        persistBookmark(for: url)
        UserDefaults.standard.set(url.path, forKey: displayPathDefaultsKey)

        vaultURL = url
        displayPath = url.path
    }

    private func persistBookmark(for url: URL) {
        guard let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkDefaultsKey)
    }

    private func clearStoredVault() {
        UserDefaults.standard.removeObject(forKey: bookmarkDefaultsKey)
        UserDefaults.standard.removeObject(forKey: displayPathDefaultsKey)
        vaultURL = nil
        displayPath = nil
    }

    private func stopAccessingIfNeeded() {
        if isAccessingSecurityScope {
            vaultURL?.stopAccessingSecurityScopedResource()
            isAccessingSecurityScope = false
        }
    }
}
