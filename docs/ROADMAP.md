# Roadmap

| Milestone | Scope | Status |
|---|---|---|
| **M1: Browser** | App shell, project tree, tabs, Java/Python highlighting, Go to File, Find in Files | ✅ Done (v0.1) |
| **M2: Agent review** | Live Changes panel, side-by-side/inline diffs, revert/stage per hunk and file, commit, worktree targets, activity timeline | ✅ Done (v0.1) |
| **Text editor** | Make Margin a general-purpose editor: highlighting for txt, html, json, yaml, css, markdown, xml, js/ts, shell, toml, sql; open single files (Open With, default app, drop on Dock icon); line numbers, find & replace, go to line, multiple windows; JSON/YAML pretty-print and validation with parse errors | Next |
| **M3: Navigation** | Language servers (jdtls for Java, basedpyright for Python): go to definition, find usages, symbol search, hover; falls back to text search | Planned |
| **M3b: margin-mcp** | A stdio MCP server over MarginCore that gives agents read-only, IDE-grade tools: find file, search, symbols, definition, references, diagnostics, git status/diff/blame | Planned |
| **M4: Git tooling** | Log, file history, blame gutter, branches, commit dialog | Planned |
| **M5: Polish** | Formatters (google-java-format, ruff), IntelliJ-style keymap, settings | Planned |
| **Phase 2: Agents** | Task → its own worktree → agent session streamed live in the app → review → merge; MCP write tools with permission controls | Planned |

Design specs and implementation plans live in [`docs/superpowers/`](superpowers/).
