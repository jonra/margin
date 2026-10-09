import MarginGit

public struct SideBySideRow: Equatable, Sendable {
    public let left: DiffLine?
    public let right: DiffLine?
}

public enum SideBySide {
    /// Aligns a hunk into two columns: context on both sides, removed lines paired with added lines.
    public static func rows(for hunk: Hunk) -> [SideBySideRow] {
        var rows: [SideBySideRow] = []
        var removed: [DiffLine] = []
        var added: [DiffLine] = []
        func flush() {
            for i in 0..<max(removed.count, added.count) {
                rows.append(SideBySideRow(left: i < removed.count ? removed[i] : nil, right: i < added.count ? added[i] : nil))
            }
            removed.removeAll()
            added.removeAll()
        }
        for line in hunk.lines {
            switch line.kind {
            case .removed: removed.append(line)
            case .added: added.append(line)
            case .context:
                flush()
                rows.append(SideBySideRow(left: line, right: line))
            case .noNewline:
                continue
            }
        }
        flush()
        return rows
    }
}
