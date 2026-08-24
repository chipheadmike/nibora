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

    Nibora is a plain-markdown notebook. Every entry is a real `.md` file on disk — nothing lives locked in a database. The app is just a nice window onto files you fully own.

    ---

    ## Vault Types

    Chosen once, when a vault is first created — not changeable afterward.

    - **Journal** — one page per day, like a daily journal. Entries are organized into `YYYY-MM` month folders and named by date. New Entry always creates (or opens) today's page.
    - **Freeform** — unlimited entries with your own titles, organized into folders you create yourself, more like a general notes app. New Entry always asks for a title. Since there's no daily cadence here, streaks, reminders, On This Day, and the Writing Calendar heatmap don't apply and are hidden — everything else (tags, wikilinks, backlinks, AI features, themes, and so on) works exactly the same as in a Journal vault.

    Opening a brand-new empty folder as a vault asks which type to make it. Opening a folder that's already a vault (or already has files in it) just opens it as whatever it already is — every vault that existed before this feature defaults to Journal, silently, with no visible change.

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

    Drag or paste an image into an entry and it's saved into that month's Attachments folder and shown in the strip below the editor. Deleting the image from the text moves its file to the Trash too, automatically, the next time the entry saves.

    Entries are also indexed into macOS's system-wide Spotlight search (Cmd+Space) — search from anywhere on your Mac and clicking a result jumps straight into that entry, entirely on-device.

    ---

    ## Toolbar

    In the sidebar:
    - **New Entry** — Journal: creates today's entry (hidden once today's entry exists). Freeform: asks for a title and creates it at the vault's root — for a specific folder instead, right-click that folder and use its own New Entry
    - **Rescan Vault** — fully re-parses every file, useful after editing files outside the app, or after enabling a feature that needs to backfill older entries
    - **Vaults** — switch between every vault folder you've ever opened, or open another one. The current vault shows a checkmark. Also manageable from Settings > General, where each recent vault can be removed from the list (this only forgets it — nothing on disk is touched)
    - **On This Day** (Journal only) — past entries from today's date in previous years
    - **Random Entry** — jumps to a random entry
    - **Journal Stats** — total entries, total words, a recent-mood indicator with a trend chart, a chart of what time of day you tend to write, and a word cloud of your most frequent words — all inferred automatically on-device, nothing is sent anywhere to compute it. Writing streaks too, in a Journal vault
    - **Entry Graph** — a node graph of entries connected by `[[wikilinks]]`
    - **Ask Nibora** — ask questions about your own journal in plain English. Uses whichever AI provider is selected in Settings > AI: On-Device (Apple Intelligence, free and fully local), or your own Claude or ChatGPT API key (journal excerpts are sent to that provider's servers, billed per-use to your own account)
    - **Journal Digest** — entry/word counts, a mood chart, a word cloud, and an AI-generated recap for the past 7 days, 30 days, or year (a built-in "Year in Review"), surfacing recurring themes and mood shifts. Same provider and privacy rules as Ask Nibora
    - **Writing Calendar** (Journal only) — a GitHub-style heatmap of writing activity over the past year; click a day to jump to that entry
    - **Attachments** — every image across the whole vault in one browsable grid, not just the current entry's

    In a Freeform vault's sidebar specifically:
    - Right-click a folder for its own **New Entry**, **New Folder**, **Rename…**, and **Delete…** (a folder must be empty to delete — move or remove what's inside first)
    - Right-click an entry for **Move to Root** or **Delete…**
    - Drag an entry onto a folder to move it there

    In an entry:
    - **Read Aloud** (speaker icon) — reads the entry aloud, with markdown syntax stripped to clean prose first. Voice, rate, and pitch are configurable in Settings > Editor
    - **Focus Mode** (eye icon) — dims every paragraph except the one you're writing
    - **Preview** (split-rectangle icon) — a second pane with fully rendered markdown, no raw syntax
    - **Export to PDF** — saves the current entry as a PDF
    - **Version History** (clock icon) — periodic automatic snapshots of the entry as you edit, with one-click restore

    Anywhere:
    - **⌘K** — quick switcher, jump to any entry by title or date

    In the menu bar (the pencil icon, always available even if Nibora's window is closed):
    - **Quick Capture** — jot a note without opening the app; it's appended, timestamped, to today's entry, creating it first if needed. A click-triggered window only — nothing runs in the background listening for keystrokes. Opening it shows your current writing streak and today's word count at a glance

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
    - **Entries** — a reminder notification for days you haven't written yet (Journal only), and optional named entry templates (with a `{{weekday}}` placeholder — with more than one, New Entry becomes a menu to pick from, in a Journal vault).
    - **Editor** — font/size, the timestamp hotkey, and Read Aloud's voice/rate/pitch (with a live preview button).
    - **Appearance** — a Display picker to override Light/Dark/System for Nibora only, and one-click theme presets.
    - **Colors** — a color picker for every styled markdown element (every color automatically nudges its brightness to stay legible in whichever Light/Dark mode is active), plus the code-block font.
    - **Import** — bring in Markdown files from another app, and scan for orphaned attachment images no entry references anymore (mainly catches leftovers from a deleted entry or files edited outside the app — removing an image from an entry's text already cleans up its file automatically).
    - **Password** — optional privacy-screen lock with a lock timer, a one-time recovery code, and an optional recovery email — if forgotten, the lock screen can open a pre-filled Mail.app draft with a temporary code, which you send to yourself and enter back in. This is a privacy screen, not encryption — entries stay plain text on disk either way.
    - **AI** — choose Ask Nibora's provider (On-Device, Claude, or ChatGPT) and enter your own API key for the cloud options. Keys are stored in this Mac's Keychain, never in plain text.

    ---

    Everything above is just markdown text in real files. If you ever want to leave Nibora, your journal is already portable.
    """
}
