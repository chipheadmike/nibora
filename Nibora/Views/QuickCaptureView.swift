//
//  QuickCaptureView.swift
//  Nibora
//

import SwiftUI
import SwiftData

/// Content of the menu bar quick-capture window — appears only when the
/// menu bar icon is clicked. Deliberately just a click-triggered SwiftUI
/// view, not backed by any global keyboard/event monitor.
struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultManager.self) private var vaultManager
    @Environment(EntryTemplatePreferences.self) private var entryTemplatePreferences
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \JournalEntryRecord.date, order: .reverse) private var allEntries: [JournalEntryRecord]

    @State private var text = ""
    @State private var statusMessage: String?
    @FocusState private var isFocused: Bool

    private var stats: JournalStats {
        JournalStats.compute(from: allEntries)
    }

    private var glanceText: String {
        let streak = stats.currentStreak == 1 ? "1 day streak" : "\(stats.currentStreak) day streak"
        let words = JournalActivity.todaysWordCount(from: allEntries)
        return words > 0 ? "\(streak) · \(words) words today" : streak
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Capture")
                .font(.headline)

            if stats.currentStreak > 0 {
                Text(glanceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(height: 100)
                .focused($isFocused)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("What's on your mind?")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if vaultManager.vaultURL == nil {
                    Text("Open a vault in Nibora first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vaultManager.vaultURL == nil)
            }
        }
        .padding(12)
        .frame(width: 320)
        .onAppear { isFocused = true }
    }

    private func save() {
        guard let vaultURL = vaultManager.vaultURL else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try QuickCaptureService.capture(trimmed, vaultURL: vaultURL, modelContext: modelContext, entryTemplatePreferences: entryTemplatePreferences)
            text = ""
            dismiss()
        } catch {
            statusMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }
}
