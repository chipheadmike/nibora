//
//  ShortcutRecorderView.swift
//  Nibora
//

import SwiftUI
import AppKit

/// Small control for recording a single keyboard shortcut: shows the
/// current combo, and while "Record…" is active, captures the next keyDown
/// via a local event monitor (scoped only to the recording session).
struct ShortcutRecorderView: View {
    @Bindable var preferences: TimestampHotkeyPreferences

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(isRecording ? "Press keys…" : preferences.displayString)
                .frame(minWidth: 90)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))

            Button(isRecording ? "Cancel" : "Record…") {
                isRecording ? stopRecording() : startRecording()
            }

            if preferences.keyCode != nil {
                Button("Clear") {
                    preferences.clearShortcut()
                }
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            preferences.setShortcut(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
