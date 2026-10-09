import Foundation
import MarginSupport

/// A throwaway git repository in a temp directory, for tests.
public final class TestRepo {
    public let root: URL

    public init(files: [String: String] = [:], commitMessage: String = "initial") async throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("margin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // Resolve /var -> /private/var so paths match what git and FSEvents report.
        root = URL(fileURLWithPath: base.path.resolvingRealPath())
        try await git("init", "-q", "-b", "main")
        try await git("config", "user.email", "test@example.com")
        try await git("config", "user.name", "Test")
        try await git("config", "commit.gpgsign", "false")
        if !files.isEmpty {
            try write(files)
            try await commitAll(commitMessage)
        }
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    public func url(_ path: String) -> URL { root.appendingPathComponent(path) }

    public func write(_ files: [String: String]) throws {
        for (path, content) in files {
            let url = url(path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    public func read(_ path: String) throws -> String { try String(contentsOf: url(path), encoding: .utf8) }

    public func delete(_ path: String) throws { try FileManager.default.removeItem(at: url(path)) }

    public func commitAll(_ message: String) async throws {
        try await git("add", "-A")
        try await git("commit", "-q", "-m", message)
    }

    @discardableResult
    public func git(_ args: String...) async throws -> String { try await git(args) }

    @discardableResult
    public func git(_ args: [String]) async throws -> String {
        let result = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/env"), ["git", "-C", root.path] + args)
        guard result.status == 0 else {
            throw ProcessError(command: "git \(args.joined(separator: " "))", status: result.status, stderr: result.stderrString)
        }
        return result.stdoutString
    }
}
