# MacDown

A native macOS app for **reading** Markdown — fast to open, beautiful to read, always up to date.

In the age of agentic development, Markdown has become the new source code: specs, PRDs, plans, and docs all live in `.md` files. MacDown is built exclusively for **reading** them — not editing. It's designed to speed up reviewing and validating docs and specs while working with coding agents (Claude Code, Codex, etc.), without opening a heavy IDE or flipping between raw and preview modes.

## Why

- Reading `.md` in VS Code/Xcode means opening a heavyweight IDE or toggling raw/preview.
- Web-based viewers are slow to open and don't understand folders as projects.
- YAML frontmatter (common in agentic specs) shows up as raw text.
- Files change constantly (agents writing them); static readers require manually reopening.

## Features

- **Folder browser sidebar** — IDE-style tree; only Markdown files are shown (`.md`, `.markdown`, `.mdown`, `.mkd`), with the active file highlighted.
- **Chrome-style tabs** — every opened `.md` gets a tab; internal links open in new tabs, with navigation history (`Cmd+←` / `Cmd+→`).
- **Full rendering** — CommonMark + GFM (tables, task lists, strikethrough, autolinks, footnotes), Mermaid diagrams inline, and relative local images.
- **Frontmatter support** — YAML frontmatter rendered as a collapsible metadata card, with clear warnings for invalid YAML.
- **Smart code blocks** — syntax highlighting, copy as raw, and *Copy Command* for shell blocks (strips prompts, comments, and line continuations into a ready-to-run command).
- **Outline/TOC panel** — synced both ways: click to scroll, scroll to highlight.
- **Reading-optimized** — adjustable reading width, long code block folding, horizontally scrollable wide tables, heading anchors with copy-link on hover.
- **Document validation** — badge for broken internal links/anchors and Mermaid syntax errors.
- **Status footer** — file path breadcrumb, word/character count, and aggregated task progress (`12/18 tasks`).
- **Per-document reading state** — scroll position is remembered per file within the session.
- **Themes** — Light, Dark, and System (follows macOS), persisted between sessions.

## Install

**Requirements:** macOS 14 (Sonoma) or later.

1. Download the latest `MacDown.app.zip` from [Releases](https://github.com/alissonpdc/macdown/releases/latest) — every release is built automatically by CI.
2. Unzip and move `MacDown.app` to `/Applications`.
3. If macOS blocks the first launch, remove the quarantine attribute and open it again:

   ```bash
   xattr -cr /Applications/MacDown.app
   ```

> Want to contribute or build from source? See [CONTRIBUTING.md](CONTRIBUTING.md).

## Feature Requests

Feature requests are very welcome! Please open a [GitHub issue](https://github.com/alissonpdc/macdown/issues) describing your use case.

## License

Licensed under the [Apache License 2.0](LICENSE).
