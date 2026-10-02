# Nibora

A plain-markdown journal and notebook for macOS. Every entry is a real `.md` file in a folder you own — nothing is locked in a database, so if you ever leave Nibora, your writing is already portable.

> **Status: beta.** Nibora is under active development and holds your personal writing. Keep backups (Settings > General > Export Vault as Zip…) and expect rough edges.

## Requirements

- macOS 27 (the deployment target is 27.0)
- Xcode 27 beta to build from source

Nibora currently targets pre-release Apple SDKs, so it will only build and run on a machine with them installed.

## Features

**Two vault types** (chosen once, when a vault is created)
- **Journal** — one page per day, filed into `YYYY-MM` month folders. Streaks, reminders, On This Day and a writing-activity heatmap.
- **Freeform** — unlimited entries with your own titles, in folders you create and nest yourself, like a general notes app.

**Writing**
- Live-styled markdown: bold, italic, strikethrough, highlight, inline code, headings, blockquotes, horizontal rules, bullet / numbered lists, and task lists with auto-continuation on Return.
- `[[wikilinks]]` between entries with a backlinks panel and an entry graph, `#tags` with per-tag colors, rename / merge / delete.
- A configurable timestamp hotkey (`1054 - `), optionally with the current temperature (Journal only).
- Focus mode, a rendered preview pane, read-aloud, export to PDF, and per-entry version history.
- Drag or paste photos and videos into an entry. They're saved next to it in an `Attachments` folder and shown as thumbnails below the editor, with a vault-wide gallery.

**Around the app**
- Quick Capture from the menu bar, Siri / Shortcuts support, and Spotlight indexing of your entries.
- Stats, mood trend, word cloud, and a Journal Digest (including a "Year in Review").
- Multiple vaults, entry templates, theme presets, light / dark override, and fully customizable colors and fonts.
- Optional privacy-screen lock with a recovery code.

The in-app **Guide** (toolbar) documents everything in more detail.

## How your data is stored

A vault is just a folder:

```
MyVault/
  .nibora/vault.json        # vault type: "journal" or "freeform"
  2026-09/
    2026-09-12.md           # frontmatter (id, title, dates, icon) + your markdown
    Attachments/            # photos and videos dropped into entries in this folder
```

SwiftData is used only as a fast index over those files. It can be rebuilt at any time (Rescan Vault), and you can edit the files outside Nibora.

## Privacy and security model

- **Local first.** Entries never leave your Mac unless you use an AI feature (below).
- **AI features are opt-in.** "Ask Nibora" and Journal Digest can use on-device Apple Intelligence (fully local), or your own Claude or ChatGPT API key. With a cloud provider, the relevant journal excerpts are sent to that provider and billed to your account. Nibora ships with no keys.
- **Weather is opt-in.** If enabled, your zip code is geocoded with Apple's geocoder and the temperature is fetched from the free [Open-Meteo](https://open-meteo.com) API. No account, and no journal content is sent.
- **The password lock is a privacy screen, not encryption.** Entries remain plain text on disk. The password is stored as a salted SHA-256 hash in the Keychain, which is reasonable for keeping a casual observer out but not a defense against a determined offline attacker. Use FileVault for real at-rest protection.
- The app is sandboxed with the hardened runtime, and can only access folders you explicitly choose.

## Building

1. Clone the repository and open `Nibora.xcodeproj` in Xcode 27 beta.
2. Under **Signing & Capabilities**, select your own development team and change the bundle identifier — the project is currently configured with the author's.
3. Build and run the `Nibora` scheme.

## Distribution

Nibora isn't on the App Store — it's distributed as a notarized `.dmg` directly. `Scripts/release.sh` builds a Release archive, signs it with a Developer ID Application certificate, submits it to Apple for notarization, staples the ticket, and packages the notarized, stapled result as `build/release/Nibora-<version>.dmg`.

To run it yourself, you need:
1. A **Developer ID Application** certificate for your team, installed in your keychain (Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application). This is a different certificate type from the one used for App Store builds or local development.
2. Notarization credentials stored under a keychain profile, using an **app-specific password** from [appleid.apple.com](https://appleid.apple.com) — not your regular Apple ID password:
   ```
   xcrun notarytool store-credentials "nibora-notarize" --apple-id "you@example.com" --team-id YOUR_TEAM_ID
   ```
3. `Scripts/release.sh` and `Scripts/ExportOptions.plist` updated with your own team ID and Developer ID identity string — they're currently set to the project author's.

Two things worth knowing if you're adapting this for your own fork: a `.dmg` built with `hdiutil` isn't signed by default, and a notarization ticket only staples onto the exact file that was submitted — so the script signs and separately notarizes the `.dmg` itself, on top of notarizing the `.app` inside it. Skipping either step passes locally but fails Gatekeeper's actual check on a clean Mac.

## Design notes for contributors

- The editor is a plain-text `NSTextView` whose backing string is always exactly what's written to disk. Styling is attribute-only — no character is ever added, removed, or hidden for display.
- As a consequence, attached photos and videos never appear in the text at all: an entry's attachment list lives in its frontmatter (`attachments:`) and is shown in a separate SwiftUI strip below the editor. Rendering images inline inside the text view was tried twice and abandoned as unreliable on this SDK; please don't restart that without reading the comments in `MarkdownTextView.swift` and `AttachmentsStripView.swift`. (Older entries may still have inline `![](…)` lines, which the strip also reads — see `AttachmentReferences.swift`.)
- Clickable spans inside the editor (task checkboxes, wikilinks, video links) use private URL schemes routed through the text view's native Cmd+Click link handling, the one interaction that has proven reliable.

## Tests

`NiboraTests` and `NiboraUITests` currently contain only the Xcode template stubs. The markdown styling, list continuation, indexer, and file-writing logic are all good candidates for real tests.

## License

Released under the [MIT License](LICENSE).
