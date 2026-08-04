//
//  MarkdownTextView.swift
//  Nibora
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Plain-text markdown editor backed by NSTextView. The backing string is
/// always exactly what gets written to disk — headings are colored by level
/// per the user's theme and bold/italic spans render with real font traits,
/// but this is purely a display layer on top; no character is ever added,
/// removed, or reflowed for styling. `![](...)` image references stay
/// literal text; AttachmentsStripView (shown below this editor) handles
/// previewing them.
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    let baseDirectory: URL
    let saveImage: (NSImage, String?) -> String?
    let theme: ThemeManager
    let hotkeyPreferences: TimestampHotkeyPreferences

    static let editorFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let boldFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
    static let italicFont: NSFont = {
        let descriptor = editorFont.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: editorFont.pointSize) ?? editorFont
    }()
    static let boldItalicFont: NSFont = {
        let descriptor = editorFont.fontDescriptor.withSymbolicTraits([.bold, .italic])
        return NSFont(descriptor: descriptor, size: editorFont.pointSize) ?? boldFont
    }()

    static let imageReferencePattern = try! NSRegularExpression(pattern: #"!\[[^\]]*\]\(([^)]+)\)"#)
    static let boldItalicAsteriskPattern = try! NSRegularExpression(pattern: #"\*\*\*([^*]+?)\*\*\*"#)
    static let boldItalicUnderscorePattern = try! NSRegularExpression(pattern: #"___([^_]+?)___"#)
    static let boldAsteriskPattern = try! NSRegularExpression(pattern: #"\*\*([^*]+?)\*\*"#)
    static let boldUnderscorePattern = try! NSRegularExpression(pattern: #"__([^_]+?)__"#)
    static let italicAsteriskPattern = try! NSRegularExpression(pattern: #"(?<!\*)\*([^*]+?)\*(?!\*)"#)
    static let italicUnderscorePattern = try! NSRegularExpression(pattern: #"(?<!_)_([^_]+?)_(?!_)"#)
    static let bulletListPattern = try! NSRegularExpression(pattern: #"^(\s*)([-*])(\s+)(.*)$"#)

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
        textView.hotkeyPreferences = hotkeyPreferences

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        Self.applyMarkdownStyling(in: textView, theme: theme)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? DropHandlingTextView else { return }
        textView.saveImage = saveImage
        textView.hotkeyPreferences = hotkeyPreferences
        if textView.string != text {
            textView.string = text
        }
        Self.applyMarkdownStyling(in: textView, theme: theme)
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
            MarkdownTextView.applyMarkdownStyling(in: textView, theme: theme)
        }

        /// Intercepts Return via the modern text-input command path rather
        /// than overriding NSResponder.insertNewline(_:) directly — this
        /// beta's TextKit 2 doesn't reliably deliver the classic override,
        /// but doCommandBy: is the documented interception point for
        /// NSTextInputClient-driven text views.
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            return MarkdownTextView.handleBulletContinuation(in: textView)
        }
    }

    /// If the cursor is at the end of a "- item" (or "* item") line, Return
    /// continues the list with a fresh marker; on an empty "- " line, Return
    /// removes the marker and exits the list instead of continuing forever.
    /// Returns false (unhandled) when the line isn't a bullet line at all.
    @discardableResult
    static func handleBulletContinuation(in textView: NSTextView) -> Bool {
        let nsString = textView.string as NSString
        let cursorLocation = textView.selectedRange().location
        let lineRange = nsString.lineRange(for: NSRange(location: cursorLocation, length: 0))
        let prefixRange = NSRange(location: lineRange.location, length: cursorLocation - lineRange.location)
        let linePrefix = nsString.substring(with: prefixRange) as NSString

        guard let match = bulletListPattern.firstMatch(in: linePrefix as String, range: NSRange(location: 0, length: linePrefix.length)) else {
            return false
        }

        let indent = linePrefix.substring(with: match.range(at: 1))
        let marker = linePrefix.substring(with: match.range(at: 2))
        let content = linePrefix.substring(with: match.range(at: 4))

        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            textView.insertText("", replacementRange: prefixRange)
            textView.insertText("\n", replacementRange: textView.selectedRange())
        } else {
            textView.insertText("\n\(indent)\(marker) ", replacementRange: textView.selectedRange())
        }
        return true
    }

    /// Recolors every line by its heading level and applies real bold/italic
    /// font traits to `**`/`__`/`*`/`_` spans — all via attribute-only edits,
    /// never touching the characters themselves, so cursor position and undo
    /// history are untouched.
    static func applyMarkdownStyling(in textView: NSTextView, theme: ThemeManager) {
        guard let textStorage = textView.textStorage else { return }
        let fullText = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: fullText.length)
        guard fullRange.length > 0 else { return }

        textStorage.beginEditing()
        textStorage.addAttribute(.foregroundColor, value: NSColor(theme.bodyColor), range: fullRange)
        textStorage.addAttribute(.font, value: editorFont, range: fullRange)

        fullText.enumerateSubstrings(in: fullRange, options: [.byLines]) { _, lineRange, _, _ in
            let line = fullText.substring(with: lineRange)
            if let level = headingLevel(of: line) {
                textStorage.addAttribute(.foregroundColor, value: NSColor(theme.color(forHeadingLevel: level)), range: lineRange)
            }
            applyBulletIndent(in: textStorage, line: line, lineRange: lineRange)
            applyEmphasis(in: textStorage, line: line, lineRange: lineRange, theme: theme)
        }
        textStorage.endEditing()
    }

    /// Gives bullet lines a hanging indent (wrapped continuation lines align
    /// under the text, not the margin) and bolds the marker so it reads as
    /// a bullet at a glance — the literal "-"/"*" character is never
    /// replaced with a real "•" glyph, since that would require an
    /// NSTextAttachment-style substitution, which turned out to be an
    /// unreliable pattern in this beta SDK (see the image-attachment work).
    private static func applyBulletIndent(in textStorage: NSTextStorage, line: String, lineRange: NSRange) {
        guard let match = bulletListPattern.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else {
            return
        }

        let indentWidth = editorFont.pointSize * 2
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.headIndent = indentWidth
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)

        let markerRange = NSRange(location: lineRange.location + match.range(at: 2).location, length: match.range(at: 2).length)
        textStorage.addAttribute(.font, value: boldFont, range: markerRange)
    }

    private static func applyEmphasis(in textStorage: NSTextStorage, line: String, lineRange: NSRange, theme: ThemeManager) {
        let nsLine = line as NSString
        let lineSearchRange = NSRange(location: 0, length: nsLine.length)
        var claimedRanges: [NSRange] = []

        func apply(_ pattern: NSRegularExpression, font: NSFont, color: Color) {
            for match in pattern.matches(in: line, range: lineSearchRange) {
                let localRange = match.range
                guard !claimedRanges.contains(where: { NSIntersectionRange($0, localRange).length > 0 }) else { continue }
                claimedRanges.append(localRange)
                let globalRange = NSRange(location: lineRange.location + localRange.location, length: localRange.length)
                textStorage.addAttribute(.font, value: font, range: globalRange)
                textStorage.addAttribute(.foregroundColor, value: NSColor(color), range: globalRange)
            }
        }

        apply(boldItalicAsteriskPattern, font: boldItalicFont, color: theme.boldColor)
        apply(boldItalicUnderscorePattern, font: boldItalicFont, color: theme.boldColor)
        apply(boldAsteriskPattern, font: boldFont, color: theme.boldColor)
        apply(boldUnderscorePattern, font: boldFont, color: theme.boldColor)
        apply(italicAsteriskPattern, font: italicFont, color: theme.italicColor)
        apply(italicUnderscorePattern, font: italicFont, color: theme.italicColor)
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
    var hotkeyPreferences: TimestampHotkeyPreferences?

    private var hotkeyMonitor: Any?
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Uses a local event monitor rather than overriding a responder method
    /// like performKeyEquivalent(_:) — this beta's TextKit 2 has already
    /// shown it doesn't reliably deliver classic overrides (see mouseDown/
    /// insertNewline above), so the monitor is the reliable path.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeHotkeyMonitor()
        guard window != nil else { return }
        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let hotkeyPreferences = self.hotkeyPreferences,
                  hotkeyPreferences.matches(event),
                  self.window?.firstResponder === self else {
                return event
            }
            self.insertTimestamp()
            return nil
        }
    }

    deinit {
        if let hotkeyMonitor {
            NSEvent.removeMonitor(hotkeyMonitor)
        }
    }

    private func removeHotkeyMonitor() {
        if let hotkeyMonitor {
            NSEvent.removeMonitor(hotkeyMonitor)
        }
        hotkeyMonitor = nil
    }

    private func insertTimestamp() {
        let timestamp = Self.timestampFormatter.string(from: Date())
        insertText("\(timestamp) - ", replacementRange: selectedRange())
    }

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
