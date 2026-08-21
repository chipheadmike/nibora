//
//  ContentView.swift
//  Nibora
//
//  Created by Mike Williams on 8/4/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(VaultManager.self) private var vaultManager
    @Environment(EntrySortPreferences.self) private var sortPreferences
    @Environment(JournalTitlePreferences.self) private var journalTitlePreferences
    @Environment(EntryTemplatePreferences.self) private var entryTemplatePreferences
    @Environment(AppLockManager.self) private var appLockManager
    @Environment(\.modelContext) private var modelContext
    @State private var selection: JournalEntryRecord?
    @State private var searchText = ""
    @State private var isQuickSwitcherPresented = false
    @State private var isOnThisDayPresented = false

    /// Live count of entries dated today, so the New Entry button can hide
    /// itself the moment today's entry exists — journals are one-per-day.
    @Query private var todaysEntries: [JournalEntryRecord]

    /// Backs the Cmd+K quick switcher — every entry, newest first.
    @Query(sort: \JournalEntryRecord.date, order: .reverse) private var allEntriesForSwitcher: [JournalEntryRecord]

    init() {
        let todayStart = Calendar.current.startOfDay(for: Date())
        _todaysEntries = Query(filter: #Predicate<JournalEntryRecord> { $0.date == todayStart })
    }

    private var hasEntryForToday: Bool {
        !todaysEntries.isEmpty
    }

    /// Entries whose date shares today's month/day (any year), excluding
    /// today's own entry — most recent past year first.
    private var onThisDayEntries: [JournalEntryRecord] {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.month, .day], from: Date())
        return allEntriesForSwitcher
            .filter { entry in
                let components = calendar.dateComponents([.month, .day], from: entry.date)
                return components.month == today.month && components.day == today.day && !calendar.isDateInToday(entry.date)
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            content
        }
        .background(WindowAccessor(autosaveName: "MainWindow", customTitle: journalTitlePreferences.title))
        .overlay {
            if appLockManager.isLocked {
                LockScreenView(lockManager: appLockManager)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let vaultURL = vaultManager.vaultURL {
            NavigationSplitView {
                SidebarView(selection: $selection, vaultURL: vaultURL, sortMode: sortPreferences.mode, searchText: searchText)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260)
                    .toolbar {
                        if !hasEntryForToday {
                            ToolbarItem {
                                Button("New Entry", systemImage: "square.and.pencil") {
                                    createEntry(in: vaultURL)
                                }
                            }
                        }
                        ToolbarItem {
                            Button("Rescan Vault", systemImage: "arrow.clockwise") {
                                EntryIndexer(modelContext: modelContext).rescanFullVault(at: vaultURL, force: true)
                            }
                        }
                        ToolbarItem {
                            Button("On This Day", systemImage: "calendar.badge.clock") {
                                isOnThisDayPresented = true
                            }
                            .popover(isPresented: $isOnThisDayPresented) {
                                OnThisDayView(entries: onThisDayEntries) { entry in
                                    selection = entry
                                    isOnThisDayPresented = false
                                }
                            }
                        }
                    }
            } detail: {
                if let selection {
                    EntryEditorView(entry: selection, vaultURL: vaultURL)
                } else {
                    ContentUnavailableView("No Entry Selected", systemImage: "doc.text")
                }
            }
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search entries")
            .task(id: vaultURL) {
                EntryIndexer(modelContext: modelContext).rescanFullVault(at: vaultURL)
            }
            .onChange(of: vaultURL) { selection = nil }
            .background {
                Button("Quick Switcher") { isQuickSwitcherPresented = true }
                    .keyboardShortcut("k", modifiers: .command)
                    .hidden()
            }
            .sheet(isPresented: $isQuickSwitcherPresented) {
                QuickSwitcherView(
                    entries: allEntriesForSwitcher,
                    onSelect: { entry in
                        selection = entry
                        isQuickSwitcherPresented = false
                    },
                    onDismiss: { isQuickSwitcherPresented = false }
                )
            }
        } else {
            VaultPickerView()
        }
    }

    private func createEntry(in vaultURL: URL) {
        let now = Date()
        let title = Self.titleDateFormatter.string(from: now)
        let body = entryTemplatePreferences.isEnabled
            ? EntryTemplatePreferences.rendering(entryTemplatePreferences.templateText, for: now)
            : ""
        guard let relativePath = try? EntryFileWriter.createEntry(date: now, title: title, body: body, in: vaultURL) else { return }
        let fileURL = vaultURL.appendingPathComponent(relativePath)
        let indexer = EntryIndexer(modelContext: modelContext)
        indexer.reindexSingleFile(at: fileURL, vaultURL: vaultURL)

        let descriptor = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate { $0.relativePath == relativePath }
        )
        selection = try? modelContext.fetch(descriptor).first
    }

    private static let titleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

#Preview {
    ContentView()
        .environment(VaultManager())
        .environment(ThemeManager())
        .environment(EntrySortPreferences())
        .environment(TimestampHotkeyPreferences())
        .environment(FontPreferences())
        .environment(JournalTitlePreferences())
        .environment(EntryTemplatePreferences())
        .environment(AppLockManager(preferences: PasswordLockPreferences()))
        .modelContainer(for: JournalEntryRecord.self, inMemory: true)
}
