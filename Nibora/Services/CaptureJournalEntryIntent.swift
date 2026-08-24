//
//  CaptureJournalEntryIntent.swift
//  Nibora
//

import AppIntents
import SwiftData
import Foundation

/// Lets Siri/Shortcuts append a note to today's entry — the voice/automation
/// counterpart to the menu bar Quick Capture window, sharing the same
/// QuickCaptureService. Runs as a standalone struct (no access to
/// NiboraApp's @State), so it builds its own short-lived VaultManager and a
/// fresh ModelContext against the app's one static shared store.
struct CaptureJournalEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Journal Entry"
    static var description = IntentDescription("Appends a note to today's Nibora journal entry, creating it first if needed.")

    @Parameter(title: "Note")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Capture \(\.$text) in Nibora")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let vaultManager = VaultManager()
        guard let vaultURL = vaultManager.vaultURL else {
            return .result(dialog: "Open a vault in Nibora first.")
        }

        let modelContext = ModelContext(NiboraApp.sharedModelContainer)
        do {
            try QuickCaptureService.capture(text, vaultURL: vaultURL, modelContext: modelContext, entryTemplatePreferences: EntryTemplatePreferences())
            return .result(dialog: "Saved to today's entry.")
        } catch {
            return .result(dialog: "Couldn't save: \(error.localizedDescription)")
        }
    }
}

/// Auto-discovered by the system at launch — makes the intent available in
/// Shortcuts and as a Siri phrase without any manual registration step.
struct NiboraAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureJournalEntryIntent(),
            phrases: [
                "Capture a journal entry in \(.applicationName)",
                "Add a note to \(.applicationName)",
                "Journal in \(.applicationName)"
            ],
            shortTitle: "Capture Entry",
            systemImageName: "square.and.pencil"
        )
    }
}
