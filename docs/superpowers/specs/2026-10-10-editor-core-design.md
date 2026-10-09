# Margin Editor Core (Text Editor Milestone, Sub-project A): Design Spec

**Date:** 2026-10-10
**Status:** Approved in brainstorming, awaiting written-spec review

## Context

Margin must replace Sublime Text as its user's everyday editor, as well as being the agent-review tool. The text-editor milestone has three sub-projects, each with its own spec, plan and implementation cycle:

| Sub-project | Scope | Depends on |
|---|---|---|
| **A. Editor core (this spec)** | Custom text engine for all files, rendering, editing power, find/replace, navigation, wrap, minimap | none |
| B. Files & windows | Sublime-style windows (folder windows + loose-file windows; a single file opens as a tab in the frontmost loose-file window, or a new one); open single files; Open With / default app for common types; drop on Dock icon; encodings and line endings | A |
| C. Languages & formatting | Grammars: html, json, yaml, css, markdown, xml, js/ts, shell, toml, sql, plain text; JSON/YAML pretty-print and validation with error markers | A |

Decisions made during brainstorming:
- **One custom editor for every file.** It replaces the current NSTextView. Rejected alternatives: NSTextView plus a separate large-file editor (two drifting implementations), and TextKit 2 / STTextView / Monaco (whole text in memory, or not native).
- Files of **hundreds of MB must open quickly and remain editable.**
- All Sublime editing features in scope: multiple cursors, word wrap, line operations, brackets, minimap.
- A **switchable keymap** with Sublime and IntelliJ presets.

## Goals

1. Open, scroll, edit, search and save text files from a few bytes up to at least 500 MB.
2. Bring Sublime-class editing ergonomics to Margin.
3. Keep the text model headless (engine-first), so the app and future agent tools (margin-mcp) share it.
4. Keep every existing safety guarantee: never lose user edits, never overwrite an external change.

## Non-goals (this sub-project)

- Windows, single-file opening, default-app registration, encodings other than UTF-8, line-ending conversion (sub-project B).
- New grammars and formatting/validation (sub-project C). A uses the existing Java and Python grammars, with plain text for everything else.
- LSP, code completion, folding, split panes, macros, plugins.

## Performance targets

| Metric | Target |
|---|---|
| Open a 500 MB file to its first rendered screen | < 1 s |
| Scrolling | 60 fps at any file size |
| Keystroke to screen update | < 16 ms at any file size |
| Memory | memory-mapped file + edits + bounded caches, never 2–3× the file size in heap |
| Syntax highlighting | fully incremental ≤ 20 MB; viewport window only for 20–200 MB; off above 200 MB (manual override) |

## Architecture

```
MarginText (engine, Foundation only)          MarginEditorKit (app side, AppKit)
┌───────────────────────────────────┐        ┌──────────────────────────────────┐
│ TextBuffer  (piece table over mmap)│◀──────│ EditorView (CoreText, viewport)  │
│ LineIndex   (background, incremental)       │  ├ Gutter (line numbers)         │
│ UndoStack   (grouped edits)        │        │  ├ Minimap (tiled, background)   │
│ Selections  (multi-cursor values)  │        │  ├ FindBar                       │
│ EditCommands (pure functions)      │        │  └ NSTextInputClient (IME)       │
│ Search      (streaming, cancellable)        │ Keymap (chords → command names)  │
│ WrapMap     (lazy visual rows)     │        └──────────────────────────────────┘
└───────────────────────────────────┘
TextDocument (MarginWorkspace): conflict-safe save rules, now backed by TextBuffer
MarginSyntax: incremental tree-sitter, viewport queries, size policy
```

Rules:
- `MarginText` imports Foundation only. Editing, selection, search and wrapping logic lives there and is unit-tested without UI.
- `MarginEditorKit` is a new app-side library target (AppKit). It renders state and turns input into command calls. It contains no editing logic.
- The `Margin` app replaces `CodeTextView` with `EditorView`. Existing features (tabs, autosave, conflict banner, go to file, find in files opening at a line) keep working.

## Components

### TextBuffer (MarginText)
- A piece table. *Original* is a read-only memory map of the file (`Data(contentsOf:options:.alwaysMapped)` or `mmap`). *Add* is an append-only buffer for inserted bytes. The pieces are kept in a balanced tree indexed by byte offset and by line count, so lookups are O(log n).
- Byte-oriented (UTF-8). It exposes byte offsets plus conversions to and from (line, UTF-16 column) for the view and IME.
- API (indicative): `init(contentsOf:)`, `init(string:)`, `length`, `lineCount`, `bytes(in:)`, `string(in:)`, `line(_:)`, `offset(ofLine:)`, `line(containing:)`, `replace(_ range:with:) -> Edit`, `snapshot()` (immutable and cheap, used for background search, highlighting and saving).
- Invalid UTF-8 means the document opens read-only with a notice, and invalid bytes render as U+FFFD.

