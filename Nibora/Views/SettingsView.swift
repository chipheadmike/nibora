//
//  SettingsView.swift
//  Nibora
//

import SwiftUI
import SwiftData
import AppKit
import AVFoundation
import UniformTypeIdentifiers

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
            AISettingsTab()
                .tabItem { Label("AI", systemImage: "sparkles") }
        }
    }
}

private struct GeneralSettingsTab: View {
    @Environment(VaultManager.self) private var vaultManager
    @Environment(EntrySortPreferences.self) private var sortPreferences
    @Environment(JournalTitlePreferences.self) private var journalTitlePreferences
    @Environment(EntryTemplatePreferences.self) private var entryTemplatePreferences

    @State private var backupStatusMessage: String?

    var body: some View {
        @Bindable var sortPreferences = sortPreferences
        @Bindable var journalTitlePreferences = journalTitlePreferences
        @Bindable var entryTemplatePreferences = entryTemplatePreferences

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

            Section("Backup") {
                Button("Export Vault as Zip…") {
                    exportVaultBackup()
                }
                .disabled(vaultManager.vaultURL == nil)

                if let backupStatusMessage {
                    Text(backupStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Creates a single .zip file with every entry and attachment in your vault — useful for backups or moving to another Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                if sortPreferences.mode != .manual {
                    Picker("Order", selection: $sortPreferences.direction) {
                        ForEach(EntrySortDirection.allCases) { direction in
                            Text(direction.label).tag(direction)
                        }
                    }
                }
                Text("Manual lets you drag/reorder entries yourself via the sidebar's context menu. The date modes ignore that order and always sort live.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Template") {
                Toggle("Start new entries from a template", isOn: $entryTemplatePreferences.isEnabled)
                TextEditor(text: $entryTemplatePreferences.templateText)
                    .font(.body.monospaced())
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    .disabled(!entryTemplatePreferences.isEnabled)
                Text("Applied as the starting body text whenever you create a new entry. Use {{weekday}} to insert the day's name, e.g. \"### {{weekday}}\" becomes \"### Monday\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func exportVaultBackup() {
        guard let vaultURL = vaultManager.vaultURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "Nibora Backup \(Self.backupDateFormatter.string(from: Date()))"
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        do {
            try VaultBackupService.exportZip(vaultURL: vaultURL, to: destinationURL)
            backupStatusMessage = "Backup saved to \(destinationURL.lastPathComponent)."
        } catch {
            backupStatusMessage = "Backup failed: \(error.localizedDescription)"
        }
    }

    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

private struct EditorSettingsTab: View {
    @Environment(FontPreferences.self) private var fontPreferences
    @Environment(TimestampHotkeyPreferences.self) private var hotkeyPreferences
    @Environment(SpeechVoicePreferences.self) private var speechVoicePreferences

    @State private var previewReader = SpeechReader()

    var body: some View {
        @Bindable var fontPreferences = fontPreferences
        @Bindable var speechVoicePreferences = speechVoicePreferences

        Form {
            Section("Font") {
                Picker("Editor Font", selection: $fontPreferences.fontName) {
                    ForEach(FontPreferences.availableFontNames, id: \.self) { name in
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

            Section("Read Aloud") {
                Picker("Voice", selection: Binding(
                    get: { speechVoicePreferences.voiceIdentifier ?? "" },
                    set: { speechVoicePreferences.voiceIdentifier = $0.isEmpty ? nil : $0 }
                )) {
                    Text("System Default").tag("")
                    ForEach(SpeechVoicePreferences.availableVoices, id: \.identifier) { voice in
                        Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                    }
                }
                Text("Used when reading an entry aloud from the toolbar. Markdown syntax is stripped first, so headings, links, and list markers are spoken as clean prose.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading) {
                    Text("Rate: \(String(format: "%.2f", speechVoicePreferences.rate))")
                    Slider(value: $speechVoicePreferences.rate, in: SpeechVoicePreferences.rateRange)
                }
                VStack(alignment: .leading) {
                    Text("Pitch: \(String(format: "%.2f", speechVoicePreferences.pitch))")
                    Slider(value: $speechVoicePreferences.pitch, in: SpeechVoicePreferences.pitchRange)
                }

                HStack {
                    Button(previewReader.isSpeaking ? "Stop" : "Preview Voice") {
                        if previewReader.isSpeaking {
                            previewReader.stop()
                        } else {
                            previewReader.speak(
                                "This is a preview of the current voice, rate, and pitch settings.",
                                voiceIdentifier: speechVoicePreferences.voiceIdentifier,
                                rate: Float(speechVoicePreferences.rate),
                                pitch: Float(speechVoicePreferences.pitch)
                            )
                        }
                    }
                    Button("Reset to Defaults") {
                        speechVoicePreferences.resetRateAndPitch()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onDisappear {
            previewReader.stop()
        }
    }
}

private struct AppearanceSettingsTab: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(FontPreferences.self) private var fontPreferences

    var body: some View {
        @Bindable var themeManager = themeManager
        @Bindable var fontPreferences = fontPreferences

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
                ColorPicker("Link", selection: $themeManager.linkColor)
                ColorPicker("Strikethrough", selection: $themeManager.strikethroughColor)
                ColorPicker("Blockquote", selection: $themeManager.blockquoteColor)
                ColorPicker("Horizontal Rule", selection: $themeManager.horizontalRuleColor)
                ColorPicker("Tag", selection: $themeManager.tagColor)
                ColorPicker("Entry Link", selection: $themeManager.wikilinkColor)
            }

            Section("Highlight") {
                ColorPicker("Highlight Background", selection: $themeManager.highlightColor)
                Text("Applies to text wrapped in ==double equals==.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Code") {
                Picker("Code Font", selection: $fontPreferences.codeFontName) {
                    ForEach(FontPreferences.availableFontNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                ColorPicker("Code Text", selection: $themeManager.codeColor)
                Text("Applies to text wrapped in `backticks`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset to Defaults") {
                    themeManager.resetToDefaults()
                }
                .help("Resets colors only — the code font is reset from the Editor tab, alongside the main editor font.")
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
    @State private var isOrphanScanPresented = false
    @State private var scannedOrphans: [OrphanedAttachmentScanner.OrphanedFile] = []

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

            Section("Attachments") {
                Button("Scan for Orphaned Attachments…") {
                    scanForOrphanedAttachments()
                }
                .disabled(vaultManager.vaultURL == nil)

                Text("Finds image files in Attachments folders that no entry references anymore, so you can move them to the Trash.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: $isOrphanScanPresented) {
            OrphanedAttachmentsView(orphans: scannedOrphans)
        }
    }

    private func scanForOrphanedAttachments() {
        guard let vaultURL = vaultManager.vaultURL else { return }
        let entries = (try? modelContext.fetch(FetchDescriptor<JournalEntryRecord>())) ?? []
        scannedOrphans = OrphanedAttachmentScanner.scan(vaultURL: vaultURL, entries: entries)
        isOrphanScanPresented = true
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

            Section("Recovery Email") {
                TextField("you@example.com", text: $preferences.recoveryEmail)
                Text("If set, the lock screen can also send a one-time temporary code to this address via a Mail.app draft — Nibora opens it pre-filled, but you review and send it yourself. Nothing is sent automatically, and no credentials are stored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

private struct AISettingsTab: View {
    @Environment(AIProviderPreferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences

        Form {
            Section("Provider") {
                Picker("Ask Nibora uses", selection: $preferences.selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.label).tag(provider)
                    }
                }
                Text(privacyNote(for: preferences.selectedProvider))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Claude (Anthropic)") {
                SecureField("API Key", text: $preferences.claudeAPIKey)
                Text("From console.anthropic.com. Stored in this Mac's Keychain, never in plain text, never sent anywhere except directly to Anthropic's API.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("ChatGPT (OpenAI)") {
                SecureField("API Key", text: $preferences.openAIAPIKey)
                Text("From platform.openai.com. Stored in this Mac's Keychain, never in plain text, never sent anywhere except directly to OpenAI's API.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Claude and ChatGPT are billed to your own API key, pay-per-use — not part of any Nibora cost. On-Device is free and requires no key, but depends on Apple Intelligence being enabled on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func privacyNote(for provider: AIProvider) -> String {
        switch provider {
        case .onDevice:
            return "Fully local — your questions and journal excerpts never leave this Mac."
        case .claude:
            return "Your questions and relevant journal excerpts are sent to Anthropic's servers to be answered."
        case .chatGPT:
            return "Your questions and relevant journal excerpts are sent to OpenAI's servers to be answered."
        }
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
        .environment(EntryTemplatePreferences())
        .environment(SpeechVoicePreferences())
        .environment(PasswordLockPreferences())
        .environment(AppLockManager(preferences: PasswordLockPreferences()))
        .environment(AIProviderPreferences())
        .modelContainer(for: JournalEntryRecord.self, inMemory: true)
}
