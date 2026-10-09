# Third-party notices

Margin includes or depends on the following third-party software. Each component is under its own license.

| Component | Version | How it is used | License |
|---|---|---|---|
| [tree-sitter](https://github.com/tree-sitter/tree-sitter) | 0.25.10 | Parsing runtime (SwiftPM dependency, via SwiftTreeSitter) | MIT, © 2018-2024 Max Brunsfeld |
| [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter) | 0.25.0 | Swift bindings for tree-sitter (SwiftPM dependency) | BSD 3-Clause, © 2021 Chime |
| [tree-sitter-java](https://github.com/tree-sitter/tree-sitter-java) | v0.23.5 | Java grammar, vendored in `Sources/TreeSitterJava`; highlight query embedded in `Sources/MarginSyntax/HighlightQueries.swift` | MIT, © 2017 Ayman Nadeem. See `Sources/TreeSitterJava/LICENSE` |
| [tree-sitter-python](https://github.com/tree-sitter/tree-sitter-python) | v0.25.0 | Python grammar, vendored in `Sources/TreeSitterPython`; highlight query embedded in `Sources/MarginSyntax/HighlightQueries.swift` | MIT, © 2016 Max Brunsfeld. See `Sources/TreeSitterPython/LICENSE` |

At runtime, Margin also invokes these external tools, installed separately by the user: `git` and [`ripgrep`](https://github.com/BurntSushi/ripgrep) (MIT / Unlicense).
