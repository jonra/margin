import Foundation

public struct Worktree: Equatable, Sendable, Identifiable {
    public let path: URL
    public let head: String
    /// Short branch name ("main"), nil when detached or bare.
    public let branch: String?
    public let isBare: Bool

    public var id: String { path.path }
    public var displayName: String { branch ?? "\(path.lastPathComponent) (detached)" }
}

public enum WorktreeParser {
    /// Parses `git worktree list --porcelain`.
    public static func parse(_ output: String) -> [Worktree] {
        output.components(separatedBy: "\n\n").compactMap { block in
            var path: String?, head = "", branch: String?, bare = false
            for line in block.split(separator: "\n") {
                if line.hasPrefix("worktree ") { path = String(line.dropFirst("worktree ".count)) }
                else if line.hasPrefix("HEAD ") { head = String(line.dropFirst("HEAD ".count)) }
                else if line.hasPrefix("branch ") {
                    let ref = line.dropFirst("branch ".count)
                    branch = ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : String(ref)
                }
                else if line == "bare" { bare = true }
            }
            guard let path else { return nil }
            return Worktree(path: URL(fileURLWithPath: path), head: head, branch: branch, isBare: bare)
        }
    }
}
