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
    let fontPreferences: FontPreferences

    static let imageReferencePattern = try! NSRegularExpression(pattern: #"!\[[^\]]*\]\(([^)]+)\)"#)
    static let boldItalicAsteriskPattern = try! NSRegularExpression(pattern: #"\*\*\*([^*]+?)\*\*\*"#)
    static let boldItalicUnderscorePattern = try! NSRegularExpression(pattern: #"___([^_]+?)___"#)
    static let boldAsteriskPattern = try! NSRegularExpression(pattern: #"\*\*([^*]+?)\*\*"#)
    static let boldUnderscorePattern = try! NSRegularExpression(pattern: #"__([^_]+?)__"#)
    static let italicAsteriskPattern = try! NSRegularExpression(pattern: #"(?<!\*)\*([^*]+?)\*(?!\*)"#)
    static let italicUnderscorePattern = try! NSRegularExpression(pattern: #"(?<!_)_([^_]+?)_(?!_)"#)
    static let bulletListPattern = try! NSRegularExpression(pattern: #"^(\s*)([-*])(\s+)(.*)$"#)
    static let linkPattern = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)

    func makeNSView(context: Context) -> NSScrollView {
        let textView = DropHandlingTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isRichText = false
        textView.font = EditorFontSet(fontName: fontPreferences.fontName, fontSize: fontPreferences.fontSize).regular
        textView.textColor = .textColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
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

        Self.applyMarkdownStyling(in: textView, theme: theme, fontPreferences: fontPreferences)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? DropHandlingTextView else { return }
        textView.saveImage = saveImage
        textView.hotkeyPreferences = hotkeyPreferences
        if textView.string != text {
            textView.string = text
        }
        Self.applyMarkdownStyling(in: textView, theme: theme, fontPreferences: fontPreferences)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, theme: theme, fontPreferences: fontPreferences)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var theme: ThemeManager
        var fontPreferences: FontPreferences

        init(text: Binding<String>, theme: ThemeManager, fontPreferences: FontPreferences) {
            self.text = text
            self.theme = theme
            self.fontPreferences = fontPreferences
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? DropHandlingTextView else { return }
            text.wrappedValue = textView.string
            MarkdownTextView.applyMarkdownStyling(in: textView, theme: theme, fontPreferences: fontPreferences)
            textView.checkForLinkBracketClosure()
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
    static func applyMarkdownStyling(in textView: NSTextView, theme: ThemeManager, fontPreferences: FontPreferences) {
        guard let textStorage = textView.textStorage else { return }
        let fonts = EditorFontSet(fontName: fontPreferences.fontName, fontSize: fontPreferences.fontSize)
        let fullText = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: fullText.length)
        guard fullRange.length > 0 else { return }

        textStorage.beginEditing()
        textStorage.addAttribute(.foregroundColor, value: NSColor(theme.bodyColor), range: fullRange)
        textStorage.addAttribute(.font, value: fonts.regular, range: fullRange)

        fullText.enumerateSubstrings(in: fullRange, options: [.byLines]) { _, lineRange, _, _ in
            let line = fullText.substring(with: lineRange)
            if let level = headingLevel(of: line) {
                textStorage.addAttribute(.foregroundColor, value: NSColor(theme.color(forHeadingLevel: level)), range: lineRange)
            }
            applyBulletIndent(in: textStorage, line: line, lineRange: lineRange, fonts: fonts)
            applyEmphasis(in: textStorage, line: line, lineRange: lineRange, theme: theme, fonts: fonts)
            applyLinks(in: textStorage, line: line, lineRange: lineRange, theme: theme, fonts: fonts)
        }
        textStorage.endEditing()
    }

    /// Colors and underlines the `[text]` portion of a `[text](url)` link
    /// and attaches a real `.link` attribute so NSTextView's built-in
    /// Cmd+Click-to-open behavior works — no custom click handling, which
    /// this beta doesn't deliver reliably for our own overrides (see the
    /// bullet/hotkey code above). The `(url)` portion stays as literal
    /// visible text (never hidden — that needs riskier TextKit tricks we're
    /// avoiding after the image-attachment experience) but is shrunk and
    /// muted so it reads as metadata rather than competing with the link.
    private static func applyLinks(in textStorage: NSTextStorage, line: String, lineRange: NSRange, theme: ThemeManager, fonts: EditorFontSet) {
        let nsLine = line as NSString
        for match in linkPattern.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            let textRange = match.range(at: 1)
            let urlString = nsLine.substring(with: match.range(at: 2))
            guard let url = URL(string: urlString) else { continue }

            let globalTextRange = NSRange(location: lineRange.location + textRange.location, length: textRange.length)
            textStorage.addAttribute(.foregroundColor, value: NSColor(theme.linkColor), range: globalTextRange)
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: globalTextRange)
            textStorage.addAttribute(.link, value: url, range: globalTextRange)
            textStorage.addAttribute(.cursor, value: NSCursor.pointingHand, range: globalTextRange)

            let metadataStart = textRange.location + textRange.length + 1
            let metadataLength = match.range.length - (metadataStart - match.range.location)
            guard metadataLength > 0 else { continue }
            let globalMetadataRange = NSRange(location: lineRange.location + metadataStart, length: metadataLength)
            let mutedFont = NSFont(descriptor: fonts.regular.fontDescriptor, size: fonts.regular.pointSize * 0.75) ?? fonts.regular
            textStorage.addAttribute(.font, value: mutedFont, range: globalMetadataRange)
            textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: globalMetadataRange)
        }
    }

    /// Gives bullet lines a hanging indent (wrapped continuation lines align
    /// under the text, not the margin) and bolds the marker so it reads as
    /// a bullet at a glance — the literal "-"/"*" character is never
    /// replaced with a real "•" glyph, since that would require an
    /// NSTextAttachment-style substitution, which turned out to be an
    /// unreliable pattern in this beta SDK (see the image-attachment work).
    private static func applyBulletIndent(in textStorage: NSTextStorage, line: String, lineRange: NSRange, fonts: EditorFontSet) {
        guard let match = bulletListPattern.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else {
            return
        }

        let indentWidth = fonts.regular.pointSize * 2
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.headIndent = indentWidth
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)

        let markerRange = NSRange(location: lineRange.location + match.range(at: 2).location, length: match.range(at: 2).length)
        textStorage.addAttribute(.font, value: fonts.bold, range: markerRange)
    }

    private static func applyEmphasis(in textStorage: NSTextStorage, line: String, lineRange: NSRange, theme: ThemeManager, fonts: EditorFontSet) {
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

        apply(boldItalicAsteriskPattern, font: fonts.boldItalic, color: theme.boldColor)
        apply(boldItalicUnderscorePattern, font: fonts.boldItalic, color: theme.boldColor)
        apply(boldAsteriskPattern, font: fonts.bold, color: theme.boldColor)
        apply(boldUnderscorePattern, font: fonts.bold, color: theme.boldColor)
        apply(italicAsteriskPattern, font: fonts.italic, color: theme.italicColor)
        apply(italicUnderscorePattern, font: fonts.italic, color: theme.italicColor)
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

    private var linkPopover: NSPopover?

    /// Fires after every edit (via textDidChange, a proven-reliable hook in
    /// this beta — unlike our own click/keyDown overrides). If the just-
    /// typed character closed a "[text]" span that isn't already part of a
    /// "[text](url)" link, prompts for a URL to complete it.
    func checkForLinkBracketClosure() {
        let nsString = string as NSString
        let cursorLocation = selectedRange().location
        guard cursorLocation > 0,
              nsString.substring(with: NSRange(location: cursorLocation - 1, length: 1)) == "]" else {
            return
        }
        if cursorLocation < nsString.length,
           nsString.substring(with: NSRange(location: cursorLocation, length: 1)) == "(" {
            return
        }

        var openIndex: Int?
        var i = cursorLocation - 2
        while i >= 0 {
            let character = nsString.substring(with: NSRange(location: i, length: 1))
            if character == "\n" || character == "]" { break }
            if character == "[" {
                openIndex = i
                break
            }
            i -= 1
        }

        guard let openIndex else { return }
        let bracketRange = NSRange(location: openIndex, length: cursorLocation - openIndex)
        let linkText = nsString.substring(with: NSRange(location: openIndex + 1, length: cursorLocation - openIndex - 2))
        guard !linkText.isEmpty else { return }

        showLinkPopover(for: bracketRange, linkText: linkText)
    }

    private func showLinkPopover(for bracketRange: NSRange, linkText: String) {
        guard let layoutManager, let textContainer else { return }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: bracketRange, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let anchorRect = boundingRect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: LinkURLEntryView(linkText: linkText) { [weak self, weak popover] url in
                self?.insertLinkURL(url, afterBracketRange: bracketRange)
                popover?.performClose(nil)
            }
        )
        linkPopover = popover
        popover.show(relativeTo: anchorRect, of: self, preferredEdge: .maxY)
    }

    private func insertLinkURL(_ url: String, afterBracketRange bracketRange: NSRange) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let insertionPoint = bracketRange.location + bracketRange.length
        insertText("(\(trimmed))", replacementRange: NSRange(location: insertionPoint, length: 0))
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

/// Resolves the editor's regular/bold/italic/bold-italic fonts from the
/// user's chosen family + size. Falls back to the system monospaced font
/// if the chosen family name doesn't resolve (e.g. deleted since picked).
struct EditorFontSet {
    let regular: NSFont
    let bold: NSFont
    let italic: NSFont
    let boldItalic: NSFont

    init(fontName: String, fontSize: CGFloat) {
        let isSystemMonospaced = fontName == FontPreferences.systemMonospacedSentinel
        let base = isSystemMonospaced
            ? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            : (NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular))
        regular = base

        bold = isSystemMonospaced
            ? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
            : (NSFont(descriptor: base.fontDescriptor.withSymbolicTraits(.bold), size: fontSize) ?? base)

        italic = NSFont(descriptor: base.fontDescriptor.withSymbolicTraits(.italic), size: fontSize) ?? base
        boldItalic = NSFont(descriptor: base.fontDescriptor.withSymbolicTraits([.bold, .italic]), size: fontSize) ?? bold
    }
}

/// Popover content shown when a "[link text]" span is just closed —
/// prompts for the URL, then hands it back via `onSubmit`. Cancelling
/// (clicking away — the popover is .transient) simply never calls back,
/// leaving the bracketed text as plain text.
private struct LinkURLEntryView: View {
    let linkText: String
    let onSubmit: (String) -> Void

    @State private var url: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Link URL for \"\(linkText)\"")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("https://example.com", text: $url)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .focused($isFocused)
                .onSubmit { onSubmit(url) }
            HStack {
                Spacer()
                Button("Add Link") {
                    onSubmit(url)
                }
                .buttonStyle(.borderedProminent)
                .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(12)
        .onAppear { isFocused = true }
    }
}
