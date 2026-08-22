//
//  EntryHistoryView.swift
//  Nibora
//

import SwiftUI

/// Lists EntryHistoryService's snapshots for one entry and lets the user
/// restore the body text from any of them. Restoring only replaces the
/// live-editing body text (via onRestore), not the title/frontmatter — it
/// reads as "get back text I lost," not "revert everything about this
/// entry to that moment."
struct EntryHistoryView: View {
    let fileURL: URL
    let onRestore: (String) -> Void

    @State private var snapshots: [EntrySnapshot] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Version History")
                .font(.headline)
                .padding(16)

            Divider()

            if snapshots.isEmpty {
                Text("No earlier versions yet. A snapshot is saved automatically about every 10 minutes while you're actively editing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            } else {
                List {
                    ForEach(snapshots) { snapshot in
                        HStack {
                            Text(Self.dateFormatter.string(from: snapshot.date))
                            Spacer()
                            Button("Restore") {
                                restore(snapshot)
                            }
                        }
                    }
                }
                .frame(height: 240)
            }
        }
        .frame(width: 340)
        .onAppear { snapshots = EntryHistoryService.snapshots(for: fileURL) }
    }

    private func restore(_ snapshot: EntrySnapshot) {
        guard let contents = try? String(contentsOf: snapshot.url, encoding: .utf8) else { return }
        onRestore(MarkdownFrontmatterParser.parse(contents).body)
        dismiss()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
