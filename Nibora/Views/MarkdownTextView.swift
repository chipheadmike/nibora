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
    let isFocusModeEnabled: Bool
    let onWikilinkClick: (String) -> Void

    static let imageReferencePattern = try! NSRegularExpression(pattern: #"!\[[^\]]*\]\(([^)]+)\)"#)
    static let boldItalicAsteriskPattern = try! NSRegularExpression(pattern: #"\*\*\*([^*]+?)\*\*\*"#)
    static let boldItalicUnderscorePattern = try! NSRegularExpression(pattern: #"___([^_]+?)___"#)
    static let boldAsteriskPattern = try! NSRegularExpression(pattern: #"\*\*([^*]+?)\*\*"#)
    static let boldUnderscorePattern = try! NSRegularExpression(pattern: #"__([^_]+?)__"#)
    static let italicAsteriskPattern = try! NSRegularExpression(pattern: #"(?<!\*)\*([^*]+?)\*(?!\*)"#)
    static let italicUnderscorePattern = try! NSRegularExpression(pattern: #"(?<!_)_([^_]+?)_(?!_)"#)
    static let bulletListPattern = try! NSRegularExpression(pattern: #"^(\s*)([-*])(\s+)(.*)$"#)
    static let numberedListPattern = try! NSRegularExpression(pattern: #"^(\s*)(\d+)([.)])(\s+)(.*)$"#)
    static let linkPattern = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)
    static let inlineCodePattern = try! NSRegularExpression(pattern: #"`([^`\n]+)`"#)
    static let strikethroughPattern = try! NSRegularExpression(pattern: #"~~([^~\n]+?)~~"#)
    static let highlightPattern = try! NSRegularExpression(pattern: #"==([^=\n]+?)=="#)
    static let taskListPattern = try! NSRegularExpression(pattern: #"^(\s*)([-*])(\s+)\[([ xX])\](\s+)(.*)$"#)
    static let taskListToggleScheme = "nibora-checkbox"
    static let blockquotePattern = try! NSRegularExpression(pattern: #"^(\s*)(>)(\s?)(.*)$"#)
    static let horizontalRulePattern = try! NSRegularExpression(pattern: #"^\s*(-{3,}|\*{3,}|_{3,})\s*$"#)
    /// Requires a word character immediately after "#" — this is what keeps
    /// it from ever matching a heading marker ("# Heading" has a space
    /// there), so tags and headings never fight over the same "#".
    static let tagPattern = try! NSRegularExpression(pattern: #"#[A-Za-z0-9][A-Za-z0-9_-]*"#)
    /// "[[Entry Title]]" — a link to another entry by its title, distinct
    /// from "[text](url)" web links (see applyLinks/applyWikilink below).
    static let wikilinkPattern = try! NSRegularExpression(pattern: #"\[\[([^\]\n]+)\]\]"#)
    static let wikilinkScheme = "nibora-wikilink"

    /// Single combined pattern for MarkdownPreviewView's inline rendering —
    /// alternation order matters: code/link/wikilink come first so their
    /// delimiter characters (backtick, brackets) never get mis-read as
    /// emphasis markers, matching how the editor's own applyInlineCode runs
    /// last to "win" on overlaps. One numbered group per alternative, in
    /// the same left-to-right order they appear below (used positionally
    /// in inlineAttributedText, not by name).
    static let previewInlinePattern = try! NSRegularExpression(pattern:
        #"`([^`\n]+)`"# + "|" +
        #"\[([^\]]+)\]\(([^)]+)\)"# + "|" +
        #"\[\[([^\]\n]+)\]\]"# + "|" +
        #"\*\*\*([^*]+?)\*\*\*"# + "|" +
        #"___([^_]+?)___"# + "|" +
        #"\*\*([^*]+?)\*\*"# + "|" +
        #"__([^_]+?)__"# + "|" +
        #"(?<!\*)\*([^*]+?)\*(?!\*)"# + "|" +
        #"(?<!_)_([^_]+?)_(?!_)"# + "|" +
        #"~~([^~\n]+?)~~"# + "|" +
        #"==([^=\n]+?)=="# + "|" +
        #"#[A-Za-z0-9][A-Za-z0-9_-]*"#
    )

    /// Renders one line's inline markdown into an NSAttributedString with
    /// the markup delimiters actually removed — unlike applyMarkdownStyling
    /// (which only ever adds attributes, never touches characters, since
    /// that string is bound to what's written to disk), this is a
    /// throwaway rendering built fresh from the current body text each
    /// call and never fed back into the editable text. Single left-to-right
    /// pass: no recursion into a matched span's own content, so e.g. a link
    /// inside bold text won't itself render as a link — an accepted
    /// simplification for a preview pane, not a full CommonMark renderer.
    static func inlineAttributedText(from line: String, theme: ThemeManager, fonts: EditorFontSet) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let nsLine = line as NSString
        let baseAttributes: [NSAttributedString.Key: Any] = [.font: fonts.regular, .foregroundColor: NSColor(theme.bodyColor)]
        var cursor = 0

        func appendPlain(_ range: NSRange) {
            guard range.length > 0 else { return }
            result.append(NSAttributedString(string: nsLine.substring(with: range), attributes: baseAttributes))
        }

        func appendStyled(_ text: String, font: NSFont, color: Color) {
            result.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor(color)]))
        }

        for match in previewInlinePattern.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            if match.range.location > cursor {
                appendPlain(NSRange(location: cursor, length: match.range.location - cursor))
            }

            if match.range(at: 1).location != NSNotFound {
                let content = nsLine.substring(with: match.range(at: 1))
                result.append(NSAttributedString(string: content, attributes: [
                    .font: fonts.code,
                    .foregroundColor: NSColor(theme.codeColor),
                    .backgroundColor: NSColor.textBackgroundColor.blended(withFraction: 0.08, of: .labelColor) ?? NSColor.textBackgroundColor
                ]))
            } else if match.range(at: 2).location != NSNotFound {
                let text = nsLine.substring(with: match.range(at: 2))
                let urlString = nsLine.substring(with: match.range(at: 3))
                var attrs: [NSAttributedString.Key: Any] = [.font: fonts.regular, .foregroundColor: NSColor(theme.linkColor), .underlineStyle: NSUnderlineStyle.single.rawValue]
                if let url = URL(string: urlString) { attrs[.link] = url }
                result.append(NSAttributedString(string: text, attributes: attrs))
            } else if match.range(at: 4).location != NSNotFound {
                let titleText = nsLine.substring(with: match.range(at: 4))
                var attrs: [NSAttributedString.Key: Any] = [.font: fonts.regular, .foregroundColor: NSColor(theme.wikilinkColor), .underlineStyle: NSUnderlineStyle.single.rawValue]
                if let encoded = titleText.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let url = URL(string: "\(wikilinkScheme):///\(encoded)") {
                    attrs[.link] = url
                }
                result.append(NSAttributedString(string: titleText, attributes: attrs))
            } else if match.range(at: 5).location != NSNotFound {
                appendStyled(nsLine.substring(with: match.range(at: 5)), font: fonts.boldItalic, color: theme.boldColor)
            } else if match.range(at: 6).location != NSNotFound {
                appendStyled(nsLine.substring(with: match.range(at: 6)), font: fonts.boldItalic, color: theme.boldColor)
            } else if match.range(at: 7).location != NSNotFound {
                appendStyled(nsLine.substring(with: match.range(at: 7)), font: fonts.bold, color: theme.boldColor)
            } else if match.range(at: 8).location != NSNotFound {
                appendStyled(nsLine.substring(with: match.range(at: 8)), font: fonts.bold, color: theme.boldColor)
            } else if match.range(at: 9).location != NSNotFound {
                appendStyled(nsLine.substring(with: match.range(at: 9)), font: fonts.italic, color: theme.italicColor)
            } else if match.range(at: 10).location != NSNotFound {
                appendStyled(nsLine.substring(with: match.range(at: 10)), font: fonts.italic, color: theme.italicColor)
            } else if match.range(at: 11).location != NSNotFound {
                let content = nsLine.substring(with: match.range(at: 11))
                result.append(NSAttributedString(string: content, attributes: [.font: fonts.regular, .foregroundColor: NSColor(theme.strikethroughColor), .strikethroughStyle: NSUnderlineStyle.single.rawValue]))
            } else if match.range(at: 12).location != NSNotFound {
                let content = nsLine.substring(with: match.range(at: 12))
                result.append(NSAttributedString(string: content, attributes: [.font: fonts.regular, .foregroundColor: NSColor(theme.bodyColor), .backgroundColor: NSColor(theme.highlightColor)]))
            } else {
                let content = nsLine.substring(with: match.range)
                result.append(NSAttributedString(string: content, attributes: [.font: fonts.bold, .foregroundColor: NSColor(theme.tagColor)]))
            }

            cursor = match.range.location + match.range.length
        }

        appendPlain(NSRange(location: cursor, length: nsLine.length - cursor))
        return result
    }

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

        Self.applyMarkdownStyling(in: textView, theme: theme, fontPreferences: fontPreferences, isFocusModeEnabled: isFocusModeEnabled)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? DropHandlingTextView else { return }
        textView.saveImage = saveImage
        textView.hotkeyPreferences = hotkeyPreferences
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.isFocusModeEnabled = isFocusModeEnabled
        context.coordinator.onWikilinkClick = onWikilinkClick
        Self.applyMarkdownStyling(in: textView, theme: theme, fontPreferences: fontPreferences, isFocusModeEnabled: isFocusModeEnabled)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, theme: theme, fontPreferences: fontPreferences, isFocusModeEnabled: isFocusModeEnabled, onWikilinkClick: onWikilinkClick)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var theme: ThemeManager
        var fontPreferences: FontPreferences
        var isFocusModeEnabled: Bool
        var onWikilinkClick: (String) -> Void

        init(text: Binding<String>, theme: ThemeManager, fontPreferences: FontPreferences, isFocusModeEnabled: Bool, onWikilinkClick: @escaping (String) -> Void) {
            self.text = text
            self.theme = theme
            self.fontPreferences = fontPreferences
            self.isFocusModeEnabled = isFocusModeEnabled
            self.onWikilinkClick = onWikilinkClick
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? DropHandlingTextView else { return }
            text.wrappedValue = textView.string
            MarkdownTextView.applyMarkdownStyling(in: textView, theme: theme, fontPreferences: fontPreferences, isFocusModeEnabled: isFocusModeEnabled)
            textView.checkForLinkBracketClosure()
        }

        /// Re-dims/un-dims paragraphs as the cursor moves, independent of any
        /// text edit — textViewDidChangeSelection is the standard AppKit
        /// callback for this, unrelated to the TextKit 2 command-routing
        /// issues noted elsewhere in this file.
        func textViewDidChangeSelection(_ notification: Notification) {
            guard isFocusModeEnabled, let textView = notification.object as? DropHandlingTextView else { return }
            MarkdownTextView.applyMarkdownStyling(in: textView, theme: theme, fontPreferences: fontPreferences, isFocusModeEnabled: isFocusModeEnabled)
        }

        /// Intercepts Return via the modern text-input command path rather
        /// than overriding NSResponder.insertNewline(_:) directly — this
        /// beta's TextKit 2 doesn't reliably deliver the classic override,
        /// but doCommandBy: is the documented interception point for
        /// NSTextInputClient-driven text views.
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            return MarkdownTextView.handleListContinuation(in: textView)
        }

        /// Task list checkboxes and entry wikilinks are both tagged with a
        /// private `.link` attribute (nibora-checkbox:// / nibora-wikilink://
        /// — see applyTaskListCheckbox/applyWikilink) so they piggyback on
        /// NSTextView's native Cmd+Click-on-link handling — the only
        /// click-driven interaction that's proven reliable this beta.
        /// Real markdown links (http/https) fall through to the default
        /// open-in-browser behavior by returning false.
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL else { return false }
            if url.scheme == MarkdownTextView.taskListToggleScheme {
                MarkdownTextView.toggleTaskListCheckbox(in: textView, at: charIndex)
                return true
            }
            if url.scheme == MarkdownTextView.wikilinkScheme {
                let rawTitle = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
                onWikilinkClick(rawTitle.removingPercentEncoding ?? rawTitle)
                return true
            }
            return false
        }
    }

    @discardableResult
    static func handleListContinuation(in textView: NSTextView) -> Bool {
        handleBulletContinuation(in: textView) || handleNumberedListContinuation(in: textView)
    }

    /// If the cursor is at the end of a "- item" (or "* item") line, Return
    /// continues the list with a fresh marker; on an empty "- " line, Return
    /// removes the marker and exits the list instead of continuing forever.
    /// Returns false (unhandled) when the line isn't a bullet line at all.
    @discardableResult
    private static func handleBulletContinuation(in textView: NSTextView) -> Bool {
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

    /// Same idea as bullet continuation, but for "1. item" / "1) item"
    /// lines — continuing increments the number instead of repeating a
    /// fixed marker.
    @discardableResult
    private static func handleNumberedListContinuation(in textView: NSTextView) -> Bool {
        let nsString = textView.string as NSString
        let cursorLocation = textView.selectedRange().location
        let lineRange = nsString.lineRange(for: NSRange(location: cursorLocation, length: 0))
        let prefixRange = NSRange(location: lineRange.location, length: cursorLocation - lineRange.location)
        let linePrefix = nsString.substring(with: prefixRange) as NSString

        guard let match = numberedListPattern.firstMatch(in: linePrefix as String, range: NSRange(location: 0, length: linePrefix.length)) else {
            return false
        }

        let indent = linePrefix.substring(with: match.range(at: 1))
        let numberString = linePrefix.substring(with: match.range(at: 2))
        let delimiter = linePrefix.substring(with: match.range(at: 3))
        let content = linePrefix.substring(with: match.range(at: 5))

        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            textView.insertText("", replacementRange: prefixRange)
            textView.insertText("\n", replacementRange: textView.selectedRange())
        } else {
            let nextNumber = (Int(numberString) ?? 0) + 1
            textView.insertText("\n\(indent)\(nextNumber)\(delimiter) ", replacementRange: textView.selectedRange())
        }
        return true
    }

    /// Recolors every line by its heading level and applies real bold/italic
    /// font traits to `**`/`__`/`*`/`_` spans — all via attribute-only edits,
    /// never touching the characters themselves, so cursor position and undo
    /// history are untouched.
    static func applyMarkdownStyling(in textView: NSTextView, theme: ThemeManager, fontPreferences: FontPreferences, isFocusModeEnabled: Bool = false) {
        guard let textStorage = textView.textStorage else { return }
        let fonts = EditorFontSet(fontName: fontPreferences.fontName, fontSize: fontPreferences.fontSize, codeFontName: fontPreferences.codeFontName)
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
            applyNumberedListIndent(in: textStorage, line: line, lineRange: lineRange, fonts: fonts)
            applyTaskListCheckbox(in: textStorage, line: line, lineRange: lineRange, theme: theme, fonts: fonts)
            applyBlockquote(in: textStorage, line: line, lineRange: lineRange, theme: theme, fonts: fonts)
            applyHorizontalRule(in: textStorage, line: line, lineRange: lineRange, theme: theme, fonts: fonts)
            applyTag(in: textStorage, line: line, lineRange: lineRange, theme: theme, fonts: fonts)
            applyEmphasis(in: textStorage, line: line, lineRange: lineRange, theme: theme, fonts: fonts)
            applyLinks(in: textStorage, line: line, lineRange: lineRange, theme: theme, fonts: fonts)
            applyWikilink(in: textStorage, line: line, lineRange: lineRange, theme: theme)
            // Applied last so code spans win over any overlapping bold/italic/
            // link styling within backticks, matching standard markdown
            // semantics (code content isn't further interpreted as markup).
            applyInlineCode(in: textStorage, line: line, lineRange: lineRange, theme: theme, fonts: fonts)
            applyStrikethrough(in: textStorage, line: line, lineRange: lineRange, theme: theme)
            applyHighlight(in: textStorage, line: line, lineRange: lineRange, theme: theme)
        }

        // Applied after all other styling so it uniformly mutes everything
        // outside the focused paragraph regardless of its normal color
        // (heading, link, code, etc.) — a flat dim rather than per-element.
        if isFocusModeEnabled {
            let focusedRange = focusedParagraphRange(in: textView)
            let dimColor = NSColor(theme.bodyColor).withAlphaComponent(0.25)
            if focusedRange.location > fullRange.location {
                textStorage.addAttribute(.foregroundColor, value: dimColor, range: NSRange(location: fullRange.location, length: focusedRange.location - fullRange.location))
            }
            let afterFocusedStart = focusedRange.location + focusedRange.length
            let fullEnd = fullRange.location + fullRange.length
            if afterFocusedStart < fullEnd {
                textStorage.addAttribute(.foregroundColor, value: dimColor, range: NSRange(location: afterFocusedStart, length: fullEnd - afterFocusedStart))
            }
        }

        textStorage.endEditing()
    }

    /// The contiguous run of non-blank lines surrounding the cursor — a
    /// blank line on either side marks the paragraph boundary. Used by focus
    /// mode to decide what stays fully visible while everything else dims.
    private static func focusedParagraphRange(in textView: NSTextView) -> NSRange {
        let nsString = textView.string as NSString
        let cursorLocation = min(textView.selectedRange().location, nsString.length)
        let cursorLineRange = nsString.lineRange(for: NSRange(location: cursorLocation, length: 0))

        func isBlank(_ range: NSRange) -> Bool {
            nsString.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var start = cursorLineRange.location
        while start > 0 {
            let previousLineRange = nsString.lineRange(for: NSRange(location: start - 1, length: 0))
            if isBlank(previousLineRange) { break }
            start = previousLineRange.location
        }

        var end = cursorLineRange.location + cursorLineRange.length
        while end < nsString.length {
            let nextLineRange = nsString.lineRange(for: NSRange(location: end, length: 0))
            if isBlank(nextLineRange) { break }
            end = nextLineRange.location + nextLineRange.length
        }

        return NSRange(location: start, length: end - start)
    }

    /// Colors, monospaces (via the user's chosen code font), and gives a
    /// subtle background pill to `` `code` `` spans.
    private static func applyInlineCode(in textStorage: NSTextStorage, line: String, lineRange: NSRange, theme: ThemeManager, fonts: EditorFontSet) {
        let nsLine = line as NSString
        for match in inlineCodePattern.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            let globalRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
            textStorage.addAttribute(.font, value: fonts.code, range: globalRange)
            textStorage.addAttribute(.foregroundColor, value: NSColor(theme.codeColor), range: globalRange)
            textStorage.addAttribute(.backgroundColor, value: NSColor.textBackgroundColor.blended(withFraction: 0.08, of: .labelColor) ?? NSColor.textBackgroundColor, range: globalRange)
        }
    }

    /// Strikes through and mutes `~~text~~` spans (marker included, matching
    /// how bold/italic/code color their whole match rather than just the
    /// inner text).
    private static func applyStrikethrough(in textStorage: NSTextStorage, line: String, lineRange: NSRange, theme: ThemeManager) {
        let nsLine = line as NSString
        for match in strikethroughPattern.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            let globalRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
            textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: globalRange)
            textStorage.addAttribute(.foregroundColor, value: NSColor(theme.strikethroughColor), range: globalRange)
        }
    }

    /// Gives `==text==` spans a highlighter-style background (marker
    /// included).
    private static func applyHighlight(in textStorage: NSTextStorage, line: String, lineRange: NSRange, theme: ThemeManager) {
        let nsLine = line as NSString
        for match in highlightPattern.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            let globalRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
            textStorage.addAttribute(.backgroundColor, value: NSColor(theme.highlightColor), range: globalRange)
        }
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

    /// Colors and underlines a "[[Entry Title]]" span and tags it with a
    /// `.link` attribute using a private `nibora-wikilink://` scheme — same
    /// Cmd+Click-routing trick as the task checkboxes, so clicking jumps to
    /// the matching entry via Coordinator.clickedOnLink rather than opening
    /// a URL. Styling doesn't check whether the title actually resolves to
    /// an entry (that lookup happens one layer up, in ContentView, where
    /// the full entry list already lives) — an unresolved link just no-ops
    /// when clicked rather than looking visually different.
    private static func applyWikilink(in textStorage: NSTextStorage, line: String, lineRange: NSRange, theme: ThemeManager) {
        let nsLine = line as NSString
        for match in wikilinkPattern.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            let globalRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
            let title = nsLine.substring(with: match.range(at: 1))

            textStorage.addAttribute(.foregroundColor, value: NSColor(theme.wikilinkColor), range: globalRange)
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: globalRange)

            guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "\(wikilinkScheme):///\(encodedTitle)") else { continue }
            textStorage.addAttribute(.link, value: url, range: globalRange)
            textStorage.addAttribute(.cursor, value: NSCursor.pointingHand, range: globalRange)
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

    /// Styles the "[ ]"/"[x]" span of a task list line and tags it with a
    /// `.link` attribute using a private `nibora-checkbox://` scheme —
    /// clicking it (Cmd+Click, same gesture the real markdown links already
    /// rely on) routes to `clickedOnLink` below rather than opening a URL.
    /// This reuses the one click-driven interaction proven reliable in this
    /// beta instead of a custom mouseDown/gesture-recognizer override, which
    /// has failed every other time it's been tried in this file. Checked
    /// items also get their content struck through, same visual language as
    /// `~~text~~`.
    private static func applyTaskListCheckbox(in textStorage: NSTextStorage, line: String, lineRange: NSRange, theme: ThemeManager, fonts: EditorFontSet) {
        let nsLine = line as NSString
        guard let match = taskListPattern.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else {
            return
        }

        let checkboxCharRange = match.range(at: 4)
        let isChecked = nsLine.substring(with: checkboxCharRange).lowercased() == "x"
        let bracketRange = NSRange(location: checkboxCharRange.location - 1, length: checkboxCharRange.length + 2)
        let globalBracketRange = NSRange(location: lineRange.location + bracketRange.location, length: bracketRange.length)

        textStorage.addAttribute(.font, value: fonts.bold, range: globalBracketRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor(isChecked ? theme.linkColor : theme.boldColor), range: globalBracketRange)
        if let toggleURL = URL(string: "\(taskListToggleScheme)://toggle") {
            textStorage.addAttribute(.link, value: toggleURL, range: globalBracketRange)
            textStorage.addAttribute(.cursor, value: NSCursor.pointingHand, range: globalBracketRange)
        }

        guard isChecked else { return }
        let contentRange = match.range(at: 6)
        guard contentRange.location != NSNotFound, contentRange.length > 0 else { return }
        let globalContentRange = NSRange(location: lineRange.location + contentRange.location, length: contentRange.length)
        textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: globalContentRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor(theme.strikethroughColor), range: globalContentRange)
    }

    /// Flips a task list item's "[ ]"/"[x]" character in place at the given
    /// character index (the click location handed back by `clickedOnLink`),
    /// then notifies the text view so the bound text updates and styling
    /// (including the new strikethrough state) reapplies.
    static func toggleTaskListCheckbox(in textView: NSTextView, at charIndex: Int) {
        guard let textStorage = textView.textStorage else { return }
        let nsString = textStorage.string as NSString
        guard charIndex >= 0, charIndex < nsString.length else { return }

        let lineRange = nsString.lineRange(for: NSRange(location: charIndex, length: 0))
        let line = nsString.substring(with: lineRange)
        guard let match = taskListPattern.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else {
            return
        }

        let checkboxCharRange = match.range(at: 4)
        let globalCheckboxRange = NSRange(location: lineRange.location + checkboxCharRange.location, length: checkboxCharRange.length)
        let isChecked = nsString.substring(with: globalCheckboxRange).lowercased() == "x"
        textStorage.replaceCharacters(in: globalCheckboxRange, with: isChecked ? " " : "x")
        textView.didChangeText()
    }

    /// Indents and mutes/italicizes "> quoted" lines. Unlike the bullet/
    /// numbered indents (marker at the margin, wrapped text hanging under
    /// it), a blockquote indents uniformly — first line and wrapped
    /// continuation lines both sit at the same offset. No vertical accent
    /// bar: that would need real custom drawing (an NSTextAttachment cell or
    /// overriding draw), which has proven unreliable for anything
    /// click/paint-related in this beta, so this stays attribute-only like
    /// everything else here.
    private static func applyBlockquote(in textStorage: NSTextStorage, line: String, lineRange: NSRange, theme: ThemeManager, fonts: EditorFontSet) {
        guard blockquotePattern.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil else {
            return
        }

        let indentWidth = fonts.regular.pointSize * 1.5
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = indentWidth
        paragraphStyle.headIndent = indentWidth
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor(theme.blockquoteColor), range: lineRange)
        textStorage.addAttribute(.font, value: fonts.italic, range: lineRange)
    }

    /// Renders a "---"/"***"/"___" line as an actual horizontal rule rather
    /// than literal dashes — no character is touched (a real rule would need
    /// an NSTextAttachment or custom drawing, both avoided here as before).
    /// The dash glyphs stay in place but go transparent, and a thick
    /// strikethrough is drawn across the run — strikethrough is a single
    /// continuous stroke spanning the run's width regardless of the
    /// (invisible) glyphs underneath, so it reads as a solid rule. Font size
    /// is left untouched (an earlier version shrank it, which collapsed the
    /// line's height along with it and made the whole thing nearly invisible).
    private static func applyHorizontalRule(in textStorage: NSTextStorage, line: String, lineRange: NSRange, theme: ThemeManager, fonts: EditorFontSet) {
        guard horizontalRulePattern.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil else {
            return
        }

        textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: lineRange)
        textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.thick.rawValue, range: lineRange)
        textStorage.addAttribute(.strikethroughColor, value: NSColor(theme.horizontalRuleColor), range: lineRange)
    }

    /// Colors "#tag" spans anywhere in a line — the pattern's own shape
    /// (word char required right after "#") already keeps this from ever
    /// matching a heading marker, so no extra exclusion logic is needed
    /// here.
    private static func applyTag(in textStorage: NSTextStorage, line: String, lineRange: NSRange, theme: ThemeManager, fonts: EditorFontSet) {
        let nsLine = line as NSString
        for match in tagPattern.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            let globalRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
            textStorage.addAttribute(.foregroundColor, value: NSColor(theme.tagColor), range: globalRange)
            textStorage.addAttribute(.font, value: fonts.bold, range: globalRange)
        }
    }

    /// Same treatment as bullet lines — hanging indent plus a bolded
    /// marker, covering both the number and its delimiter ("1." or "1)").
    private static func applyNumberedListIndent(in textStorage: NSTextStorage, line: String, lineRange: NSRange, fonts: EditorFontSet) {
        guard let match = numberedListPattern.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else {
            return
        }

        let indentWidth = fonts.regular.pointSize * 2.5
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.headIndent = indentWidth
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)

        let numberRange = match.range(at: 2)
        let delimiterRange = match.range(at: 3)
        let markerRange = NSRange(location: lineRange.location + numberRange.location, length: numberRange.length + delimiterRange.length)
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

    /// Not private — reused by MarkdownPreviewView for its own line
    /// classification, so heading detection stays defined in exactly one
    /// place instead of drifting between the editor and the preview.
    static func headingLevel(of line: String) -> Int? {
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
        guard !isTaskListCheckboxBracket(nsString: nsString, openIndex: openIndex, bracketContent: linkText) else { return }
        guard !isWikilinkBracket(nsString: nsString, openIndex: openIndex) else { return }

        showLinkPopover(for: bracketRange, linkText: linkText)
    }

    /// "[[Title]]" (an entry wikilink) also looks like the link popover's
    /// "[text]" trigger the instant its inner "]" is typed — the character
    /// immediately before the opening "[" is itself "[" only when it's the
    /// inner bracket of a wikilink's double brackets, which is what
    /// distinguishes the two cases.
    private func isWikilinkBracket(nsString: NSString, openIndex: Int) -> Bool {
        guard openIndex > 0 else { return false }
        return nsString.substring(with: NSRange(location: openIndex - 1, length: 1)) == "["
    }

    /// "- [ ]" and "- [x]" (task list checkboxes) look identical to the link
    /// popover's "[text]" trigger at the character level — a "]" closing a
    /// non-empty "[...]" span. Distinguishes them so typing a checkbox
    /// doesn't spuriously prompt for a URL: true only when the bracket's
    /// content is checkbox-shaped (blank or "x") AND everything before it on
    /// the line is just a bullet marker.
    private func isTaskListCheckboxBracket(nsString: NSString, openIndex: Int, bracketContent: String) -> Bool {
        let trimmedContent = bracketContent.trimmingCharacters(in: .whitespaces)
        guard trimmedContent.isEmpty || trimmedContent.lowercased() == "x" else { return false }

        let lineRange = nsString.lineRange(for: NSRange(location: openIndex, length: 0))
        let prefix = nsString.substring(with: NSRange(location: lineRange.location, length: openIndex - lineRange.location))
        let trimmedPrefix = prefix.trimmingCharacters(in: .whitespaces)
        return trimmedPrefix == "-" || trimmedPrefix == "*"
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
/// user's chosen family + size, plus a separately-chosen family for inline
/// code spans (same size as the body). Falls back to the system monospaced
/// font if a chosen family name doesn't resolve (e.g. deleted since picked).
struct EditorFontSet {
    let regular: NSFont
    let bold: NSFont
    let italic: NSFont
    let boldItalic: NSFont
    let code: NSFont

    init(fontName: String, fontSize: CGFloat, codeFontName: String = FontPreferences.systemMonospacedSentinel) {
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

        code = codeFontName == FontPreferences.systemMonospacedSentinel
            ? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            : (NSFont(name: codeFontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular))
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
