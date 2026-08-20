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
    @Environment(\.modelContext) private var modelContext
    @State private var selection: JournalEntryRecord?
    @State private var searchText = ""

    /// Live count of entries dated today, so the New Entry button can hide
    /// itself the moment today's entry exists — journals are one-per-day.
    @Query private var todaysEntries: [JournalEntryRecord]

    init() {
        let todayStart = Calendar.current.startOfDay(for: Date())
        _todaysEntries = Query(filter: #Predicate<JournalEntryRecord> { $0.date == todayStart })
    }

    private var hasEntryForToday: Bool {
        !todaysEntries.isEmpty
    }

    var body: some View {
        Group {
            content
        }
        .background(WindowAccessor(autosaveName: "MainWindow", customTitle: journalTitlePreferences.title))
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
                                EntryIndexer(modelContext: modelContext).rescanFullVault(at: vaultURL)
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
        } else {
            VaultPickerView()
        }
    }

    private func createEntry(in vaultURL: URL) {
        let now = Date()
        let title = Self.titleDateFormatter.string(from: now)
        guard let relativePath = try? EntryFileWriter.createEntry(date: now, title: title, in: vaultURL) else { return }
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
        .modelContainer(for: JournalEntryRecord.self, inMemory: true)
}
