//
//  NiboraApp.swift
//  Nibora
//
//  Created by Mike Williams on 8/4/26.
//

import SwiftUI
import SwiftData

@main
struct NiboraApp: App {
    @State private var vaultManager = VaultManager()
    @State private var themeManager = ThemeManager()
    @State private var tagColorPreferences = TagColorPreferences()
    @State private var sortPreferences = EntrySortPreferences()
    @State private var hotkeyPreferences = TimestampHotkeyPreferences()
    @State private var fontPreferences = FontPreferences()
    @State private var journalTitlePreferences = JournalTitlePreferences()
    @State private var entryTemplatePreferences = EntryTemplatePreferences()
    @State private var speechVoicePreferences = SpeechVoicePreferences()
    @State private var aiProviderPreferences = AIProviderPreferences()
    @State private var appAppearancePreferences = AppAppearancePreferences()
    @State private var streakReminderPreferences = StreakReminderPreferences()
    @State private var passwordLockPreferences: PasswordLockPreferences
    @State private var appLockManager: AppLockManager

    /// Static so CaptureJournalEntryIntent — a standalone struct with no
    /// access to this App instance's @State — can reach the same
    /// persistent store when Siri/Shortcuts invokes it.
    static let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: JournalEntryRecord.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        let passwordPrefs = PasswordLockPreferences()
        _passwordLockPreferences = State(initialValue: passwordPrefs)
        _appLockManager = State(initialValue: AppLockManager(preferences: passwordPrefs))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vaultManager)
                .environment(themeManager)
                .environment(tagColorPreferences)
                .environment(sortPreferences)
                .environment(hotkeyPreferences)
                .environment(fontPreferences)
                .environment(journalTitlePreferences)
                .environment(entryTemplatePreferences)
                .environment(speechVoicePreferences)
                .environment(aiProviderPreferences)
                .environment(appAppearancePreferences)
                .environment(streakReminderPreferences)
                .environment(passwordLockPreferences)
                .environment(appLockManager)
                .preferredColorScheme(appAppearancePreferences.mode.colorScheme)
        }
        .modelContainer(Self.sharedModelContainer)
        .commands {
            // A menu bar fallback for switching vaults — the sidebar
            // toolbar's own Vaults button can vanish under macOS's
            // customizable-toolbar overflow behavior at narrower window
            // widths; the menu bar isn't subject to that at all.
            CommandMenu("Vault") {
                ForEach(vaultManager.recentVaults.sorted(by: { $0.lastOpenedAt > $1.lastOpenedAt })) { info in
                    Button(info.displayName) {
                        vaultManager.switchToVault(info)
                    }
                    .disabled(vaultManager.isCurrent(info))
                }
                Divider()
                Button("Open Other Vault…") {
                    vaultManager.pickVault()
                }
            }
        }

        MenuBarExtra("Quick Capture", systemImage: "square.and.pencil") {
            QuickCaptureView()
                .environment(vaultManager)
                .environment(entryTemplatePreferences)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(Self.sharedModelContainer)

        Settings {
            SettingsView()
                .environment(vaultManager)
                .environment(themeManager)
                .environment(tagColorPreferences)
                .environment(sortPreferences)
                .environment(hotkeyPreferences)
                .environment(fontPreferences)
                .environment(journalTitlePreferences)
                .environment(entryTemplatePreferences)
                .environment(speechVoicePreferences)
                .environment(aiProviderPreferences)
                .environment(appAppearancePreferences)
                .environment(streakReminderPreferences)
                .environment(passwordLockPreferences)
                .environment(appLockManager)
                .preferredColorScheme(appAppearancePreferences.mode.colorScheme)
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
