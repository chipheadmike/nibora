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
    @Environment(TagColorPreferences.self) private var tagColorPreferences
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
                tagColorPreferences: tagColorPreferences,
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

    Entries are also indexed into macOS's system-wide Spotlight search (Cmd+Space) — search from anywhere on your Mac and clicking a result jumps straight into that entry, entirely on-device.

    ---

    ## Toolbar

    In the sidebar:
    - **New Entry** — creates today's entry (hidden once today's entry exists)
    - **Rescan Vault** — fully re-parses every file, useful after editing files outside the app, or after enabling a feature that needs to backfill older entries
    - **Vaults** — switch between every vault folder you've ever opened, or open another one. The current vault shows a checkmark. Also manageable from Settings > General, where each recent vault can be removed from the list (this only forgets it — nothing on disk is touched)
    - **On This Day** — past entries from today's date in previous years
    - **Random Entry** — jumps to a random entry
    - **Journal Stats** — total entries, total words, writing streaks, a recent-mood indicator with a trend chart, a chart of what time of day you tend to write, and a word cloud of your most frequent words — all inferred automatically on-device, nothing is sent anywhere to compute it
    - **Entry Graph** — a node graph of entries connected by `[[wikilinks]]`
    - **Ask Nibora** — ask questions about your own journal in plain English. Uses whichever AI provider is selected in Settings > AI: On-Device (Apple Intelligence, free and fully local), or your own Claude or ChatGPT API key (journal excerpts are sent to that provider's servers, billed per-use to your own account)
    - **Journal Digest** — an AI-generated recap of the past 7 or 30 days, surfacing recurring themes and mood shifts. Same provider and privacy rules as Ask Nibora
    - **Writing Calendar** — a GitHub-style heatmap of writing activity over the past year; click a day to jump to that entry
    - **Attachments** — every image across the whole vault in one browsable grid, not just the current entry's

    In an entry:
    - **Read Aloud** (speaker icon) — reads the entry aloud, with markdown syntax stripped to clean prose first. Voice, rate, and pitch are configurable in Settings > Editor
    - **Focus Mode** (eye icon) — dims every paragraph except the one you're writing
    - **Preview** (split-rectangle icon) — a second pane with fully rendered markdown, no raw syntax
    - **Export to PDF** — saves the current entry as a PDF
    - **Version History** (clock icon) — periodic automatic snapshots of the entry as you edit, with one-click restore

    Anywhere:
    - **⌘K** — quick switcher, jump to any entry by title or date

    In the menu bar (the pencil icon, always available even if Nibora's window is closed):
    - **Quick Capture** — jot a note without opening the app; it's appended, timestamped, to today's entry, creating it first if needed. A click-triggered window only — nothing runs in the background listening for keystrokes

    Outside the app entirely:
    - **Siri / Shortcuts** — say "Capture a journal entry in Nibora" (or build a Shortcuts automation around it) to append a note to today's entry, hands-free. Uses Apple's App Intents framework, the same officially-supported mechanism apps use for Siri and Shortcuts — not a custom background listener

    ---

    ## Organization

    - The sidebar groups entries by month — click a month header to collapse or expand it.
    - Right-click an entry for Choose Icon…, Move Up/Down (when sorted manually), and Delete….
    - Search (top of the sidebar) matches titles and body text, with matches highlighted.
    - Tag pills appear above the entry list once you've used any #tags — click one to filter. Right-click a tag for a color picker (applies everywhere that tag appears — sidebar, editor, and preview), Rename or Merge… (renaming to an existing tag folds the two together), and Delete Tag, applied across every entry that uses it.
    - A "Linked From" panel appears below an entry's attachments whenever another entry references it via `[[wikilink]]` — the reverse direction of the link itself.

    ---

    ## Settings

    - **General** — vault location (and switching between every vault you've opened), window title, sort order (with an ascending/descending option for the date-based modes), and a one-click "Export Vault as Zip…" backup of everything.
    - **Entries** — a reminder notification for days you haven't written yet, and optional named entry templates (with a `{{weekday}}` placeholder — with more than one, New Entry becomes a menu to pick from).
    - **Editor** — font/size, the timestamp hotkey, and Read Aloud's voice/rate/pitch (with a live preview button).
    - **Appearance** — a Display picker to override Light/Dark/System for Nibora only (every color below automatically nudges its brightness to stay legible in whichever mode is active), one-click theme presets, a color picker for every styled markdown element, plus the code-block font.
    - **Import** — bring in Markdown files from another app, and scan for orphaned attachment images no entry references anymore.
    - **Password** — optional privacy-screen lock with a lock timer, a one-time recovery code, and an optional recovery email — if forgotten, the lock screen can open a pre-filled Mail.app draft with a temporary code, which you send to yourself and enter back in. This is a privacy screen, not encryption — entries stay plain text on disk either way.
    - **AI** — choose Ask Nibora's provider (On-Device, Claude, or ChatGPT) and enter your own API key for the cloud options. Keys are stored in this Mac's Keychain, never in plain text.

    ---

    Everything above is just markdown text in real files. If you ever want to leave Nibora, your journal is already portable.
    """
}
