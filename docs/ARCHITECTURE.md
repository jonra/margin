# Architecture

Margin has two parts: a **headless engine**, and **thin clients** that present it.

```
            ┌──────────────┐      ┌──────────────────┐
  human ──▶ │  Margin.app  │      │  margin-mcp      │ ◀── agents   (planned, M3b)
            │ (SwiftUI)    │      │  (stdio MCP)     │
            └──────┬───────┘      └────────┬─────────┘
                   └────────┬──────────────┘
                     ┌──────▼──────┐
                     │ MarginCore  │  Workspace · Syntax · Git · Search · Review
                     └─────────────┘
```

## Principles

1. **The engine has no UI.** Engine targets never import SwiftUI or AppKit. Anything the app can do, apart from drawing, should be reachable through a public `async` API on the engine.
2. **Clients are thin.** The app (and, later, the MCP server) translates between the engine and its medium.
3. **The disk and git are the source of truth.** Nothing is updated optimistically. FSEvents tells the app something changed, and the app re-reads from git and disk. A human and an agent working on the same repo therefore always see the same state.
4. **Never lose work.** User edits are never dropped silently, and a file an agent changed is never overwritten silently (see `TextDocument`).

## Engine modules

| Module | Responsibility | Key types |
|---|---|---|
| `MarginSupport` | Run external tools off the main thread; find them on `PATH` and in Homebrew locations; resolve real paths | `ProcessRunner`, `ToolLocator`, `MissingToolError` |
| `MarginSyntax` | Tree-sitter highlighting from vendored grammars, with highlight queries embedded as Swift strings | `SyntaxHighlighter`, `SourceLanguage`, `HighlightSpan` |
| `MarginGit` | Typed git CLI wrapper. Reads machine-readable output only (`--porcelain=v2 -z`, unified diff with forced `a/`/`b/` prefixes). Read-only calls use `--no-optional-locks` so they never fight an agent over `index.lock`. | `Git`, `StatusParser`, `DiffParser`, `FileDiff`, `Hunk`, `Worktree` |
| `MarginWorkspace` | Lists files (via `git ls-files` or a filtered walk), builds the tree, watches with FSEvents, owns the conflict-safe document model | `Workspace`, `FileTree`, `FileWatcher`, `TextDocument` |
| `MarginSearch` | Camel-hump fuzzy file matching; ripgrep `--json` search | `FileFinder`, `FuzzyMatcher`, `TextSearch` |
| `MarginReview` | What to review and how to act on it | `ReviewTarget`, `ReviewEngine`, `ChangedFile`, `SideBySide`, `ChangeTimeline` |
| `MarginCore` | Umbrella module that `@_exported`-imports all of the above | — |

### Review targets

- `.workingTree(root)`: the main checkout. It shows uncommitted (staged + unstaged + untracked) changes against `HEAD`. Stage and commit are allowed.
- `.worktree(root, branch, baseBranch)`: any other git worktree. It shows everything the agent did (commits + uncommitted work) against `merge-base(baseBranch, HEAD)`. Revert only, because an index hunk built against the merge-base would not apply.

### Hunk actions

- **Revert hunk** reverse-applies a single-hunk patch to the working tree (`git apply -R`). For the main checkout, if that exact change is also staged, the matching staged hunk is located by content in `git diff --cached` and reverse-applied to the index. The patch built from the working tree is never applied to the index.
- **Stage hunk** applies the single-hunk patch with `--cached`.
- Untracked files are diffed with `git diff --no-index /dev/null <file>`, so the user's index is never modified implicitly.

### `TextDocument`: conflict-safe editing

`TextDocument` keeps a *baseline*: what Margin believes is on disk (`nil` means the file is absent).

- `saveIfSafe()` re-reads the disk before writing. If the disk differs from the baseline, it records a conflict (`.modifiedOnDisk` / `.deletedOnDisk`) and does not write. It never recreates a file that was deleted outside Margin.
- `diskChanged()` reloads clean documents silently and flags dirty ones. The echo of Margin's own save is not a conflict.
- `keepMine()` re-baselines to the current disk state, so the next save writes the user's text. `reloadFromDisk()` and `discardChanges()` resolve the conflict the other way.
- Saves write through symlinks, so a link is never replaced by a regular file.

## The app (`Sources/Margin`)

- `AppState` owns the open workspace, the file list and tree, the open documents and the workspace watcher. It refuses to close a tab, switch folders or quit while a document is dirty and unresolved.
- `ReviewModel` owns the review UI state. Each target gets its own FSEvents watcher. Refreshes are debounced (150 ms) and ordered by a generation counter, so stale results are dropped. Paths of worktrees nested inside the target are ignored. Editor temp files are left out of the Activity list.
- `CodeTextView` is a plain `NSTextView` with tree-sitter colouring. CodeEditSourceEditor was ruled out because it does not build under SwiftPM without Xcode.

## Build constraints

- Pure SwiftPM: no Xcode project, and builds with the Command Line Tools only. Tests use Swift Testing (`import Testing`), not XCTest.
- Grammars are **vendored** by `scripts/vendor-grammars.sh`. The upstream `tree-sitter-python` SwiftPM manifest omits `scanner.c`, which causes a link error. Queries are embedded as Swift strings, so the `.app` needs no resource bundles.
- `scripts/bundle-app.sh` wraps the release binary in `build/Margin.app` with an `Info.plist` and an ad-hoc signature.

## Known follow-ups

- Move the live-review session logic (debounce, ordering, timeline, nested-worktree filtering) from `ReviewModel` into the engine before `margin-mcp`, so the app and agents share it.
- Add paging and limits to `changes()` and `TextSearch` for agent consumers.
- See [ROADMAP.md](ROADMAP.md) for the milestones.
