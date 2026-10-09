# Margin

[![Build](https://github.com/jonra/margin/actions/workflows/build.yml/badge.svg)](https://github.com/jonra/margin/actions/workflows/build.yml)

**A native macOS code browser and agent-change reviewer.** Agents write the code. Margin is where you read it, follow what they are doing, and decide what stays.

Margin borrows the core of IntelliJ IDEA (project tree, fast navigation, search, git, diffs) and rebuilds it from scratch around one workflow: AI agents edit files on disk while you browse and review. It is the foundation of an agent-centric coding platform. Its engine (`MarginCore`) is headless, so the Mac app and, later, agents (through an MCP server) can both use it.

> **Status:** early (v0.1). Milestones M1 (browser) and M2 (agent review) are done. Java and Python have syntax highlighting; other text files open as plain text. See the [roadmap](docs/ROADMAP.md).

## Features

**Browse**
- Project tree that respects `.gitignore`, and tabbed editor
- Tree-sitter syntax highlighting for Java and Python
- **Go to File**: ⇧⌘O or double-Shift, with IntelliJ-style camel humps (`US` → `UserService`)
- **Find in Files**: ⇧⌘F, powered by ripgrep (plain text or regex)

**Review what agents change**
- **Live Changes panel** (⌘0): updates within a second as files change on disk. A green *live* dot and an **Activity** list follow the agent's edits.
- **Side-by-side or inline diffs**, with syntax highlighting on both sides
- **Revert or stage per hunk or per file**, then commit from the panel
- **Worktree aware:** review your main checkout (uncommitted changes vs `HEAD`) or any git worktree an agent works in (its branch vs the merge-base with your main branch)

**Edit safely next to agents**
- Autosaves like IntelliJ: on tab switch, app switch, ⌘S and quit
- **Never overwrites a file that changed on disk since you loaded it.** A banner offers *Load Disk Version*, *Keep Mine* or *Discard My Changes*.
- Quitting with unresolved conflicts asks for confirmation first

## Download

**[⬇ Download Margin.dmg (latest build)](https://github.com/jonra/margin/releases/download/latest/Margin.dmg)**: requires a Mac with **Apple silicon (M1 or later)** and **macOS 14+**.

Every push to `main` that passes all tests publishes a fresh DMG to the [latest release](https://github.com/jonra/margin/releases/tag/latest). Tagged versions (`v*`) are published as their own [releases](https://github.com/jonra/margin/releases).

1. Open `Margin.dmg` and drag **Margin** to **Applications**.
2. Install ripgrep for Find in Files: `brew install ripgrep`.
3. Launch Margin and open a folder (⌘O).

> Until builds are notarized by Apple, macOS blocks the first launch ("Apple could not verify…"). Open **System Settings › Privacy & Security** and click **Open Anyway**, or run `xattr -dr com.apple.quarantine /Applications/Margin.app`. See [docs/RELEASING.md](docs/RELEASING.md).

## Requirements (building from source)

- macOS 14 or later
- Swift 6 toolchain. The Xcode **Command Line Tools are enough**; Xcode itself is not required.
- `git`
- [`ripgrep`](https://github.com/BurntSushi/ripgrep) for Find in Files: `brew install ripgrep`

## Build and run

```bash
git clone https://github.com/jonra/margin.git
cd margin
swift test                      # run the test suite
./scripts/bundle-app.sh         # builds build/Margin.app (ad-hoc signed)
open -n build/Margin.app --args -workspace /path/to/your/repo
```

You can also launch without arguments and use **File › Open Folder…** (⌘O).

> Pass the folder with `-workspace <path>`. A bare path argument is treated by AppKit as an "open document" event and stops the main window from appearing.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘O | Open folder |
| ⇧⌘O / Shift Shift | Go to file |
| ⇧⌘F | Find in files |
| ⌘S | Save |
| ⌘1 | Project tree |
| ⌘0 | Changes (review) |

## Reviewing an agent's work

1. Open your repo in Margin and press ⌘0.
2. Start your agent (for example Claude Code) in the same checkout, or in a git worktree (`git worktree add …` or `claude --worktree`).
3. Watch files appear under **Changes** and **Activity** as the agent works. Pick a worktree from the picker at the top to review it.
4. Select a file to see its diff. **Revert Hunk** discards a change on disk. **Stage Hunk** / **Stage File** accept changes into the index; then **Commit Staged**.

Staging and committing are available for the main checkout. For worktrees, Margin offers revert only, because their diff is against the merge-base rather than `HEAD`.

## Project layout

```
Sources/
  MarginSupport/    process runner, tool lookup, path helpers
  MarginSyntax/     tree-sitter highlighting (Java, Python)
  MarginGit/        git CLI wrapper: status, diffs, per-hunk patches, worktrees
  MarginWorkspace/  file listing and tree, FSEvents watcher, TextDocument (conflict-safe saves)
  MarginSearch/     fuzzy file finder, ripgrep search
  MarginReview/     review targets, ReviewEngine (revert/stage/commit), diff rows, activity timeline
  MarginCore/       umbrella module re-exporting the engine
  Margin/           SwiftUI + AppKit macOS app
  TreeSitterJava/, TreeSitterPython/   vendored grammars (generated)
Tests/              Swift Testing suites, run against real temporary git repos
scripts/            vendor-grammars.sh, bundle-app.sh
docs/               architecture, roadmap, design specs and plans
```

Read more in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Coding agents working in this repo should read [AGENTS.md](AGENTS.md).

## License

No license has been chosen yet, so all rights are reserved. Third-party components keep their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
