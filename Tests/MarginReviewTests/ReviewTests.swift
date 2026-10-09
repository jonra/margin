import Foundation
import Testing
import MarginGit
import MarginTestSupport
@testable import MarginReview

private let thirtyLines = (1...30).map { "line \($0)" }.joined(separator: "\n") + "\n"

private func editTwoHunks(_ repo: TestRepo) throws {
    var lines = thirtyLines.components(separatedBy: "\n")
    lines[1] = "CHANGED 2"
    lines[27] = "CHANGED 28"
    try repo.write(["f.txt": lines.joined(separator: "\n")])
}

@Test func workingTreeTargetListsChangesWithKinds() async throws {
    let repo = try await TestRepo(files: ["f.txt": thirtyLines, "gone.txt": "x\n"])
    try editTwoHunks(repo)
    try repo.delete("gone.txt")
    try repo.write(["new.py": "print(1)\n"])

    let changes = try await ReviewEngine(target: .workingTree(root: repo.root)).changes()

    #expect(changes.map(\.path) == ["f.txt", "gone.txt", "new.py"])
    #expect(changes.map(\.kind) == [.modified, .deleted, .added])
    #expect(changes[0].diff.hunks.count == 2)
}

@Test func revertHunkAndRevertFile() async throws {
    let repo = try await TestRepo(files: ["f.txt": thirtyLines])
    try editTwoHunks(repo)
    try repo.write(["new.py": "print(1)\n"])
    let engine = try ReviewEngine(target: .workingTree(root: repo.root))

    var changes = try await engine.changes()
    try await engine.revert(changes[0].diff.hunks[0], in: changes[0])
    changes = try await engine.changes()
    #expect(changes[0].diff.hunks.count == 1)
    #expect(try repo.read("f.txt").contains("CHANGED 28"))

    try await engine.revert(changes[0])
    try await engine.revert(changes[1])
    #expect(try await engine.changes().isEmpty)
    #expect(try repo.read("f.txt") == thirtyLines)
}

@Test func stageHunkThenCommit() async throws {
    let repo = try await TestRepo(files: ["f.txt": thirtyLines])
    try editTwoHunks(repo)
    let engine = try ReviewEngine(target: .workingTree(root: repo.root))
    let file = try await engine.changes()[0]

    try await engine.stage(file.diff.hunks[1], in: file)
    try await engine.commit(message: "accept second hunk")

    let remaining = try await engine.changes()
    #expect(remaining.count == 1 && remaining[0].diff.hunks.count == 1)
    #expect(remaining[0].diff.hunks[0].lines.contains { $0.text == "CHANGED 2" })
}

@Test func revertingAFileThatWasStagedLeavesNothingBehind() async throws {
    let repo = try await TestRepo(files: ["f.txt": thirtyLines])
    try editTwoHunks(repo)
    let engine = try ReviewEngine(target: .workingTree(root: repo.root))
    try await engine.stage(try await engine.changes()[0])

    try await engine.revert(try await engine.changes()[0])

    #expect(try await engine.changes().isEmpty)
    #expect(try await repo.git("status", "--porcelain").isEmpty)
}

@Test func worktreeTargetShowsAgentCommitsAndUncommittedWork() async throws {
    let repo = try await TestRepo(files: ["app.py": "a = 1\n"])
    let wt = repo.root.deletingLastPathComponent().appendingPathComponent("wt-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: wt) }
    try await repo.git("worktree", "add", "-q", "-b", "agent/x", wt.path)
    try "a = 2\n".write(to: wt.appendingPathComponent("app.py"), atomically: true, encoding: .utf8)
    try await repo.git("-C", wt.path, "commit", "-q", "-am", "agent commit")
    try "print('wip')\n".write(to: wt.appendingPathComponent("wip.py"), atomically: true, encoding: .utf8)

    let targets = ReviewTarget.all(from: try await Git(root: repo.root).worktrees())
    #expect(targets.count == 2)
    #expect(targets[1].title == "agent/x vs main")
    let engine = try ReviewEngine(target: targets[1])
    let changes = try await engine.changes()

    #expect(changes.map(\.path) == ["app.py", "wip.py"])
    let contents = try await engine.contents(of: changes[0])
    #expect(contents.old == "a = 1\n" && contents.new == "a = 2\n")
    await #expect(throws: ReviewError.self) { try await engine.stage(changes[0]) }
}

@Test func sideBySidePairsRemovedAndAddedLines() {
    let diff = DiffParser.parse("""
    diff --git a/f b/f
    --- a/f
    +++ b/f
    @@ -1,4 +1,4 @@
     keep
    -old 1
    -old 2
    +new 1
     tail

    """)[0]

    let rows = SideBySide.rows(for: diff.hunks[0])

    #expect(rows.map { $0.left?.text } == ["keep", "old 1", "old 2", "tail"])
    #expect(rows.map { $0.right?.text } == ["keep", "new 1", nil, "tail"])
}

@Test func timelineOrdersMostRecentFirstAndIgnoresGitInternals() {
    var timeline = ChangeTimeline()
    let t0 = Date(timeIntervalSince1970: 1000)
    timeline.record(["a.py", ".git/index"], at: t0)
    timeline.record(["b.py"], at: t0.addingTimeInterval(1))
    timeline.record(["a.py"], at: t0.addingTimeInterval(2))

    #expect(timeline.entries.map(\.path) == ["a.py", "b.py"])
    #expect(timeline.isLive(now: t0.addingTimeInterval(4)))
    #expect(!timeline.isLive(now: t0.addingTimeInterval(10)))
}

@Test func timelineIgnoresEditorTempFiles() {
    var timeline = ChangeTimeline()
    timeline.record(["src/.!34533!A.java", "src/A.java~", "src/.A.java.swp", "build.tmp", "src/A.java"])
    #expect(timeline.entries.map(\.path) == ["src/A.java"])
}
