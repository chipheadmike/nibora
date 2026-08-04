# Changelog

All notable changes to Nibora will be documented in this file.

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
