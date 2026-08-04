//
//  IconPickerView.swift
//  Nibora
//

import SwiftUI

/// Curated grid of SF Symbols for entry icons. Not a full symbol picker (v1).
struct IconPickerView: View {
    let selectedIcon: String?
    let onSelect: (String?) -> Void

    private static let icons = [
        "sun.max", "moon.stars", "cloud.sun", "cloud.rain", "snowflake", "rainbow",
        "star", "heart", "flame", "leaf", "gift", "sparkles",
        "book.closed", "pencil", "paintpalette", "camera", "music.note", "quote.bubble",
        "cup.and.saucer", "fork.knife", "airplane", "car", "house", "building.2",
        "figure.walk", "dumbbell", "tent", "beach.umbrella", "pawprint", "bicycle",
        "briefcase", "graduationcap", "stethoscope", "gamecontroller", "party.popper", "bell",
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Self.icons, id: \.self) { icon in
                    Button {
                        onSelect(icon)
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(
                                icon == selectedIcon ? Color.accentColor.opacity(0.2) : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Remove Icon", role: .destructive) {
                onSelect(nil)
            }
            .disabled(selectedIcon == nil)
        }
        .padding(12)
        .frame(width: 260)
    }
}