### LineIndex
- Newline offsets are built in the background in chunks (for example 4 MB) and published progressively. The view can render the first screen as soon as the first chunk is indexed, and the scrollbar becomes exact once indexing completes.
- After indexing it is kept up to date incrementally by edits (it lives in the piece tree's line counts).

### UndoStack
- Records `Edit`s (range, old bytes reference, new bytes), grouped by action. Consecutive typing is coalesced, and a multi-cursor action or a Replace All is one group. Redo is supported. Memory stays bounded because old text is referenced through pieces, not copied.

### Selections and EditCommands
- `Selections`: an ordered, non-overlapping set of ranges with a caret and anchor each. Overlapping ranges are merged after every command.
- Commands are pure functions `(TextBuffer snapshot, Selections) -> (edits, Selections)`:
  - **Typing and deletion:** insertText, deleteBackward/Forward (with word and line variants).
  - **Paste:** with N lines onto N cursors, one line goes to each cursor.
  - **Cursors:** selectNextOccurrence, selectAllOccurrences, addCursorAbove/Below, splitSelectionIntoLines, columnSelect(from:to:).
  - **Lines:** selectLine, duplicateLine, deleteLine, moveLineUp/Down, indent/outdent, autoIndentNewline.
  - **Comments:** toggleComment, using per-language line and block tokens from MarginSyntax.
  - **Brackets:** autoClose and wrapSelection for `() [] {} "" ''`, skipped inside strings and comments (based on the syntax tree), and matchingBracket.
- Each command is registered under a stable name, which the keymap and later MCP use.

### Search
- Plain, regex, case-sensitive and whole-word search over a snapshot. It is streamed chunk by chunk, with matches spanning chunk boundaries handled. It is cancellable and reports progress and a running count.
- Replace and Replace All support `$1`-style capture groups. Replace All is a single undo group and is cancellable with progress.

### WrapMap
- A lazy mapping between visual rows and (line, segment), computed for the viewport neighbourhood from glyph widths supplied by the view (a function injected from the view, so the engine stays UI-free).
- Default: on for md and txt, off otherwise, toggled per file. Above 50 MB it starts off and turning it on shows a warning.

### EditorView (MarginEditorKit)
- A custom NSView inside a scroll view. It lays out only the visible lines with CoreText (`CTLine`), with an LRU cache of laid-out lines. The document height comes from the line count times the line height, with wrap rows when wrap is on.
- Drawing: text, selections (multiple), carets (blinking), current-line highlight, matching-bracket highlight, find matches, and IME marked text.
- Input through `NSTextInputClient` (insertText, setMarkedText, firstRect, characterIndex(for:)) for full IME support. Mouse: click, drag, double-click word, triple-click line, ⌥-click add cursor, ⌥-drag column selection.
- **Gutter:** line numbers with the current line highlighted.
- **Minimap:** block-colour rendering in background tiles, with drag to scroll. Hidden above 50 MB.
- Theme: a monospaced font, syntax colours from `Theme`, and system light/dark appearance.

### Keymap
- A table from key chords to command names, with two presets, **Sublime** and **IntelliJ**, chosen in **Settings › Editor** (stored in UserDefaults). Margin's navigation shortcuts (Shift-Shift, ⌘⇧O, ⌘⇧F, ⌘1, ⌘0) are the same in both presets.
- Preset highlights:

| Command | Sublime | IntelliJ |
|---|---|---|
| select next occurrence | ⌘D | ⌃G |
| select all occurrences | ⌃⌘G | ⌃⌘G |
| duplicate line | ⌘⇧D | ⌘D |
| delete line | ⌃⇧K | ⌘⌫ |
| move line up/down | ⌃⌘↑/↓ | ⌥⇧↑/↓ |
| select line | ⌘L | — (⌘L is go to line) |
| split selection into lines | ⌘⇧L | ⌥⇧G |
| toggle comment | ⌘/ | ⌘/ |
| go to line | ⌃G | ⌘L |
| find / replace | ⌘F / ⌥⌘F | ⌘F / ⌘R |

### Syntax highlighting (MarginSyntax changes)
- The parser is kept per document. Every `Edit` is forwarded to tree-sitter as an incremental edit, and re-parsing runs on a background queue against a buffer snapshot (tree-sitter's read callback over pieces, so no full string copy).
- Highlight queries run only over the visible byte range, and results are cached per line until invalidated by edits.
- Size policy:
  - Up to 20 MB: full incremental parse.
  - 20–200 MB: parse a window of roughly 2 MB around the viewport (approximate).
  - Above 200 MB: off, with a status-bar notice and a manual "Highlight anyway" override.

### Find bar, go to line, live tail
- **Find bar** (⌘F) with toggles for regex, case and whole word. Matches show in the text, minimap and scrollbar. Next/previous match, select all matches as cursors, and a streaming match count.
- **Go to line** accepts `line` or `line:column`.
- **Live tail** is a toggle for files growing on disk (logs). Appended bytes are added to the buffer and the view follows the end. It switches off when the user edits or scrolls up.

### TextDocument integration (MarginWorkspace)
- Backed by `TextBuffer`, with the same conflict rules. The disk check before save uses a **fingerprint** (size, mtime, inode, and a hash of the first and last 1 MB) rather than re-reading the whole file. A full hash is computed in the background after load and after save to cover the middle.
- **Save:** stream the pieces of a snapshot to a temp file in the same directory, `fsync`, then atomically rename it into place (through symlinks, as today). After saving, re-map the new file and reset the piece table to a single original piece.
- **Memory-map hazard:** if the mapped file is truncated or replaced externally while open, reading beyond the new end must never crash (SIGBUS). Before mapping, and on every FSEvents notification for the file, Margin checks the inode and size and copies the still-needed original ranges into memory, or flags `.modifiedOnDisk`. This needs a dedicated test.

## Data flow
1. Key press: Keymap maps it to a command name, EditCommands returns (edits, selections), TextBuffer applies the edits and returns `Edit`s, then UndoStack, LineIndex, Syntax (incremental) and the view's invalidated line caches are updated in turn, and the view redraws the affected visible lines.
2. Search, highlighting and saving run on immutable snapshots off the main thread. Their results are applied only if the buffer version still matches; otherwise they are recomputed.
3. FSEvents change: TextDocument compares fingerprints. If the document is clean it reloads (re-map); if it is dirty it raises a conflict; with live tail on and the file only appended to, the appended bytes are added.

## Error handling
- Map or read failure: an alert with the error, and the tab is not opened.
- Invalid UTF-8: the document is read-only with a banner explaining that encoding support comes in sub-project B.
- Save failure: the error is reported, the document stays dirty and nothing is dropped (existing rule).
- Search regex error: shown inline in the find bar.
- Background tasks (indexing, search, highlight, minimap) are cancelled when the document closes. Stale results are dropped by version check.

## Testing
- **MarginText unit tests:**
  - Piece-table operations against a reference `String`.
  - **Property-based random edit sequences** (seeded) with invariants: content equals the reference, line index equals recomputed line offsets, and undo-all returns the original content.
  - Every EditCommand, including multi-cursor and edge cases (empty document, last line without a newline, CRLF content left untouched).
  - Search across chunk boundaries, regex, cancellation, and Replace All with undo.
  - WrapMap with a fake width function.
- **TextDocument tests:** fingerprint conflict detection, streaming save round-trip, save through a symlink, truncation of the mapped file while open (no crash, conflict raised), and live-tail append.
- **Performance tests:** generate 100 MB and 500 MB files at test time (not committed) and assert open-to-first-lines, offset↔line lookups, edit latency, and search throughput against the targets. They are tagged so CI can run a smaller size.
- **Manual checklists** for the view: IME input (Japanese and dead keys), multi-cursor editing, scrolling a 500 MB file, wrap toggle, minimap drag, and both keymap presets.

## Phasing (one implementation plan, phases shippable through the DMG pipeline)
- **A1 Buffer:** MarginText TextBuffer, LineIndex, UndoStack, Selections, Search; TextDocument on TextBuffer with streaming save and the memory-map hazard handled.
- **A2 View:** EditorView replaces CodeTextView with rendering, gutter, IME, mouse, single-cursor editing, and incremental highlighting with the size policy.
- **A3 Editing power:** multiple cursors, line operations, comments, brackets, Keymap with both presets, Settings › Editor.
- **A4 Find & navigation:** find bar, replace, go to line, live tail.
- **A5 Wrap & minimap:** WrapMap and soft wrap, and the minimap.

## Risks
- **The custom text view is the biggest risk** (IME correctness, accessibility, and macOS text conventions). Mitigation: implement `NSTextInputClient` fully in A2 and test IME by hand early. Basic accessibility (`NSAccessibility` text role) is in A2 scope, and full VoiceOver parity is out of scope for A.
- **Memory-mapped files changing underneath us.** Mitigated as described in TextDocument integration, with a test.
- **Tree-sitter on large buffers.** Mitigated by the size policy and viewport-only queries.
