import Foundation
import Testing
import MarginTestSupport
@testable import MarginGit

@Test func statusReportsModifiedDeletedAndUntracked() async throws {
    let repo = try await TestRepo(files: ["a.txt": "a\n", "b.txt": "b\n"])
    try repo.write(["a.txt": "changed\n", "new/c.py": "print(1)\n"])
    try repo.delete("b.txt")

    let status = try await Git(root: repo.root).status()

    #expect(status.map(\.path) == ["a.txt", "b.txt", "new/c.py"])
    #expect(status.map(\.kind) == [.modified, .deleted, .untracked])
}

@Test func listFilesRespectsGitignoreAndSkipsDeletedFiles() async throws {
    let repo = try await TestRepo(files: [".gitignore": "build/\n", "src/A.java": "class A {}\n", "old.txt": "x\n"])
    try repo.write(["build/out.class": "bin", "notes.md": "n\n"])
    try repo.delete("old.txt")

    let files = try await Git(root: repo.root).listFiles()

    #expect(Set(files) == [".gitignore", "src/A.java", "notes.md"])
}

@Test func diffWorkingTreeIncludesTrackedAndUntrackedChanges() async throws {
    let repo = try await TestRepo(files: ["a.txt": "one\ntwo\n"])
    try repo.write(["a.txt": "one\n2\n", "z.txt": "new\n"])
    let git = try Git(root: repo.root)

    let diffs = try await git.diffWorkingTree(against: "HEAD")

    #expect(diffs.map(\.path) == ["a.txt", "z.txt"])
    #expect(diffs[0].additions == 1 && diffs[0].deletions == 1)
    #expect(diffs[1].isNewFile && diffs[1].additions == 1)
}

@Test func diffWorksInRepositoryWithoutCommits() async throws {
    let repo = try await TestRepo()
    try repo.write(["first.py": "x = 1\n"])
    let git = try Git(root: repo.root)

    #expect(try await git.headCommit() == nil)
    let diffs = try await git.diffWorkingTree(against: Git.emptyTree)
    #expect(diffs.map(\.path) == ["first.py"])
}

@Test func reverseApplyingAHunkRevertsOnlyThatHunk() async throws {
    let lines = (1...30).map { "line \($0)" }
    let repo = try await TestRepo(files: ["f.txt": lines.joined(separator: "\n") + "\n"])
    var edited = lines
    edited[1] = "CHANGED 2"
    edited[27] = "CHANGED 28"
    try repo.write(["f.txt": edited.joined(separator: "\n") + "\n"])
    let git = try Git(root: repo.root)
    let file = try await git.diffWorkingTree(against: "HEAD")[0]
    #expect(file.hunks.count == 2)

    try await git.apply(patch: file.patch(only: file.hunks[0]), reverse: true)

    let content = try repo.read("f.txt")
    #expect(content.contains("line 2\n") && content.contains("CHANGED 28"))
}

@Test func stagingAHunkPutsOnlyThatHunkInTheIndex() async throws {
    let lines = (1...30).map { "line \($0)" }
    let repo = try await TestRepo(files: ["f.txt": lines.joined(separator: "\n") + "\n"])
    var edited = lines
    edited[1] = "CHANGED 2"
    edited[27] = "CHANGED 28"
    try repo.write(["f.txt": edited.joined(separator: "\n") + "\n"])
    let git = try Git(root: repo.root)
    let file = try await git.diffWorkingTree(against: "HEAD")[0]

    try await git.apply(patch: file.patch(only: file.hunks[1]), cached: true)

    let staged = try await repo.git("diff", "--cached")
    #expect(staged.contains("+CHANGED 28") && !staged.contains("CHANGED 2\n"))
}

@Test func reverseApplyingANewFilePatchDeletesTheFile() async throws {
    let repo = try await TestRepo(files: ["a.txt": "a\n"])
    try repo.write(["agent.py": "print('hi')\n"])
    let git = try Git(root: repo.root)
    let file = try await git.diffWorkingTree(against: "HEAD").first { $0.path == "agent.py" }!

    try await git.apply(patch: file.patch(), reverse: true)

    #expect(!FileManager.default.fileExists(atPath: repo.url("agent.py").path))
}

@Test func showReturnsContentAtRevisionOrNil() async throws {
    let repo = try await TestRepo(files: ["a.txt": "v1\n"])
    try repo.write(["a.txt": "v2\n"])
    let git = try Git(root: repo.root)

    #expect(try await git.show(path: "a.txt", revision: "HEAD") == "v1\n")
    #expect(try await git.show(path: "missing.txt", revision: "HEAD") == nil)
}

@Test func worktreesAndMergeBase() async throws {
    let repo = try await TestRepo(files: ["a.txt": "a\n"])
    let base = try await repo.git("rev-parse", "HEAD").trimmingCharacters(in: .whitespacesAndNewlines)
    let wtPath = repo.root.deletingLastPathComponent().appendingPathComponent("wt-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: wtPath) }
    try await repo.git("worktree", "add", "-q", "-b", "agent/task-1", wtPath.path)
    try await repo.git("-C", wtPath.path, "commit", "-q", "--allow-empty", "-m", "agent work")
    let git = try Git(root: repo.root)

    let worktrees = try await git.worktrees()

    #expect(worktrees.map(\.branch) == ["main", "agent/task-1"])
    #expect(worktrees[1].path.lastPathComponent == wtPath.lastPathComponent)
    #expect(try await git.mergeBase("main", "agent/task-1") == base)
}

@Test func stageUnstageAndCommit() async throws {
    let repo = try await TestRepo(files: ["a.txt": "a\n"])
    try repo.write(["a.txt": "b\n"])
    let git = try Git(root: repo.root)

    try await git.stage(paths: ["a.txt"])
    #expect(try await git.status().first?.index == "M")
    try await git.unstage(paths: ["a.txt"])
    #expect(try await git.status().first?.index == ".")
    try await git.stage(paths: ["a.txt"])
    try await git.commit(message: "update a")
    #expect(try await git.status().isEmpty)
}
