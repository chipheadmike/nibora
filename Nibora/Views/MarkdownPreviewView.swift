//
//  MarkdownPreviewView.swift
//  Nibora
//

import SwiftUI

/// Read-only rendered markdown view — unlike the editor (which only ever
/// adds styling attributes on top of the literal characters that get saved
/// to disk), this actually strips markdown syntax and renders real
/// formatting, since that's the whole point of a preview. Built fresh from
/// the current body text on every render; never writes anything back.
struct MarkdownPreviewView: View {
    let markdownText: String
    let theme: ThemeManager
    let fontPreferences: FontPreferences
    let onWikilinkClick: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var resolvedTheme: ResolvedTheme {
        ResolvedTheme(theme, for: colorScheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(for: block)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == MarkdownTextView.wikilinkScheme else { return .systemAction }
            let rawTitle = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
            onWikilinkClick(rawTitle.removingPercentEncoding ?? rawTitle)
            return .handled
        })
    }

    private enum Block {
        case blank
        case heading(level: Int, content: String)
        case blockquote(content: String)
        case horizontalRule
        case bullet(content: String)
        case numbered(marker: String, content: String)
        case task(checked: Bool, content: String)
        case paragraph(content: String)
    }

    private var blocks: [Block] {
        markdownText.components(separatedBy: "\n").map(classify)
    }

    /// Order matters: task lines also match the plain bullet pattern (both
    /// start with "-"/"*"), so task must be checked first or every checkbox
    /// line would render as an ordinary bullet instead.
    private func classify(_ line: String) -> Block {
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        if MarkdownTextView.horizontalRulePattern.firstMatch(in: line, range: fullRange) != nil {
            return .horizontalRule
        }
        if let level = MarkdownTextView.headingLevel(of: line) {
            return .heading(level: level, content: String(line.dropFirst(level + 1)))
        }
        if let match = MarkdownTextView.taskListPattern.firstMatch(in: line, range: fullRange) {
            let checkboxChar = nsLine.substring(with: match.range(at: 4))
            return .task(checked: checkboxChar.lowercased() == "x", content: nsLine.substring(with: match.range(at: 6)))
        }
        if let match = MarkdownTextView.bulletListPattern.firstMatch(in: line, range: fullRange) {
            return .bullet(content: nsLine.substring(with: match.range(at: 4)))
        }
        if let match = MarkdownTextView.numberedListPattern.firstMatch(in: line, range: fullRange) {
            let number = nsLine.substring(with: match.range(at: 2))
            let delimiter = nsLine.substring(with: match.range(at: 3))
            return .numbered(marker: "\(number)\(delimiter)", content: nsLine.substring(with: match.range(at: 5)))
        }
        if let match = MarkdownTextView.blockquotePattern.firstMatch(in: line, range: fullRange) {
            return .blockquote(content: nsLine.substring(with: match.range(at: 4)))
        }
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            return .blank
        }
        return .paragraph(content: line)
    }

    @ViewBuilder
    private func blockView(for block: Block) -> some View {
        switch block {
        case .blank:
            Spacer().frame(height: 4)
        case .heading(let level, let content):
            Text(attributedText(content))
                .font(headingFont(for: level))
                .foregroundStyle(resolvedTheme.color(forHeadingLevel: level))
                .padding(.top, level <= 2 ? 8 : 4)
        case .blockquote(let content):
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(resolvedTheme.blockquoteColor.opacity(0.5))
                    .frame(width: 3)
                Text(attributedText(content))
                    .italic()
                    .foregroundStyle(resolvedTheme.blockquoteColor)
            }
        case .horizontalRule:
            Divider()
        case .bullet(let content):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                Text(attributedText(content))
            }
        case .numbered(let marker, let content):
            HStack(alignment: .top, spacing: 6) {
                Text(marker).fontWeight(.bold)
                Text(attributedText(content))
            }
        case .task(let checked, let content):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(checked ? resolvedTheme.linkColor : resolvedTheme.boldColor)
                Text(attributedText(content))
                    .strikethrough(checked)
                    .foregroundStyle(checked ? resolvedTheme.strikethroughColor : resolvedTheme.bodyColor)
            }
        case .paragraph(let content):
            Text(attributedText(content))
        }
    }

    private func attributedText(_ line: String) -> AttributedString {
        let fonts = EditorFontSet(fontName: fontPreferences.fontName, fontSize: fontPreferences.fontSize, codeFontName: fontPreferences.codeFontName)
        let nsAttributed = MarkdownTextView.inlineAttributedText(from: line, theme: theme, fonts: fonts, colorScheme: colorScheme)
        return AttributedString(nsAttributed)
    }

    private func headingFont(for level: Int) -> Font {
        let size = fontPreferences.fontSize
        switch level {
        case 1: return .system(size: size * 1.8, weight: .bold)
        case 2: return .system(size: size * 1.5, weight: .bold)
        case 3: return .system(size: size * 1.3, weight: .semibold)
        case 4: return .system(size: size * 1.15, weight: .semibold)
        case 5: return .system(size: size * 1.05, weight: .semibold)
        default: return .system(size: size, weight: .semibold)
        }
    }
}
