# Margin

Native macOS code browser and agent-change reviewer (Java/Python). Engine: `MarginCore`; app: `Margin`.

## Requirements
- macOS 14+, Swift 6 toolchain (Command Line Tools are enough), git, ripgrep (`brew install ripgrep`).

## Build & run
    swift test
    ./scripts/bundle-app.sh
    open -n build/Margin.app --args -workspace /path/to/repo

## Shortcuts
⌘O open folder · ⇧⌘O / double-Shift go to file · ⇧⌘F find in files · ⌘S save · ⌘1 project · ⌘0 changes

## Editing safety
Margin autosaves (tab switch, app switch, ⌘S, quit) but never overwrites a file that changed on disk since it was loaded (e.g. by an agent).
Instead a banner offers "Load Disk Version" or "Keep Mine".
Quitting with unresolved conflicts asks for confirmation.

## Reviewing agent changes
⌘0 opens Changes. The picker switches between the main checkout (uncommitted vs HEAD, stage/commit allowed) and each git worktree (branch vs merge-base with main, revert only).
The green "live" dot and Activity list follow an agent's edits.

## Updating grammars
Edit the tags in `scripts/vendor-grammars.sh`, run it, commit the regenerated sources.
