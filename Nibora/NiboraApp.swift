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
    @State private var sortPreferences = EntrySortPreferences()
    @State private var hotkeyPreferences = TimestampHotkeyPreferences()
    @State private var fontPreferences = FontPreferences()
    @State private var journalTitlePreferences = JournalTitlePreferences()
    @State private var entryTemplatePreferences = EntryTemplatePreferences()
    @State private var speechVoicePreferences = SpeechVoicePreferences()
    @State private var aiProviderPreferences = AIProviderPreferences()
    @State private var appAppearancePreferences = AppAppearancePreferences()
    @State private var passwordLockPreferences: PasswordLockPreferences
    @State private var appLockManager: AppLockManager

    let sharedModelContainer: ModelContainer = {
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
                .environment(sortPreferences)
                .environment(hotkeyPreferences)
                .environment(fontPreferences)
                .environment(journalTitlePreferences)
                .environment(entryTemplatePreferences)
                .environment(speechVoicePreferences)
                .environment(aiProviderPreferences)
                .environment(appAppearancePreferences)
                .environment(passwordLockPreferences)
                .environment(appLockManager)
                .preferredColorScheme(appAppearancePreferences.mode.colorScheme)
        }
        .modelContainer(sharedModelContainer)

        MenuBarExtra("Quick Capture", systemImage: "square.and.pencil") {
            QuickCaptureView()
                .environment(vaultManager)
                .environment(entryTemplatePreferences)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView()
                .environment(vaultManager)
                .environment(themeManager)
                .environment(sortPreferences)
                .environment(hotkeyPreferences)
                .environment(fontPreferences)
                .environment(journalTitlePreferences)
                .environment(entryTemplatePreferences)
                .environment(speechVoicePreferences)
                .environment(aiProviderPreferences)
                .environment(appAppearancePreferences)
                .environment(passwordLockPreferences)
                .environment(appLockManager)
                .preferredColorScheme(appAppearancePreferences.mode.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
