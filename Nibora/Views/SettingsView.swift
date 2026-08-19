//
//  SettingsView.swift
//  Nibora
//

import SwiftUI
import SwiftData
import AppKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            EditorSettingsTab()
                .tabItem { Label("Editor", systemImage: "textformat") }
            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            ImportSettingsTab()
                .tabItem { Label("Import", systemImage: "square.and.arrow.down") }
        }
    }
}

private struct GeneralSettingsTab: View {
    @Environment(VaultManager.self) private var vaultManager
    @Environment(EntrySortPreferences.self) private var sortPreferences

    var body: some View {
        @Bindable var sortPreferences = sortPreferences

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

            Section("Sorting") {
                Picker("Sort entries within a month by", selection: $sortPreferences.mode) {
                    ForEach(EntrySortMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                Text("Manual lets you drag/reorder entries yourself via the sidebar's context menu. The date modes ignore that order and always sort live.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct EditorSettingsTab: View {
    @Environment(FontPreferences.self) private var fontPreferences
    @Environment(TimestampHotkeyPreferences.self) private var hotkeyPreferences

    private static let availableFontNames: [String] = {
        [FontPreferences.systemMonospacedSentinel] + NSFontManager.shared.availableFontFamilies.sorted()
    }()

    var body: some View {
        @Bindable var fontPreferences = fontPreferences

        Form {
            Section("Font") {
                Picker("Editor Font", selection: $fontPreferences.fontName) {
                    ForEach(Self.availableFontNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                Stepper(value: $fontPreferences.fontSize, in: FontPreferences.sizeRange, step: 1) {
                    LabeledContent("Size", value: "\(Int(fontPreferences.fontSize))pt")
                }
                Button("Reset to Defaults") {
                    fontPreferences.resetToDefaults()
                }
            }

            Section("Timestamp Hotkey") {
                ShortcutRecorderView(preferences: hotkeyPreferences)
                Text("While writing an entry, press this to insert the current 24-hour time (e.g. \"1350 - \") at the cursor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct AppearanceSettingsTab: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        @Bindable var themeManager = themeManager

        Form {
            Section("Text Colors") {
                ColorPicker("Body Text", selection: $themeManager.bodyColor)
                ColorPicker("# Heading 1", selection: $themeManager.h1Color)
                ColorPicker("## Heading 2", selection: $themeManager.h2Color)
                ColorPicker("### Heading 3", selection: $themeManager.h3Color)
                ColorPicker("#### Heading 4", selection: $themeManager.h4Color)
                ColorPicker("##### Heading 5", selection: $themeManager.h5Color)
                ColorPicker("###### Heading 6", selection: $themeManager.h6Color)
                ColorPicker("Bold", selection: $themeManager.boldColor)
                ColorPicker("Italic", selection: $themeManager.italicColor)
            }

            Section {
                Button("Reset to Defaults") {
                    themeManager.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ImportSettingsTab: View {
    @Environment(VaultManager.self) private var vaultManager
    @Environment(\.modelContext) private var modelContext

    @State private var importResultMessage: String?

    var body: some View {
        Form {
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
        .environment(EntrySortPreferences())
        .environment(TimestampHotkeyPreferences())
        .environment(FontPreferences())
        .modelContainer(for: JournalEntryRecord.self, inMemory: true)
}
