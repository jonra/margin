# Changelog

## 0.1.0: Browser + agent review (M1, M2)

### Added
- Headless engine `MarginCore`: process and tool support, tree-sitter syntax (Java, Python), git CLI wrapper with porcelain/diff parsers and per-hunk patches, workspace listing and FSEvents watcher, fuzzy file finder, ripgrep search, review engine.
- macOS app: project tree, tabbed editor with highlighting, Go to File (⇧⌘O / double-Shift), Find in Files (⇧⌘F).
- Live Changes panel (⌘0) with side-by-side/inline diffs, revert/stage per hunk and file, commit, git worktree targets, live indicator and Activity timeline.
- Conflict-safe editing (`TextDocument`): autosave never overwrites files changed on disk; Load Disk Version / Keep Mine / Discard My Changes; confirmation on quit with unresolved conflicts.
- `scripts/bundle-app.sh` (build `Margin.app` without Xcode) and `scripts/vendor-grammars.sh`.

### Safety fixes from review
- Reverting a hunk also removes that exact staged hunk from the index, matched by content. A worktree-derived patch is never applied to the index.
- Reverting a hunk of a new file asks for confirmation, because it deletes the file.
- Paths with spaces are handled (git's trailing-tab path terminator).
- Diffs are independent of user git config (`diff.noprefix`, `diff.mnemonicPrefix`, textconv).
- Background git reads use `--no-optional-locks`, so they don't collide with an agent's git commands.
- Ignore SIGPIPE when writing to child processes.
- Saving through a symlink keeps the link.
- Stale refresh results are dropped (generation counter), and delete-only change batches refresh live.
