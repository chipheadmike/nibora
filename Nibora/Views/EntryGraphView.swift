//
//  EntryGraphView.swift
//  Nibora
//

import SwiftUI

/// A node graph of entries connected by "[[wikilinks]]" — deliberately
/// scoped to wikilinks only, not shared tags, since two entries merely
/// sharing a common #tag isn't the same kind of relationship as an explicit
/// link and would turn this into a dense, unreadable hairball. Entries with
/// no wikilink connections at all are excluded rather than shown floating.
/// Layout is a small self-contained force-directed simulation (Canvas +
/// plain SwiftUI buttons for nodes) — no custom AppKit drawing or click
/// handling, which is what's proven unreliable elsewhere in this beta.
struct EntryGraphView: View {
    let entries: [JournalEntryRecord]
    let onSelect: (JournalEntryRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var positions: [UUID: CGPoint] = [:]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Entry Graph")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if adjacency.nodes.isEmpty {
                ContentUnavailableView(
                    "No Linked Entries",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Use [[Entry Title]] in an entry to link it to another — connections will show up here.")
                )
            } else {
                GeometryReader { geometry in
                    ZStack {
                        Canvas { context, _ in
                            for edge in adjacency.edges {
                                guard let start = positions[edge.0], let end = positions[edge.1] else { continue }
                                var path = Path()
                                path.move(to: start)
                                path.addLine(to: end)
                                context.stroke(path, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
                            }
                        }

                        ForEach(adjacency.nodes, id: \.id) { node in
                            if let point = positions[node.id] {
                                Button {
                                    onSelect(node)
                                    dismiss()
                                } label: {
                                    VStack(spacing: 2) {
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 10, height: 10)
                                        Text(node.title.isEmpty ? "(untitled)" : node.title)
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .frame(maxWidth: 90)
                                    }
                                }
                                .buttonStyle(.plain)
                                .position(point)
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onAppear { computeLayout(in: geometry.size) }
                    .onChange(of: geometry.size) { _, newSize in computeLayout(in: newSize) }
                }
            }
        }
        .frame(width: 800, height: 620)
    }

    /// Undirected, deduplicated edges resolved from each entry's own
    /// "[[Title]]" wikilinks — same title-matching rule as the editor's
    /// live navigation (ContentView.navigateToEntry), so what's clickable
    /// in an entry and what shows up here always agree.
    private var adjacency: (nodes: [JournalEntryRecord], edges: [(UUID, UUID)]) {
        let titleIndex = Dictionary(
            entries.map { ($0.title.trimmingCharacters(in: .whitespaces).lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var seenEdgeKeys = Set<String>()
        var edgeList: [(UUID, UUID)] = []
        var connectedIDs = Set<UUID>()

        for entry in entries {
            let nsBody = entry.searchableBody as NSString
            let matches = MarkdownTextView.wikilinkPattern.matches(in: entry.searchableBody, range: NSRange(location: 0, length: nsBody.length))
            for match in matches {
                let title = nsBody.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces).lowercased()
                guard let target = titleIndex[title], target.id != entry.id else { continue }
                let key = [entry.id.uuidString, target.id.uuidString].sorted().joined(separator: "_")
                guard !seenEdgeKeys.contains(key) else { continue }
                seenEdgeKeys.insert(key)
                edgeList.append((entry.id, target.id))
                connectedIDs.insert(entry.id)
                connectedIDs.insert(target.id)
            }
        }

        return (entries.filter { connectedIDs.contains($0.id) }, edgeList)
    }

    /// Fruchterman-Reingold-style force-directed layout: nodes repel each
    /// other, edges pull their endpoints together, run for a fixed number
    /// of iterations. Cheap enough to run synchronously — the node count
    /// here is only entries that actually use wikilinks, which stays small
    /// for a personal journal even as the vault grows.
    private func computeLayout(in size: CGSize) {
        let (nodes, edges) = adjacency
        guard !nodes.isEmpty else { positions = [:]; return }

        var pos: [UUID: CGPoint] = [:]
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.35
        for (index, node) in nodes.enumerated() {
            let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(nodes.count)
            pos[node.id] = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }

        let ids = nodes.map(\.id)
        let k = sqrt((size.width * size.height) / CGFloat(nodes.count)) * 0.8

        for _ in 0..<120 {
            var displacement: [UUID: CGPoint] = Dictionary(uniqueKeysWithValues: ids.map { ($0, .zero) })

            for i in 0..<ids.count {
                for j in (i + 1)..<ids.count {
                    let a = ids[i], b = ids[j]
                    guard let pa = pos[a], let pb = pos[b] else { continue }
                    var dx = pa.x - pb.x
                    var dy = pa.y - pb.y
                    var distance = sqrt(dx * dx + dy * dy)
                    if distance < 0.01 {
                        dx = CGFloat.random(in: -1...1)
                        dy = CGFloat.random(in: -1...1)
                        distance = 0.01
                    }
                    let force = (k * k) / distance
                    let fx = (dx / distance) * force
                    let fy = (dy / distance) * force
                    displacement[a]?.x += fx
                    displacement[a]?.y += fy
                    displacement[b]?.x -= fx
                    displacement[b]?.y -= fy
                }
            }

            for (a, b) in edges {
                guard let pa = pos[a], let pb = pos[b] else { continue }
                let dx = pa.x - pb.x
                let dy = pa.y - pb.y
                let distance = max(sqrt(dx * dx + dy * dy), 0.01)
                let force = (distance * distance) / k
                let fx = (dx / distance) * force
                let fy = (dy / distance) * force
                displacement[a]?.x -= fx
                displacement[a]?.y -= fy
                displacement[b]?.x += fx
                displacement[b]?.y += fy
            }

            for id in ids {
                guard var p = pos[id], let d = displacement[id] else { continue }
                let dLength = max(sqrt(d.x * d.x + d.y * d.y), 0.01)
                let limited = min(dLength, 10)
                p.x += (d.x / dLength) * limited
                p.y += (d.y / dLength) * limited
                p.x = min(max(p.x, 40), size.width - 40)
                p.y = min(max(p.y, 40), size.height - 40)
                pos[id] = p
            }
        }

        positions = pos
    }
}
