# Contributing

## Setup

- macOS 14+, Swift 6 toolchain (`xcode-select --install` is enough; no Xcode needed), `git`, `ripgrep` (`brew install ripgrep`).

```bash
swift build
swift test
./scripts/bundle-app.sh && open -n build/Margin.app --args -workspace "$PWD"
```

## Ground rules

- **Engine first.** Feature logic goes in the engine modules (`Sources/Margin*`, everything except `Sources/Margin/`). The app target `Sources/Margin` only presents engine state. Engine modules must not import SwiftUI or AppKit.
- **Test-driven.** Write a failing test, make it pass, then refactor. Engine behaviour is tested against real temporary git repositories (`Tests/MarginTestSupport/TestRepo.swift`), not mocks.
- **Swift Testing, not XCTest.** Use `import Testing`, `@Test` and `#expect`. XCTest is not available with the Command Line Tools alone.
- **Git via the CLI only**, through `Git` in `MarginGit`. Parse machine-readable output only. Read-only commands use `--no-optional-locks`. Never modify the user's index implicitly.
- **Never lose user or agent work.** Any change touching saving, reverting or staging needs a test showing that nothing is silently overwritten or dropped.
- **External tools** are found through `ToolLocator`. A missing tool must surface as `MissingToolError` with an install hint, never as a crash.
- Swift 6 toolchain with Swift 5 language mode (`swiftLanguageModes: [.v5]`). Keep the build free of warnings.

## Grammars

Tree-sitter grammars are vendored. To update them, edit the tags in `scripts/vendor-grammars.sh`, run it, and commit the regenerated `Sources/TreeSitter*` and `Sources/MarginSyntax/HighlightQueries.swift`. Do not edit generated files by hand.

## Commits

- Small, focused commits, conventional prefixes (`feat(review): …`, `fix(git): …`, `docs: …`).
- `swift build` and `swift test` must be green before every commit.

## Design docs

Larger changes start with a design spec in `docs/superpowers/specs/` and an implementation plan in `docs/superpowers/plans/`. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/ROADMAP.md](docs/ROADMAP.md).
