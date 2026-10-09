import Foundation
import MarginGit
import MarginSupport

/// An opened folder. Lists files (respecting .gitignore when it is a git repo).
public struct Workspace: Sendable {
    public let root: URL
    public let isGitRepository: Bool

    /// Directories skipped when the folder is not a git repo.
    static let skippedDirectories: Set<String> = [".git", "node_modules", ".build", "build", "target", "__pycache__", ".venv", ".idea"]
    static let maxFiles = 200_000

    public static func open(_ url: URL) async -> Workspace {
        let root = URL(fileURLWithPath: url.path.resolvingRealPath())
        return Workspace(root: root, isGitRepository: await Git.isRepository(root))
    }

    public func listFiles() async throws -> [String] {
        if isGitRepository { return try await Git(root: root).listFiles() }
        return enumerateFiles()
    }

    private func enumerateFiles() -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        let prefixLength = root.path.count + 1
        var result: [String] = []
        for case let url as URL in enumerator {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                if Self.skippedDirectories.contains(url.lastPathComponent) { enumerator.skipDescendants() }
                continue
            }
            result.append(String(url.path.resolvingRealPath().dropFirst(prefixLength)))
            if result.count >= Self.maxFiles { break }
        }
        return result.sorted()
    }
}
