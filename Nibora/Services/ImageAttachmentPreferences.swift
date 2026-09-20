//
//  ImageAttachmentPreferences.swift
//  Nibora
//

import Foundation

/// Caps how large an attached photo's enlarged preview popover appears when
/// its thumbnail (in AttachmentsStripView) is clicked — the image's long
/// edge is scaled to at most this value, never upscaled past its native
/// size.
@Observable
final class ImageAttachmentPreferences {
    var previewMaxDimension: Double {
        didSet { UserDefaults.standard.set(previewMaxDimension, forKey: Keys.previewMaxDimension) }
    }
    /// Whether AttachmentsStripView renders below the editor at all —
    /// toggled from EntryEditorView's toolbar, remembered across launches.
    var isStripVisible: Bool {
        didSet { UserDefaults.standard.set(isStripVisible, forKey: Keys.isStripVisible) }
    }

    static let dimensionRange: ClosedRange<Double> = 200...900
    static let defaultDimension: Double = 400

    private enum Keys {
        static let previewMaxDimension = "imageAttachmentPreferences.previewMaxDimension"
        static let isStripVisible = "imageAttachmentPreferences.isStripVisible"
    }

    init() {
        let stored = UserDefaults.standard.double(forKey: Keys.previewMaxDimension)
        previewMaxDimension = stored == 0 ? Self.defaultDimension : stored
        isStripVisible = UserDefaults.standard.object(forKey: Keys.isStripVisible) as? Bool ?? true
    }
}
