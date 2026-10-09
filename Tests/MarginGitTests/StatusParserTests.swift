import Testing
@testable import MarginGit

@Test func parsesOrdinaryRenamedUnmergedAndUntrackedEntries() {
    let output = [
        "1 .M N... 100644 100644 100644 abc abc src/Main.java",
        "1 A. N... 000000 100644 100644 000 def new file.py",
        "1 .D N... 100644 100644 000000 abc abc gone.txt",
        "2 R. N... 100644 100644 100644 abc abc R100 renamed.txt",
        "old.txt",
        "u UU N... 100644 100644 100644 100644 a b c conflict.txt",
        "? notes/todo.md",
    ].joined(separator: "\0") + "\0"

    let statuses = StatusParser.parse(output)

    #expect(statuses == [
        FileStatus(path: "src/Main.java", index: ".", worktree: "M", kind: .modified),
        FileStatus(path: "new file.py", index: "A", worktree: ".", kind: .added),
        FileStatus(path: "gone.txt", index: ".", worktree: "D", kind: .deleted),
        FileStatus(path: "renamed.txt", originalPath: "old.txt", index: "R", worktree: ".", kind: .renamed),
        FileStatus(path: "conflict.txt", index: "U", worktree: "U", kind: .conflicted),
        FileStatus(path: "notes/todo.md", index: "?", worktree: "?", kind: .untracked),
    ])
}

@Test func parsesEmptyStatus() {
    #expect(StatusParser.parse("").isEmpty)
}
