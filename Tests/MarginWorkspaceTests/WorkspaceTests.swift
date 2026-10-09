import Foundation
import Testing
import MarginTestSupport
@testable import MarginWorkspace

@Test func buildsSortedTreeWithDirectoriesFirst() {
    let tree = FileTree.build(paths: ["src/b.py", "README.md", "src/a/Main.java", "src/A.py", "build.gradle"])

    #expect(tree.map(\.name) == ["src", "build.gradle", "README.md"])
    let src = tree[0]
    #expect(src.isDirectory && src.id == "src")
    #expect(src.children?.map(\.name) == ["a", "A.py", "b.py"])
    #expect(src.children?[0].children?.map(\.id) == ["src/a/Main.java"])
    #expect(tree[1].children == nil)
}

@Test func gitWorkspaceListsFilesRespectingGitignore() async throws {
    let repo = try await TestRepo(files: [".gitignore": "*.log\n", "app.py": "x\n"])
    try repo.write(["debug.log": "noise", "new.py": "y\n"])

    let workspace = await Workspace.open(repo.root)

    #expect(workspace.isGitRepository)
    #expect(Set(try await workspace.listFiles()) == [".gitignore", "app.py", "new.py"])
}

@Test func plainFolderSkipsHiddenAndBuildDirectories() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("plain-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    for path in ["a.py", "pkg/b.py", ".hidden/c.py", "node_modules/d.js", "target/e.class"] {
        let url = dir.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "x".write(to: url, atomically: true, encoding: .utf8)
    }

    let workspace = await Workspace.open(dir)

    #expect(!workspace.isGitRepository)
    #expect(try await workspace.listFiles() == ["a.py", "pkg/b.py"])
}

@Test func watcherReportsChangedRelativePaths() async throws {
    let repo = try await TestRepo(files: ["a.txt": "a\n"])
    let watcher = FileWatcher(root: repo.root, latency: 0.05)
    defer { watcher.stop() }
    try await Task.sleep(for: .milliseconds(300))

    try repo.write(["src/new.py": "x\n"])

    let found = try await withThrowingTaskGroup(of: Bool.self) { group in
        group.addTask {
            for await batch in watcher.events where batch.contains("src/new.py") { return true }
            return false
        }
        group.addTask {
            try await Task.sleep(for: .seconds(5))
            return false
        }
        let result = try await group.next() ?? false
        group.cancelAll()
        return result
    }
    #expect(found)
}

@Test func plainFolderListsSymlinksByTheirOwnName() async throws {
    let base = URL(fileURLWithPath: NSTemporaryDirectory())
    let dir = base.appendingPathComponent("plain-link-\(UUID().uuidString)")
    let outside = base.appendingPathComponent("outside-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.removeItem(at: outside)
    }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try "x".write(to: dir.appendingPathComponent("a.py"), atomically: true, encoding: .utf8)
    let target = outside.appendingPathComponent("target.py")
    try "y".write(to: target, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("link.py"), withDestinationURL: target)

    let workspace = await Workspace.open(dir)

    #expect(!workspace.isGitRepository)
    #expect(try await workspace.listFiles() == ["a.py", "link.py"])
}

@Test func watcherEventsFinishAfterStop() async throws {
    let repo = try await TestRepo(files: ["a.txt": "a\n"])
    let watcher = FileWatcher(root: repo.root, latency: 0.05)
    watcher.stop()

    let finished = try await withThrowingTaskGroup(of: Bool.self) { group in
        group.addTask {
            for await _ in watcher.events {}
            return true
        }
        group.addTask {
            try await Task.sleep(for: .seconds(5))
            return false
        }
        let result = try await group.next() ?? false
        group.cancelAll()
        return result
    }
    #expect(finished)
}
