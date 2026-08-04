//
//  SettingsView.swift
//  Nibora
//

import SwiftUI
import SwiftData
import AppKit

struct SettingsView: View {
    @Environment(VaultManager.self) private var vaultManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext

    @State private var importResultMessage: String?

    var body: some View {
        @Bindable var themeManager = themeManager

        Form {
            Section("Vault") {
                LabeledContent("Location") {
                    Text(vaultManager.displayPath ?? "None")
                        .foregroundStyle(.secondary)
                }
                Button("Change Vault…") {
                    vaultManager.changeVault()
                }
            }

            Section("Appearance") {
                ColorPicker("Body Text", selection: $themeManager.bodyColor)
                ColorPicker("# Heading 1", selection: $themeManager.h1Color)
                ColorPicker("## Heading 2", selection: $themeManager.h2Color)
                ColorPicker("### Heading 3", selection: $themeManager.h3Color)
                ColorPicker("#### Heading 4", selection: $themeManager.h4Color)
                ColorPicker("##### Heading 5", selection: $themeManager.h5Color)
                ColorPicker("###### Heading 6", selection: $themeManager.h6Color)
                Button("Reset to Defaults") {
                    themeManager.resetToDefaults()
                }
            }

            Section("Import") {
                Button("Import from Folder…") {
                    importFromFolder()
                }
                .disabled(vaultManager.vaultURL == nil)

                if let importResultMessage {
                    Text(importResultMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Choose a folder of exported Markdown files (e.g. from Ulysses' Export → Markdown) to bring them in as new entries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func importFromFolder() {
        guard let vaultURL = vaultManager.vaultURL else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose the folder of exported Markdown files to import."

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }

        let result = ImportService.importFiles(from: folderURL, into: vaultURL, modelContext: modelContext)
        let entryWord = result.importedCount == 1 ? "entry" : "entries"
        var message = "Imported \(result.importedCount) \(entryWord)"
        if result.skippedCount > 0 {
            message += ", skipped \(result.skippedCount)"
        }
        importResultMessage = message
    }
}

#Preview {
    SettingsView()
        .environment(VaultManager())
        .environment(ThemeManager())
        .modelContainer(for: JournalEntryRecord.self, inMemory: true)
}
