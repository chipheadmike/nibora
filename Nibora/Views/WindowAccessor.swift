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
    var hidesTitle: Bool = false

    func makeNSView(context: Context) -> WindowAccessorView {
        let view = WindowAccessorView()
        view.autosaveName = autosaveName
        view.hidesTitle = hidesTitle
        return view
    }

    func updateNSView(_ nsView: WindowAccessorView, context: Context) {
        nsView.autosaveName = autosaveName
        nsView.hidesTitle = hidesTitle
    }
}

final class WindowAccessorView: NSView {
    var autosaveName: String = ""
    var hidesTitle: Bool = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        if !autosaveName.isEmpty {
            window.setFrameAutosaveName(autosaveName)
        }
        if hidesTitle {
            window.titleVisibility = .hidden
        }
    }
}
