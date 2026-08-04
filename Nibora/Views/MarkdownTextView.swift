//
//  MarkdownTextView.swift
//  Nibora
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Plain-text markdown editor backed by NSTextView. The backing string is
/// always exactly what gets written to disk — headings are colored by level
/// per the user's theme, but this is purely a display attribute layered on
/// top; no character is ever added, removed, or reflowed for styling.
/// `![](...)` image references stay literal text; AttachmentsStripView
/// (shown below this editor) handles previewing them.
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    let baseDirectory: URL
    let saveImage: (NSImage, String?) -> String?
    let theme: ThemeManager

    static let editorFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let imageReferencePattern = try! NSRegularExpression(pattern: #"!\[[^\]]*\]\(([^)]+)\)"#)

    func makeNSView(context: Context) -> NSScrollView {
        let textView = DropHandlingTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isRichText = false
        textView.font = Self.editorFont
        textView.textColor = .textColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.string = text
        textView.allowsUndo = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        textView.saveImage = saveImage

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        Self.applyHeadingColors(in: textView, theme: theme)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? DropHandlingTextView else { return }
        textView.saveImage = saveImage
        if textView.string != text {
            textView.string = text
        }
        Self.applyHeadingColors(in: textView, theme: theme)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, theme: theme)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var theme: ThemeManager

        init(text: Binding<String>, theme: ThemeManager) {
            self.text = text
            self.theme = theme
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            MarkdownTextView.applyHeadingColors(in: textView, theme: theme)
        }
    }

    /// Recolors every line by its heading level (or body color if none),
    /// via attribute-only edits — never touches the characters themselves,
    /// so cursor position and undo history are untouched.
    static func applyHeadingColors(in textView: NSTextView, theme: ThemeManager) {
        guard let textStorage = textView.textStorage else { return }
        let fullText = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: fullText.length)
        guard fullRange.length > 0 else { return }

        textStorage.beginEditing()
        textStorage.addAttribute(.foregroundColor, value: NSColor(theme.bodyColor), range: fullRange)

        fullText.enumerateSubstrings(in: fullRange, options: [.byLines]) { _, lineRange, _, _ in
            let line = fullText.substring(with: lineRange)
            guard let level = headingLevel(of: line) else { return }
            textStorage.addAttribute(.foregroundColor, value: NSColor(theme.color(forHeadingLevel: level)), range: lineRange)
        }
        textStorage.endEditing()
    }

    private static func headingLevel(of line: String) -> Int? {
        var level = 0
        for character in line {
            if character == "#" {
                level += 1
            } else {
                break
            }
        }
        guard level > 0, level <= 6, line.count > level, line[line.index(line.startIndex, offsetBy: level)] == " " else {
            return nil
        }
        return level
    }
}

/// NSTextView subclass that intercepts image drags/pastes (Finder or Photos)
/// and routes them through `saveImage` so they land as real vault files
/// referenced by a plain `![]()` link inserted as literal text.
final class DropHandlingTextView: NSTextView {
    var saveImage: ((NSImage, String?) -> String?)?

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if let saveImage, pasteboardContainsImage(pasteboard) {
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
               let imageURL = urls.first(where: { isImageFile($0) }),
               let image = NSImage(contentsOf: imageURL) {
                insertImageLink(image, suggestedName: imageURL.lastPathComponent, at: selectedRange().location, save: saveImage)
                return
            }
            if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
               let image = images.first {
                insertImageLink(image, suggestedName: nil, at: selectedRange().location, save: saveImage)
                return
            }
        }
        super.paste(sender)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if pasteboardContainsImage(sender.draggingPasteboard) { return .copy }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard pasteboardContainsImage(pasteboard), let saveImage else {
            return super.performDragOperation(sender)
        }

        let dropPoint = convert(sender.draggingLocation, from: nil)
        let insertionIndex = characterIndexForInsertion(at: dropPoint)

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let imageURL = urls.first(where: { isImageFile($0) }),
           let image = NSImage(contentsOf: imageURL) {
            insertImageLink(image, suggestedName: imageURL.lastPathComponent, at: insertionIndex, save: saveImage)
            return true
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            insertImageLink(image, suggestedName: nil, at: insertionIndex, save: saveImage)
            return true
        }

        return super.performDragOperation(sender)
    }

    private func insertImageLink(_ image: NSImage, suggestedName: String?, at index: Int, save: (NSImage, String?) -> String?) {
        guard let relativePath = save(image, suggestedName), let textStorage else { return }
        let markdown = "![](\(relativePath))"
        textStorage.replaceCharacters(in: NSRange(location: index, length: 0), with: markdown)
        didChangeText()
    }

    private func pasteboardContainsImage(_ pasteboard: NSPasteboard) -> Bool {
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) { return true }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            return urls.contains { isImageFile($0) }
        }
        return false
    }

    private func isImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }
}
