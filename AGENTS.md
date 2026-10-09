# Agent instructions

Instructions for AI coding agents (Claude Code, Codex, …) working in this repository.

## Commands

```bash
swift build                     # build everything
swift test                      # full suite (Swift Testing), must stay green
swift test --filter MarginGitTests
./scripts/bundle-app.sh         # build/Margin.app
open -n build/Margin.app --args -workspace /path/to/repo   # never pass a bare path
```

## Rules

- Pure SwiftPM. There is no Xcode project, and Xcode may not be installed. Don't add one, and don't use `xcodebuild` or XCTest.
- Tests use `import Testing` (`@Test`, `#expect`). Add a failing test first for every engine change.
- Feature logic belongs in the engine (`MarginSupport`, `MarginSyntax`, `MarginGit`, `MarginWorkspace`, `MarginSearch`, `MarginReview`). `Sources/Margin` (the app) stays thin. Engine targets must not import SwiftUI or AppKit.
- Git is accessed only through `Git` (`Sources/MarginGit/Git.swift`) with machine-readable output, forced `a/`/`b/` diff prefixes and `--no-textconv`. Read-only commands use `--no-optional-locks`.
- Saving, reverting and staging must never silently drop user edits or overwrite external changes. Keep `TextDocument` and `ReviewEngine` invariants intact, with tests.
- Do not hand-edit `Sources/TreeSitter*` or `Sources/MarginSyntax/HighlightQueries.swift`. Regenerate them with `scripts/vendor-grammars.sh`.
- Keep the build warning-free. Swift 5 language mode on the Swift 6 toolchain.

## Where things are

- Architecture: `docs/ARCHITECTURE.md`
- Roadmap: `docs/ROADMAP.md`
- Specs and plans: `docs/superpowers/specs/`, `docs/superpowers/plans/`
