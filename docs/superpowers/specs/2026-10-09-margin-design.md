# Margin — Design Spec

**Date:** 2026-10-09
**Status:** Draft v2 (agent-centric platform), awaiting review

## Purpose
Margin is the foundation of an **agent-centric coding platform** for macOS. It starts from scratch with IntelliJ's core capabilities (navigation, search, syntax, git, change review) and builds them as a **headless engine**. Two kinds of client use that engine on equal terms:
- **Humans**, through a native Mac app that is read-first and review-first.
- **Agents**, through an MCP server, so they get IDE-grade navigation and diffs instead of grep.

v1 ("engine first") ships the engine, the Mac app and a minimal MCP server. Agent orchestration (launching and managing agents per task) is phase 2 and is built on top of the same engine.

## Architecture
```
            ┌──────────────┐      ┌──────────────────┐
  human ──▶ │  Margin.app  │      │  margin-mcp      │ ◀── agents (Claude Code, …)
            │ (SwiftUI)    │      │  (stdio MCP)     │
            └──────┬───────┘      └────────┬─────────┘
                   └────────┬──────────────┘
                     ┌──────▼──────┐
                     │ MarginCore  │  engine: Workspace · Search · LSP · Git · Review
                     └─────────────┘
          (phase 2: MarginAgents: task → worktree → agent session → review → merge)
```
Rules:
- **MarginCore has no UI dependency.** Everything the app can do (except rendering) is a public, async, `Sendable` API on the core.
- **Clients are thin.** The app and the MCP server only translate between the core API and their medium. No feature logic lives in a client.
- **The disk and git are the single source of truth**, so a human and an agent working on the same repo always see the same state.

## Scope
**In:** Java and Python syntax highlighting and formatting; navigation (go-to-definition, find usages, search everywhere, symbol search); agent change review; git tooling; light editing.
**Out:** run/debug configurations, debugger, automated refactorings, plugin system, languages beyond Java/Python (for v1).

## Platform & stack
- macOS 14+, Swift 6, SwiftUI app shell with AppKit where SwiftUI falls short (code view, diff view).
- Organized as a local Swift package. Engine targets are `MarginWorkspace`, `MarginSearch`, `MarginLSP`, `MarginGit` and `MarginReview`, re-exported together as `MarginCore`. Client targets are `MarginEditor`, the app target and the `margin-mcp` executable.
- The MCP server uses the official MCP Swift SDK (`modelcontextprotocol/swift-sdk`) over stdio.
- Reused building blocks:
  - **CodeEditSourceEditor** + **SwiftTreeSitter** (MIT) for the code view and tree-sitter highlighting (java, python grammars).
  - **jdtls** (Java) and **basedpyright** (Python) language servers via a small JSON-RPC/stdio LSP client.
  - **google-java-format** and **ruff format** as external formatter CLIs.
  - **git CLI** for all git operations (porcelain v2, diff, log, blame, worktree).
  - **ripgrep** for full-text search; **FSEvents** for file watching.
- External tools are discovered on `PATH` (and common Homebrew locations); missing tools degrade the matching feature with a clear in-app message instead of failing.

## Modules
Each module has one purpose, a small public API, and can be tested without the UI.

### MarginWorkspace
Opens a folder or repo, builds the file tree (respecting `.gitignore`), and publishes debounced file-change events from FSEvents. All other modules subscribe to these events instead of watching the disk themselves.

### MarginSearch
- File finder: fuzzy match on relative paths (Cmd-Shift-O, double-Shift).
- Text search: streams ripgrep `--json` results (Cmd-Shift-F).
- Symbol search: delegates to LSP `workspace/symbol` (Cmd-Alt-O).

### MarginEditor
Tabbed, read-first code view built on CodeEditSourceEditor. It supports light editing and save, format-on-demand (Cmd-Alt-L, matching IntelliJ), a gutter for blame and change markers, and Cmd-click navigation through LSP.

