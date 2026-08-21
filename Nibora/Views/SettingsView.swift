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
            PasswordSettingsTab()
                .tabItem { Label("Password", systemImage: "lock.fill") }
        }
    }
}

private struct GeneralSettingsTab: View {
    @Environment(VaultManager.self) private var vaultManager
    @Environment(EntrySortPreferences.self) private var sortPreferences
    @Environment(JournalTitlePreferences.self) private var journalTitlePreferences

    var body: some View {
        @Bindable var sortPreferences = sortPreferences
        @Bindable var journalTitlePreferences = journalTitlePreferences

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

            Section("Journal Title") {
                TextField("e.g. Mike's Journal", text: $journalTitlePreferences.title)
                Text("Shown in the window's title bar. Leave blank to hide it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

private struct PasswordSettingsTab: View {
    @Environment(PasswordLockPreferences.self) private var preferences
    @Environment(AppLockManager.self) private var lockManager

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var statusMessage: String?
    @State private var isError = false
    @State private var generatedRecoveryCode: String?

    var body: some View {
        if lockManager.isLocked {
            ContentUnavailableView(
                "Unlock Nibora First",
                systemImage: "lock.fill",
                description: Text("Password settings are unavailable while the app is locked.")
            )
            .frame(width: 440, height: 300)
        } else {
            settingsForm
        }
    }

    private var settingsForm: some View {
        @Bindable var preferences = preferences

        return Form {
            Section("Password") {
                if preferences.hasPassword {
                    SecureField("Current Password", text: $currentPassword)
                }
                SecureField("New Password", text: $newPassword)
                SecureField("Confirm New Password", text: $confirmPassword)

                HStack {
                    Button(preferences.hasPassword ? "Change Password" : "Set Password") {
                        changePassword()
                    }
                    .disabled(newPassword.isEmpty)

                    if preferences.hasPassword {
                        Button("Remove Password", role: .destructive) {
                            removePassword()
                        }
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(isError ? .red : .secondary)
                }
            }

            Section("Lock Behavior") {
                Stepper(value: $preferences.lockAfterMinutes, in: PasswordLockPreferences.minutesRange, step: 1) {
                    LabeledContent("Lock after", value: "\(preferences.lockAfterMinutes) min")
                }
                Toggle("Require password after minimizing", isOn: $preferences.lockOnMinimize)

                Text("This is a privacy screen, not encryption — entries stay plain text on disk either way.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Recovery Code") {
                if preferences.hasRecoveryCode {
                    Text("A recovery code is set. Enter it at the lock screen if you forget your password — using it will require setting a new one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Regenerate Recovery Code") {
                        generatedRecoveryCode = preferences.generateRecoveryCode()
                    }
                } else {
                    Text("Generate a one-time recovery code now, before you ever need it. It's shown once — save it somewhere safe.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Generate Recovery Code") {
                        generatedRecoveryCode = preferences.generateRecoveryCode()
                    }
                }
            }
            .disabled(!preferences.hasPassword)
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: Binding(
            get: { generatedRecoveryCode != nil },
            set: { isPresented in if !isPresented { generatedRecoveryCode = nil } }
        )) {
            if let generatedRecoveryCode {
                RecoveryCodeRevealView(code: generatedRecoveryCode)
            }
        }
    }

    private func changePassword() {
        guard newPassword == confirmPassword else {
            statusMessage = "Passwords don't match."
            isError = true
            return
        }
        if preferences.hasPassword {
            guard preferences.verifyPassword(currentPassword) else {
                statusMessage = "Current password is incorrect."
                isError = true
                return
            }
        }
        preferences.setPassword(newPassword)
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
        statusMessage = "Password updated."
        isError = false
    }

    private func removePassword() {
        preferences.clearPassword()
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
        statusMessage = "Password removed."
        isError = false
    }
}

/// Shows a freshly-generated recovery code exactly once — the app never
/// retains a copy after this (only the hash persists), so this is the
/// only chance to save it.
private struct RecoveryCodeRevealView: View {
    let code: String

    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Your Recovery Code")
                .font(.title3.bold())

            Text(code)
                .font(.system(.title2, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.15)))

            Text("Save this now — it won't be shown again. Using it later will require setting a new password.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Button(didCopy ? "Copied!" : "Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    didCopy = true
                }
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 360)
    }
}

#Preview {
    SettingsView()
        .environment(VaultManager())
        .environment(ThemeManager())
        .environment(EntrySortPreferences())
        .environment(TimestampHotkeyPreferences())
        .environment(FontPreferences())
        .environment(JournalTitlePreferences())
        .environment(PasswordLockPreferences())
        .environment(AppLockManager(preferences: PasswordLockPreferences()))
        .modelContainer(for: JournalEntryRecord.self, inMemory: true)
}
