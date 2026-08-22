//
//  HelpView.swift
//  Nibora
//

import SwiftUI

/// In-app user manual — written as plain markdown and rendered through the
/// same MarkdownPreviewView the entry editor uses, so it looks and behaves
/// exactly like a real entry rather than a separately-styled document.
struct HelpView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(FontPreferences.self) private var fontPreferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Nibora Guide")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            MarkdownPreviewView(
                markdownText: Self.manualText,
                theme: themeManager,
                fontPreferences: fontPreferences,
                onWikilinkClick: { _ in }
            )
        }
        .frame(width: 640, height: 620)
    }

    private static let manualText = """
    # Welcome to Nibora

    Nibora is a plain-markdown journal. Every entry is a real `.md` file on disk, organized into `YYYY-MM` month folders — nothing lives locked in a database. The app is just a nice window onto files you fully own.

    ---

    ## Writing

    Nibora supports a focused set of markdown, styled live as you type and fully rendered (markup hidden) in the **Preview** pane:

    - `**bold**`, `*italic*`, `***bold italic***`
    - `~~strikethrough~~`
    - `==highlight==`
    - `` `inline code` `` (font choosable in Settings > Appearance)
    - `# Heading` through `###### Heading`
    - `> blockquote`
    - `---` for a horizontal rule
    - `- item` or `* item` for bullet lists — press Return to continue automatically
    - `1. item` for numbered lists — auto-increments on Return
    - `- [ ] task` / `- [x] task` — Cmd+Click the checkbox to toggle it
    - `[link text](https://example.com)` for a web link
    - `[[Entry Title]]` to link directly to another entry by its exact title — Cmd+Click to jump there
    - `#tag` anywhere in a line — filterable from the sidebar

    Drag or paste an image into an entry and it's saved into that month's Attachments folder and shown in the strip below the editor.

    ---

    ## Toolbar

    In the sidebar:
    - **New Entry** — creates today's entry (hidden once today's entry exists)
    - **Rescan Vault** — fully re-parses every file, useful after editing files outside the app
    - **On This Day** — past entries from today's date in previous years
    - **Random Entry** — jumps to a random entry
    - **Journal Stats** — total entries, total words, current and longest writing streak

    In an entry:
    - **Focus Mode** (eye icon) — dims every paragraph except the one you're writing
    - **Preview** (split-rectangle icon) — a second pane with fully rendered markdown, no raw syntax
    - **Export to PDF** — saves the current entry as a PDF

    Anywhere:
    - **⌘K** — quick switcher, jump to any entry by title or date

    ---

    ## Organization

    - The sidebar groups entries by month — click a month header to collapse or expand it.
    - Right-click an entry for Choose Icon…, Move Up/Down (when sorted manually), and Delete….
    - Search (top of the sidebar) matches titles and body text, with matches highlighted.
    - Tag pills appear above the entry list once you've used any #tags — click one to filter.

    ---

    ## Settings

    - **General** — vault location, window title, sort order, and an optional entry template (with a `{{weekday}}` placeholder) applied to every new entry.
    - **Editor** — font/size and the timestamp hotkey, which inserts the current time at the cursor.
    - **Appearance** — a color picker for every styled markdown element, plus the code-block font.
    - **Import** — bring in Markdown files from another app, and scan for orphaned attachment images no entry references anymore.
    - **Password** — optional privacy-screen lock with a lock timer and a one-time recovery code. This is a privacy screen, not encryption — entries stay plain text on disk either way.

    ---

    Everything above is just markdown text in real files. If you ever want to leave Nibora, your journal is already portable.
    """
}
