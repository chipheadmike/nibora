//
//  ContentView.swift
//  Nibora
//
//  Created by Mike Williams on 8/4/26.
//

import SwiftUI
import SwiftData
import CoreSpotlight

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
    @State private var isJournalStatsPresented = false
    @State private var isHelpPresented = false
    @State private var isGraphPresented = false
    @State private var isAskNiboraPresented = false
    @State private var isDigestPresented = false
    @State private var isHeatmapPresented = false
    @State private var isAttachmentsGalleryPresented = false

    /// Backs the Cmd+K quick switcher — every entry, newest first. Also
    /// used to check for today's entry (see hasEntryForToday) instead of a
    /// separate date-filtered @Query: a predicate built from `Date()` at
    /// init time gets baked in permanently — SwiftUI never re-runs a
    /// view's init just because time passed — so if Nibora stays open
    /// across midnight, that frozen "today" silently goes stale until the
    /// app restarts. Computing it fresh on every access avoids that.
    @Query(sort: \JournalEntryRecord.date, order: .reverse) private var allEntriesForSwitcher: [JournalEntryRecord]

    /// Bumped once a day by watchForDayChange() purely to force a re-render
    /// at the midnight boundary — hasEntryForToday itself always computes
    /// Date() fresh, but SwiftUI only re-evaluates body when some tracked
    /// value actually changes, and nothing else in this view necessarily
    /// changes overnight if the app just sits idle.
    @State private var currentDay = Calendar.current.startOfDay(for: Date())

    private var hasEntryForToday: Bool {
        _ = currentDay
        let todayStart = Calendar.current.startOfDay(for: Date())
        return allEntriesForSwitcher.contains { $0.date == todayStart }
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
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let uuid = UUID(uuidString: identifier),
                  let match = allEntriesForSwitcher.first(where: { $0.id == uuid }) else { return }
            selection = match
        }
        .task {
            await watchForDayChange()
        }
    }

    /// Sleeps until just past the next midnight, then bumps `currentDay` —
    /// repeating for as long as the view exists — purely to force a
    /// re-render so the New Entry button notices the date changed even if
    /// Nibora sits open, untouched, overnight.
    private func watchForDayChange() async {
        while !Task.isCancelled {
            let now = Date()
            let calendar = Calendar.current
            guard let nextMidnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) else {
                return
            }
            let interval = nextMidnight.timeIntervalSince(now) + 1
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            currentDay = calendar.startOfDay(for: Date())
        }
    }

    @ViewBuilder
    private var content: some View {
        if let vaultURL = vaultManager.vaultURL {
            NavigationSplitView {
                SidebarView(selection: $selection, vaultURL: vaultURL, sortMode: sortPreferences.mode, sortDirection: sortPreferences.direction, searchText: searchText)
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
                            Menu {
                                ForEach(vaultManager.recentVaults.sorted(by: { $0.lastOpenedAt > $1.lastOpenedAt })) { info in
                                    Button {
                                        vaultManager.switchToVault(info)
                                    } label: {
                                        Label(info.displayName, systemImage: vaultManager.isCurrent(info) ? "checkmark.circle.fill" : "externaldrive")
                                    }
                                    .disabled(vaultManager.isCurrent(info))
                                }
                                Divider()
                                Button("Open Other Vault…") {
                                    vaultManager.pickVault()
                                }
                            } label: {
                                Label("Vaults", systemImage: "externaldrive.badge.plus")
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
                        ToolbarItem {
                            Button("Random Entry", systemImage: "shuffle") {
                                selectRandomEntry()
                            }
                            .disabled(allEntriesForSwitcher.isEmpty)
                        }
                        ToolbarItem {
                            Button("Journal Stats", systemImage: "chart.bar") {
                                isJournalStatsPresented = true
                            }
                            .popover(isPresented: $isJournalStatsPresented) {
                                JournalStatsView(stats: JournalStats.compute(from: allEntriesForSwitcher))
                            }
                        }
                        ToolbarItem {
                            Button("Entry Graph", systemImage: "point.3.connected.trianglepath.dotted") {
                                isGraphPresented = true
                            }
                        }
                        ToolbarItem {
                            Button("Ask Nibora", systemImage: "sparkles") {
                                isAskNiboraPresented = true
                            }
                        }
                        ToolbarItem {
                            Button("Journal Digest", systemImage: "text.book.closed") {
                                isDigestPresented = true
                            }
                        }
                        ToolbarItem {
                            Button("Writing Calendar", systemImage: "square.grid.3x3.fill") {
                                isHeatmapPresented = true
                            }
                        }
                        ToolbarItem {
                            Button("Attachments", systemImage: "photo.on.rectangle.angled") {
                                isAttachmentsGalleryPresented = true
                            }
                        }
                        ToolbarItem {
                            Button("Guide", systemImage: "questionmark.circle") {
                                isHelpPresented = true
                            }
                        }
                    }
            } detail: {
                if let selection {
                    EntryEditorView(entry: selection, vaultURL: vaultURL, allEntries: allEntriesForSwitcher, onNavigateToEntry: navigateToEntry(titled:))
                } else {
                    ContentUnavailableView("No Entry Selected", systemImage: "doc.text")
                }
            }
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search entries")
            .task(id: vaultURL) {
                EntryIndexer(modelContext: modelContext).rescanFullVault(at: vaultURL)
            }
            .onChange(of: vaultURL) {
                selection = nil
                SpotlightIndexer.removeAll()
            }
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
            .sheet(isPresented: $isHelpPresented) {
                HelpView()
            }
            .sheet(isPresented: $isGraphPresented) {
                EntryGraphView(entries: allEntriesForSwitcher) { entry in
                    selection = entry
                }
            }
            .sheet(isPresented: $isAskNiboraPresented) {
                AskNiboraView(entries: allEntriesForSwitcher)
            }
            .sheet(isPresented: $isDigestPresented) {
                JournalDigestView(entries: allEntriesForSwitcher)
            }
            .sheet(isPresented: $isHeatmapPresented) {
                CalendarHeatmapView(entries: allEntriesForSwitcher) { date in
                    if let match = allEntriesForSwitcher.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                        selection = match
                        isHeatmapPresented = false
                    }
                }
            }
            .sheet(isPresented: $isAttachmentsGalleryPresented) {
                AttachmentsGalleryView(vaultURL: vaultURL, entries: allEntriesForSwitcher) { entry in
                    selection = entry
                    isAttachmentsGalleryPresented = false
                }
            }
        } else {
            VaultPickerView()
        }
    }

    /// Picks a random entry, favoring one different from the current
    /// selection when there's more than one to choose from.
    private func selectRandomEntry() {
        guard !allEntriesForSwitcher.isEmpty else { return }
        if allEntriesForSwitcher.count > 1, let selection {
            let candidates = allEntriesForSwitcher.filter { $0.id != selection.id }
            self.selection = candidates.randomElement()
        } else {
            selection = allEntriesForSwitcher.randomElement()
        }
    }

    /// Resolves a "[[Title]]" wikilink click to an entry by exact
    /// case-insensitive title match. Silently does nothing if no entry has
    /// that title — the editor doesn't distinguish resolved from unresolved
    /// wikilinks visually, so this is the only place that check happens.
    private func navigateToEntry(titled title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let match = allEntriesForSwitcher.first(where: { $0.title.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        selection = match
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
        .environment(SpeechVoicePreferences())
        .environment(AIProviderPreferences())
        .environment(AppAppearancePreferences())
        .environment(AppLockManager(preferences: PasswordLockPreferences()))
        .modelContainer(for: JournalEntryRecord.self, inMemory: true)
}
