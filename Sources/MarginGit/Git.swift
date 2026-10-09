import Foundation
import MarginSupport

/// Typed wrapper around the git CLI for one working tree.
public struct Git: Sendable {
    /// Hash of git's empty tree, used as the base when a repo has no commits yet.
    public static let emptyTree = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

    public let root: URL
    private let executable: URL

    public init(root: URL) throws {
        self.root = root
        self.executable = try ToolLocator.require("git", installHint: "xcode-select --install")
    }

    // MARK: Queries

    public static func isRepository(_ url: URL) async -> Bool {
        guard let git = try? Git(root: url) else { return false }
        return (try? await git.run(["rev-parse", "--is-inside-work-tree"], readOnly: true))?.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    public func status() async throws -> [FileStatus] {
        StatusParser.parse(try await run(["status", "--porcelain=v2", "-z", "--untracked-files=all"], readOnly: true))
    }

    /// Tracked and untracked (non-ignored) files that exist on disk, repo-relative.
    public func listFiles() async throws -> [String] {
        let output = try await run(["ls-files", "--cached", "--others", "--exclude-standard", "-z"], readOnly: true)
        var seen = Set<String>()
        return output.split(separator: "\0").map(String.init).filter { path in
            seen.insert(path).inserted
                && FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path)
        }
    }

    /// HEAD's commit hash, or nil in a repository without commits.
    public func headCommit() async throws -> String? {
        let result = try await ProcessRunner.run(executable, readOnlyPrefix + ["rev-parse", "--verify", "-q", "HEAD"])
        return result.status == 0 ? result.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    public func mergeBase(_ a: String, _ b: String) async throws -> String {
        try await run(["merge-base", a, b], readOnly: true).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func worktrees() async throws -> [Worktree] {
        WorktreeParser.parse(try await run(["worktree", "list", "--porcelain"], readOnly: true))
    }

    /// Diff of `base` (a commit) against the working tree, including untracked files.
    public func diffWorkingTree(against base: String) async throws -> [FileDiff] {
        var diffs = DiffParser.parse(try await run(["diff", "--no-color", "--no-ext-diff", "--no-textconv", "--src-prefix=a/", "--dst-prefix=b/", "--no-renames", base], readOnly: true))
        for status in try await status() where status.kind == .untracked {
            diffs.append(contentsOf: DiffParser.parse(try await untrackedDiff(status.path)))
        }
        return diffs.sorted { $0.path < $1.path }
    }

    /// Staged changes (index vs HEAD) of one path; empty when nothing is staged for it.
    public func diffStaged(path: String) async throws -> [FileDiff] {
        let base = try await headCommit() != nil ? [] : [Git.emptyTree]
        return DiffParser.parse(try await run(
            ["diff", "--cached", "--no-color", "--no-ext-diff", "--no-renames", "--no-textconv",
             "--src-prefix=a/", "--dst-prefix=b/"] + base + ["--", path], readOnly: true))
    }

    /// File contents at a revision, or nil if the file does not exist there.
    public func show(path: String, revision: String) async throws -> String? {
        let result = try await ProcessRunner.run(executable, readOnlyPrefix + ["show", "\(revision):\(path)"])
        return result.status == 0 ? result.stdoutString : nil
    }

    // MARK: Mutations

    /// Applies a patch to the working tree (or to the index when `cached`).
    public func apply(patch: String, reverse: Bool = false, cached: Bool = false) async throws {
        var args = ["apply", "--whitespace=nowarn"]
        if reverse { args.append("-R") }
        if cached { args.append("--cached") }
        try await run(args + ["-"], stdin: Data(patch.utf8))
    }

    public func stage(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        try await run(["add", "-A", "--"] + paths)
    }

    public func unstage(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        guard try await headCommit() != nil else {
            try await run(["rm", "-q", "--cached", "--ignore-unmatch", "--"] + paths)
            return
        }
        try await run(["reset", "-q", "HEAD", "--"] + paths)
    }

    public func commit(message: String) async throws {
        try await run(["commit", "-q", "-m", message])
    }

    // MARK: Plumbing

    @discardableResult
    func run(_ args: [String], stdin: Data? = nil, readOnly: Bool = false) async throws -> String {
        let prefix = readOnly ? readOnlyPrefix : mutatingPrefix
        let result = try await ProcessRunner.run(executable, prefix + args, stdin: stdin)
        guard result.status == 0 else {
            throw ProcessError(command: "git " + args.joined(separator: " "), status: result.status, stderr: result.stderrString)
        }
        return result.stdoutString
    }

    private var mutatingPrefix: [String] { ["-C", root.path, "-c", "core.quotePath=false"] }

    /// Read-only commands skip optional locks so background polling never collides with agents' index.lock.
    private var readOnlyPrefix: [String] { ["-C", root.path, "--no-optional-locks", "-c", "core.quotePath=false"] }

    private func untrackedDiff(_ path: String) async throws -> String {
        // --no-index exits with 1 when files differ, which is always the case here.
        let result = try await ProcessRunner.run(
            executable, readOnlyPrefix + ["diff", "--no-color", "--no-ext-diff", "--no-textconv", "--src-prefix=a/", "--dst-prefix=b/", "--no-index", "--", "/dev/null", path])
        guard result.status <= 1 else {
            throw ProcessError(command: "git diff --no-index \(path)", status: result.status, stderr: result.stderrString)
        }
        return result.stdoutString
    }
}
