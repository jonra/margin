import Foundation

public enum ChangeKind: String, Sendable {
    case added, modified, deleted, renamed, untracked, conflicted
}

/// One entry of `git status --porcelain=v2`.
public struct FileStatus: Equatable, Sendable {
    public let path: String
    public let originalPath: String?
    /// Staged state (X) and worktree state (Y), using git's letters ("." = unchanged).
    public let index: Character
    public let worktree: Character
    public let kind: ChangeKind

    public init(path: String, originalPath: String? = nil, index: Character, worktree: Character, kind: ChangeKind) {
        self.path = path
        self.originalPath = originalPath
        self.index = index
        self.worktree = worktree
        self.kind = kind
    }
}

public enum StatusParser {
    /// Parses NUL-separated output of `git status --porcelain=v2 -z --untracked-files=all`.
    public static func parse(_ output: String) -> [FileStatus] {
        var entries = output.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)[...]
        var result: [FileStatus] = []
        while let entry = entries.popFirst() {
            guard let type = entry.first else { continue }
            switch type {
            case "1":
                let fields = entry.split(separator: " ", maxSplits: 8).map(String.init)
                guard fields.count == 9 else { continue }
                let (x, y) = xy(fields[1])
                result.append(FileStatus(path: fields[8], index: x, worktree: y, kind: kind(x, y)))
            case "2":
                let fields = entry.split(separator: " ", maxSplits: 9).map(String.init)
                guard fields.count == 10 else { continue }
                let (x, y) = xy(fields[1])
                let original = entries.popFirst()
                result.append(FileStatus(path: fields[9], originalPath: original, index: x, worktree: y, kind: .renamed))
            case "u":
                let fields = entry.split(separator: " ", maxSplits: 10).map(String.init)
                guard fields.count == 11 else { continue }
                let (x, y) = xy(fields[1])
                result.append(FileStatus(path: fields[10], index: x, worktree: y, kind: .conflicted))
            case "?":
                result.append(FileStatus(path: String(entry.dropFirst(2)), index: "?", worktree: "?", kind: .untracked))
            default:
                continue
            }
        }
        return result
    }

    private static func xy(_ field: String) -> (Character, Character) {
        let chars = Array(field)
        return (chars.first ?? ".", chars.count > 1 ? chars[1] : ".")
    }

    private static func kind(_ x: Character, _ y: Character) -> ChangeKind {
        if x == "A" { return .added }
        if x == "D" || y == "D" { return .deleted }
        return .modified
    }
}
