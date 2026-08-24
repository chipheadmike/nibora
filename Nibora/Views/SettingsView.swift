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
            EntriesSettingsTab()
                .tabItem { Label("Entries", systemImage: "doc.badge.plus") }
            EditorSettingsTab()
                .tabItem { Label("Editor", systemImage: "textformat") }
            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            ColorsSettingsTab()
                .tabItem { Label("Colors", systemImage: "paintbrush") }
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

    @State private var backupStatusMessage: String?

    var body: some View {
        @Bindable var sortPreferences = sortPreferences
        @Bindable var journalTitlePreferences = journalTitlePreferences

        Form {
            Section("Vault") {
                LabeledContent("Location") {
                    Text(vaultManager.displayPath ?? "None")
                        .foregroundStyle(.secondary)
                }
                Button("Open Other Vault…") {
                    vaultManager.pickVault()
                }

                ForEach(vaultManager.recentVaults.sorted(by: { $0.lastOpenedAt > $1.lastOpenedAt })) { info in
                    HStack {
                        Label(info.displayName, systemImage: vaultManager.isCurrent(info) ? "checkmark.circle.fill" : "externaldrive")
                            .foregroundStyle(vaultManager.isCurrent(info) ? Color.accentColor : .primary)
                        Spacer()
                        if !vaultManager.isCurrent(info) {
                            Button("Switch") {
                                vaultManager.switchToVault(info)
                            }
                            Button("Remove") {
                                vaultManager.removeVault(info)
                            }
                            .foregroundStyle(.red)
                        }
                    }
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

private struct EntriesSettingsTab: View {
    @Environment(EntryTemplatePreferences.self) private var entryTemplatePreferences
    @Environment(StreakReminderPreferences.self) private var reminderPreferences

    var body: some View {
        @Bindable var entryTemplatePreferences = entryTemplatePreferences
        @Bindable var reminderPreferences = reminderPreferences

        Form {
            Section("Reminders") {
                Toggle("Remind me if I haven't written yet", isOn: Binding(
                    get: { reminderPreferences.isEnabled },
                    set: { newValue in
                        reminderPreferences.isEnabled = newValue
                        if newValue {
                            StreakReminderScheduler.requestAuthorizationIfNeeded()
                        }
                    }
                ))
                DatePicker("At", selection: $reminderPreferences.reminderTime, displayedComponents: .hourAndMinute)
                    .disabled(!reminderPreferences.isEnabled)
                Text("A single local notification, only on days you haven't written yet. Nothing is sent anywhere — this uses macOS's own notification scheduling.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Templates") {
                Toggle("Offer a template when creating new entries", isOn: $entryTemplatePreferences.isEnabled)

                ForEach($entryTemplatePreferences.templates) { $template in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("Name", text: $template.name)
                                .textFieldStyle(.plain)
                                .font(.headline)
                            Spacer()
                            if entryTemplatePreferences.defaultTemplateID == template.id {
                                Text("Default")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Make Default") {
                                    entryTemplatePreferences.defaultTemplateID = template.id
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }
                            Button {
                                entryTemplatePreferences.removeTemplate(template)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                        }
                        TextEditor(text: $template.text)
                            .font(.body.monospaced())
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    }
                    .padding(.vertical, 4)
                    .disabled(!entryTemplatePreferences.isEnabled)
                }

                Button("Add Template") {
                    entryTemplatePreferences.addTemplate()
                }
                .disabled(!entryTemplatePreferences.isEnabled)

                Text("With more than one template, New Entry becomes a menu to pick which to start from (or a blank entry). With just one, New Entry uses it automatically. Use {{weekday}} to insert the day's name, e.g. \"### {{weekday}}\" becomes \"### Monday\".")
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
    @Environment(AppAppearancePreferences.self) private var appAppearancePreferences

    var body: some View {
        @Bindable var themeManager = themeManager
        @Bindable var appAppearancePreferences = appAppearancePreferences

        Form {
            Section("Display") {
                Picker("Appearance", selection: $appAppearancePreferences.mode) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                Text("Overrides the system setting for Nibora only. Every color on the Colors tab automatically adjusts brightness as needed to stay legible against whichever mode is active — Light and Dark aren't separate palettes, just a readability nudge on top of the ones you've chosen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Theme Presets") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ThemePresets.all) { preset in
                            Button {
                                themeManager.apply(preset)
                            } label: {
                                VStack(spacing: 4) {
                                    HStack(spacing: 2) {
                                        ForEach(Array(preset.previewSwatches.enumerated()), id: \.offset) { _, swatch in
                                            Circle().fill(swatch).frame(width: 12, height: 12)
                                        }
                                    }
                                    Text(preset.name)
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Text("Applies every color on the Colors tab at once — a starting point you can still fine-tune there.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ColorsSettingsTab: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(FontPreferences.self) private var fontPreferences

    var body: some View {
        @Bindable var themeManager = themeManager
        @Bindable var fontPreferences = fontPreferences

        Form {
            Section("Text Colors") {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    colorGridRow("Body Text", $themeManager.bodyColor, "# Heading 1", $themeManager.h1Color)
                    colorGridRow("## Heading 2", $themeManager.h2Color, "### Heading 3", $themeManager.h3Color)
                    colorGridRow("#### Heading 4", $themeManager.h4Color, "##### Heading 5", $themeManager.h5Color)
                    colorGridRow("###### Heading 6", $themeManager.h6Color, "Bold", $themeManager.boldColor)
                    colorGridRow("Italic", $themeManager.italicColor, "Link", $themeManager.linkColor)
                    colorGridRow("Strikethrough", $themeManager.strikethroughColor, "Blockquote", $themeManager.blockquoteColor)
                    colorGridRow("Horizontal Rule", $themeManager.horizontalRuleColor, "Tag", $themeManager.tagColor)
                    colorGridRow("Entry Link", $themeManager.wikilinkColor)
                }
                .padding(.vertical, 4)
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

    @ViewBuilder
    private func colorGridRow(_ label1: String, _ color1: Binding<Color>, _ label2: String? = nil, _ color2: Binding<Color>? = nil) -> some View {
        GridRow {
            colorCell(label1, color1)
            if let label2, let color2 {
                colorCell(label2, color2)
            } else {
                Color.clear
            }
        }
    }

    private func colorCell(_ label: String, _ color: Binding<Color>) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .lineLimit(1)
            Spacer(minLength: 8)
            ColorPicker("", selection: color)
                .labelsHidden()
        }
        .gridCellColumns(1)
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
        .environment(AppAppearancePreferences())
        .environment(StreakReminderPreferences())
        .modelContainer(for: JournalEntryRecord.self, inMemory: true)
}
