import Testing
@testable import MarginGit

private let modifiedDiff = """
diff --git a/src/App.py b/src/App.py
index 1111111..2222222 100644
--- a/src/App.py
+++ b/src/App.py
@@ -1,3 +1,3 @@ def main():
 import os
-print("old")
+print("new")
 x = 1
@@ -10,2 +10,3 @@
 a
+b
 c
\\ No newline at end of file
diff --git a/added.txt b/added.txt
new file mode 100644
index 0000000..3333333
--- /dev/null
+++ b/added.txt
@@ -0,0 +1 @@
+hello
diff --git a/removed.txt b/removed.txt
deleted file mode 100644
index 4444444..0000000
--- a/removed.txt
+++ /dev/null
@@ -1 +0,0 @@
-bye
diff --git a/logo.png b/logo.png
index 5555555..6666666 100644
Binary files a/logo.png and b/logo.png differ

"""

@Test func parsesFilesHunksAndLineNumbers() {
    let files = DiffParser.parse(modifiedDiff)
    #expect(files.map(\.path) == ["src/App.py", "added.txt", "removed.txt", "logo.png"])

    let app = files[0]
    #expect(app.hunks.count == 2)
    #expect(app.additions == 2 && app.deletions == 1)
    let first = app.hunks[0]
    #expect((first.oldStart, first.oldCount, first.newStart, first.newCount) == (1, 3, 1, 3))
    #expect(first.lines.map(\.kind) == [.context, .removed, .added, .context])
    #expect(first.lines[1].oldLine == 2 && first.lines[1].newLine == nil)
    #expect(first.lines[2].text == "print(\"new\")" && first.lines[2].newLine == 2)
    #expect(first.lines[3].oldLine == 3 && first.lines[3].newLine == 3)
    #expect(app.hunks[1].lines.last?.kind == .noNewline)
}

@Test func detectsNewDeletedAndBinaryFiles() {
    let files = DiffParser.parse(modifiedDiff)
    #expect(files[1].isNewFile && files[1].newPath == "added.txt")
    #expect(files[2].isDeletedFile && files[2].oldPath == "removed.txt")
    #expect(files[3].isBinary && files[3].hunks.isEmpty)
}

@Test func singleHunkPatchKeepsHeaderAndOnlyThatHunk() {
    let app = DiffParser.parse(modifiedDiff)[0]
    let patch = app.patch(only: app.hunks[1])
    #expect(patch == """
    diff --git a/src/App.py b/src/App.py
    index 1111111..2222222 100644
    --- a/src/App.py
    +++ b/src/App.py
    @@ -10,2 +10,3 @@
     a
    +b
     c
    \\ No newline at end of file

    """)
}

@Test func trailingTabAfterPathWithSpaceIsStripped() {
    let text = "diff --git a/new file.py b/new file.py\nindex 1..2 100644\n--- a/new file.py\t\n+++ b/new file.py\t\n@@ -1 +1 @@\n-a\n+b\n"
    let file = DiffParser.parse(text)[0]
    #expect(file.oldPath == "new file.py" && file.newPath == "new file.py")
}
