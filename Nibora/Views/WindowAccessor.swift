//
//  WindowAccessor.swift
//  Nibora
//

import SwiftUI
import AppKit

/// Invisible helper that reaches into the hosting NSWindow to enable
/// AppKit's frame-autosave mechanism — SwiftUI's WindowGroup has no direct
/// equivalent. setFrameAutosaveName both restores the last-saved size/
/// position immediately and keeps persisting future changes automatically.
struct WindowAccessor: NSViewRepresentable {
    let autosaveName: String
    var customTitle: String = ""

    func makeNSView(context: Context) -> WindowAccessorView {
        let view = WindowAccessorView()
        view.autosaveName = autosaveName
        view.customTitle = customTitle
        return view
    }

    func updateNSView(_ nsView: WindowAccessorView, context: Context) {
        nsView.autosaveName = autosaveName
        nsView.customTitle = customTitle
        nsView.applyTitle()
    }
}

final class WindowAccessorView: NSView {
    var autosaveName: String = ""
    /// Empty means "no custom title" — the title bar stays hidden, matching
    /// the app's default (Mail/Notes-style) look with the big sidebar title
    /// instead. A non-empty value shows it as the real window title.
    var customTitle: String = ""

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        if !autosaveName.isEmpty {
            window.setFrameAutosaveName(autosaveName)
        }
        applyTitle()
    }

    /// Called from updateNSView too, so changing the title in Settings
    /// while the main window is open takes effect immediately.
    func applyTitle() {
        guard let window else { return }
        if customTitle.isEmpty {
            window.titleVisibility = .hidden
        } else {
            window.title = customTitle
            window.titleVisibility = .visible
        }
    }
}
