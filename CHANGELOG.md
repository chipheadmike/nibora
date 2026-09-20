# Changelog

All notable changes to Nibora will be documented in this file.

## [Unreleased]

### Added
- Freeform vault type alongside the daily Journal: your own titles, nested folders, drag-to-move
- Wikilinks with backlinks and an entry graph; tags with colors, rename, merge and delete
- Blockquotes, horizontal rules, inline code, strikethrough, highlight and task lists (with auto-continuation on Return)
- Journal Stats (mood trend, writing-time chart, word cloud, streaks), Journal Digest and Year in Review
- Ask Nibora and Journal Digest with on-device Apple Intelligence, or your own Claude / ChatGPT API key
- Quick Capture from the menu bar, Siri / Shortcuts support, Spotlight indexing, streak reminders and entry templates
- Multiple vaults, theme presets, light / dark override, vault backup to zip, PDF export, read-aloud, focus mode, preview pane and per-entry version history
- Optional privacy-screen password lock with a recovery code and email recovery
- Optional current temperature in the timestamp hotkey (Journal only)
- Video attachments: drag or paste a video into an entry; thumbnails in the entry strip and the vault-wide Attachments gallery, opened in your default player
- Settings for the photo preview popup size, and a toolbar toggle to show / hide the photo strip

### Fixed
- Unchecking a task list item now clears its strikethrough
- Pressing Return on a task list item continues the list with a new checkbox instead of a bare bullet
- Date, month and timestamp formatters now follow the Mac's time zone live instead of freezing the zone at first use, so traveling with the app open no longer mis-files or mis-stamps entries
- Settings window is wide enough to show every tab icon

## [1.0.0] - 2026-08-04

### Added
- Vault-backed markdown journal: entries stored as plain `.md` files organized into month folders, with SwiftData used only as a fast index/cache layer over the files
- Security-scoped vault picker, with a "Change Vault…" option in Settings
- Sectioned sidebar grouped by month, sortable manually (Move Up/Down) or automatically by creation date / modified date
- Per-entry SF Symbol icons and a delete flow (moves the file to Trash)
- Plain-text markdown editor with autosave, including:
  - Heading colors (H1–H6), configurable per level in Settings
  - Real bold/italic font rendering with configurable colors
  - Bullet list auto-continuation (`-`/`*`) with a hanging indent
- Image support: drag-and-drop or paste an image to save it into the vault and insert a link, with a thumbnail strip below the editor and click-to-preview
- Import from a folder of exported Markdown files (e.g. Ulysses' Export → Markdown)
- Configurable timestamp hotkey (default ⌘⇧T) that inserts a 24-hour `HHmm - ` stamp at the cursor
- Full-text search across entry titles and bodies
- Window size and position persist across launches
- Custom app icon and a Mail/Notes-style large title in the sidebar
