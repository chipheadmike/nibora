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

    let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: JournalEntryRecord.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vaultManager)
                .environment(themeManager)
                .environment(sortPreferences)
                .environment(hotkeyPreferences)
                .environment(fontPreferences)
                .environment(journalTitlePreferences)
        }
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView()
                .environment(vaultManager)
                .environment(themeManager)
                .environment(sortPreferences)
                .environment(hotkeyPreferences)
                .environment(fontPreferences)
                .environment(journalTitlePreferences)
        }
        .modelContainer(sharedModelContainer)
    }
}
