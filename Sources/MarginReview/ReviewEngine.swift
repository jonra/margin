import Foundation
import MarginGit

public struct ChangedFile: Identifiable, Equatable, Sendable {
    public let diff: FileDiff
    public let kind: ChangeKind

    public var id: String { diff.path }
    public var path: String { diff.path }
}

public struct ReviewError: Error, CustomStringConvertible, Sendable {
    public let description: String
}

/// Computes and acts on the changes of a review target. Stateless: the disk and git are the source of truth.
public struct ReviewEngine: Sendable {
    public let target: ReviewTarget
    private let git: Git

    public init(target: ReviewTarget) throws {
        self.target = target
        self.git = try Git(root: target.root)
    }

    /// The commit the target is compared against.
    public func baseRevision() async throws -> String {
        switch target {
        case .workingTree:
            return try await git.headCommit() ?? Git.emptyTree
        case .worktree(_, _, let baseBranch):
            return try await git.mergeBase(baseBranch, "HEAD")
        }
    }

    public func changes() async throws -> [ChangedFile] {
        let diffs = try await git.diffWorkingTree(against: try await baseRevision())
        return diffs.map { diff in
            let kind: ChangeKind = diff.isNewFile ? .added : diff.isDeletedFile ? .deleted : .modified
            return ChangedFile(diff: diff, kind: kind)
        }
    }

    /// Old (base) and new (working tree) contents, for side-by-side display.
    public func contents(of file: ChangedFile) async throws -> (old: String?, new: String?) {
        var old: String?
        if let oldPath = file.diff.oldPath {
            old = try await git.show(path: oldPath, revision: try await baseRevision())
        }
        let new = file.diff.newPath.flatMap { try? String(contentsOf: target.root.appendingPathComponent($0), encoding: .utf8) }
        return (old, new)
    }

    // MARK: Actions

    public func revert(_ hunk: Hunk, in file: ChangedFile) async throws {
        try requireText(file)
        try await git.apply(patch: file.diff.patch(only: hunk), reverse: true)
        guard target.allowsStaging else { return }
        // Drop the same change from the index, but only via a patch derived from the index itself:
        // the worktree-derived patch could match a different location there.
        func changedLines(_ h: Hunk) -> [String] { h.lines.filter { $0.kind == .added || $0.kind == .removed }.map(\.raw) }
        let wanted = changedLines(hunk)
        let staged = try await git.diffStaged(path: file.path).first { $0.path == file.path }
        guard let staged, !staged.hunks.isEmpty else { return }
        if let match = staged.hunks.first(where: { changedLines($0) == wanted }) {
            try await git.apply(patch: staged.patch(only: match), reverse: true, cached: true)
        } else {
            throw ReviewError(description: "\(file.path): the hunk was reverted in the working tree, but the file has other staged changes that do not match it, so the index was left untouched. Unstage or review the staged changes with git.")
        }
    }

    public func revert(_ file: ChangedFile) async throws {
        try requireText(file)
        try await git.apply(patch: file.diff.patch(), reverse: true)
        // Drop any staged version too, so the file is fully back to base.
        if target.allowsStaging { try await git.unstage(paths: [file.path]) }
    }

    public func stage(_ hunk: Hunk, in file: ChangedFile) async throws {
        try requireStaging()
        try requireText(file)
        try await git.apply(patch: file.diff.patch(only: hunk), cached: true)
    }

    public func stage(_ file: ChangedFile) async throws {
        try requireStaging()
        try await git.stage(paths: [file.path])
    }

    public func commit(message: String) async throws {
        try requireStaging()
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReviewError(description: "Commit message is empty.")
        }
        try await git.commit(message: message)
    }

    private func requireStaging() throws {
        guard target.allowsStaging else {
            throw ReviewError(description: "Staging is only available when reviewing uncommitted changes.")
        }
    }

    private func requireText(_ file: ChangedFile) throws {
        guard !file.diff.isBinary else { throw ReviewError(description: "\(file.path) is binary; revert it with git.") }
    }
}