### MarginLSP
Manages one language-server process per (workspace, language), starting it lazily when the first file of that language opens. Implements initialize/shutdown, didOpen/didChange/didClose, definition, references, hover, documentSymbol, workspaceSymbol, and publishDiagnostics. If a server crashes it restarts with backoff and shows the status in the status bar.

### MarginGit
Typed wrappers over the git CLI: status, diff (worktree vs HEAD; branch vs merge-base), hunk apply/reverse-apply, stage/unstage, commit, log, file history, blame, branches, and `worktree list`. It parses machine-readable output only, and every command runs with an explicit `-C <path>`.

### MarginReview (core differentiator)
- **Review target** is one of: the main checkout's uncommitted changes vs HEAD, or a worktree/branch vs its merge-base with the base branch. A switcher lists all worktrees from `git worktree list`, so both agent workflows are covered.
- **Changes panel** lists changed files with status and +/- counts, refreshing live on workspace events. A "live" indicator shows when files changed in the last few seconds.
- **Diff view** is side-by-side or inline, with tree-sitter highlighting on both sides.
- **Actions:** revert a hunk or file (`git apply -R` on that hunk, or checkout for the whole file), accept a hunk or file (stage it), and commit from the panel.
- **Timeline** lists files touched during the session, most recent first, so you can follow what an agent is doing.

### margin-mcp (agent client)
A stdio MCP server that opens a workspace through MarginCore. It exposes read-only tools first: `find_file`, `search_text`, `find_symbol`, `go_to_definition`, `find_references`, `hover`, `document_symbols`, `diagnostics`, `git_status`, `git_diff`, `blame` and `file_history`. Results use repo-relative paths with line numbers and are paged so they fit in an agent's context. Write tools (stage, revert, commit) wait until phase 2, when they come with permission controls.

## Data flow
FSEvents → Workspace (debounce ~200 ms) → events → {Review refreshes git status/diff; Editor reloads clean open buffers and flags dirty ones as conflicted; LSP sends didChange for open files}.
User action (e.g. revert hunk) → Git → disk change → the same event path updates every view. Nothing updates the UI optimistically; the disk is the single source of truth.

## Error handling
- A missing external tool shows a per-feature banner with the install command (for example `brew install ripgrep`).
- A failing git command surfaces its stderr in a non-blocking toast. A revert that fails to apply leaves the files untouched.
- If an LSP server is unavailable, navigation falls back to text search ("Find usages (text)").
- An open buffer with unsaved edits that changes on disk prompts the user to keep theirs, take the disk version, or open a diff.

## Testing
- XCTest per module. Git and Review tests run against fixture repos created in temp directories (status parsing, diff/hunk parsing, revert/stage of a single hunk, worktree listing, merge-base diffs).
- The LSP client is tested against a fake stdio server, plus one smoke test each with real jdtls and basedpyright when they are installed.
- Search is tested on a fixture tree (fuzzy ranking, ripgrep JSON parsing).
- Manual end-to-end: run Claude Code in the main checkout and in a separate worktree, watch changes appear live, revert a hunk, and confirm with `git diff`.

## Milestones
1. **M1 Browser:** shell, open repo, file tree, tabs, highlighting, file finder, text search.
2. **M2 Agent review:** git status, changes panel, diff view, revert/stage hunk, live refresh, worktree switcher. *(M1 + M2 is the first usable cut.)*
3. **M3 Navigation:** LSP client, jdtls and basedpyright, go-to-definition, usages, symbols, hover.
3b. **M3b margin-mcp:** read-only MCP server over MarginCore. Verified by registering it with Claude Code and having an agent navigate a Java repo with it.
4. **M4 Git tooling:** log, file history, blame gutter, branches, commit dialog.
5. **M5 Polish:** formatters, IntelliJ-like keymap, settings, editing quality.

## Phase 2 (outline, separate spec later)
**MarginAgents:** create a task, which gets its own git worktree, then start an agent (Claude Agent SDK / Claude Code) in it, stream the session live in the app, review the changes with MarginReview, and merge. This phase also adds write tools in margin-mcp, with permission controls.
