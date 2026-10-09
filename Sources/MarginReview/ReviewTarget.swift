import Foundation
import MarginGit

/// What is being reviewed.
public enum ReviewTarget: Hashable, Sendable, Identifiable {
    /// Uncommitted changes (staged + unstaged + untracked) in a checkout, vs HEAD.
    case workingTree(root: URL)
    /// Everything an agent did in a worktree (commits + uncommitted), vs the merge-base with `baseBranch`.
    case worktree(root: URL, branch: String, baseBranch: String)

    public var id: String { root.path }

    public var root: URL {
        switch self {
        case .workingTree(let root), .worktree(let root, _, _): return root
        }
    }

    /// Staging/committing only makes sense against HEAD of the reviewed checkout.
    public var allowsStaging: Bool {
        if case .workingTree = self { return true }
        return false
    }

    public var title: String {
        switch self {
        case .workingTree(let root): return "\(root.lastPathComponent) — uncommitted"
        case .worktree(_, let branch, let base): return "\(branch) vs \(base)"
        }
    }

    /// One target per worktree: the main checkout reviews uncommitted work,
    /// every other worktree reviews its branch against the main checkout's branch.
    public static func all(from worktrees: [Worktree]) -> [ReviewTarget] {
        let usable = worktrees.filter { !$0.isBare }
        guard let main = usable.first else { return [] }
        let base = main.branch ?? main.head
        return [.workingTree(root: main.path)] + usable.dropFirst().map {
            .worktree(root: $0.path, branch: $0.displayName, baseBranch: base)
        }
    }
}
