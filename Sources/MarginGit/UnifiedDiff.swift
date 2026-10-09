import Foundation

public struct DiffLine: Equatable, Sendable {
    public enum Kind: Sendable { case context, added, removed, noNewline }

    public let kind: Kind
    /// The line as it appears in the patch, including its prefix (" ", "+", "-", "\").
    public let raw: String
    public let oldLine: Int?
    public let newLine: Int?

    /// Line content without the patch prefix.
    public var text: String { String(raw.dropFirst()) }
}

public struct Hunk: Equatable, Sendable, Identifiable {
    public let header: String
    public let oldStart: Int
    public let oldCount: Int
    public let newStart: Int
    public let newCount: Int
    public let lines: [DiffLine]

    public var id: String { header }
    public var additions: Int { lines.filter { $0.kind == .added }.count }
    public var deletions: Int { lines.filter { $0.kind == .removed }.count }
}

public struct FileDiff: Equatable, Sendable, Identifiable {
    /// Lines from `diff --git` up to and including `+++` (or the "Binary files" line).
    public let headerLines: [String]
    public let oldPath: String?
    public let newPath: String?
    public let hunks: [Hunk]
    public let isBinary: Bool

    public var id: String { path }
    public var path: String { newPath ?? oldPath ?? "" }
    public var additions: Int { hunks.reduce(0) { $0 + $1.additions } }
    public var deletions: Int { hunks.reduce(0) { $0 + $1.deletions } }
    public var isNewFile: Bool { oldPath == nil }
    public var isDeletedFile: Bool { newPath == nil }

    /// A patch containing only `hunk` (or all hunks when nil), suitable for `git apply`.
    public func patch(only hunk: Hunk? = nil) -> String {
        let selected = hunk.map { [$0] } ?? hunks
        var lines = headerLines
        for h in selected {
            lines.append(h.header)
            lines.append(contentsOf: h.lines.map(\.raw))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

public enum DiffParser {
    public static func parse(_ text: String) -> [FileDiff] {
        var files: [FileDiff] = []
        var lines = text.components(separatedBy: "\n")[...]
        if lines.last == "" { lines.removeLast() }

        while let first = lines.first {
            guard first.hasPrefix("diff --git ") else { lines.removeFirst(); continue }
            var header = [lines.removeFirst()]
            var oldPath: String? = gitHeaderPath(first, side: "a/")
            var newPath: String? = gitHeaderPath(first, side: "b/")
            var isBinary = false

            while let line = lines.first, !line.hasPrefix("@@"), !line.hasPrefix("diff --git ") {
                header.append(lines.removeFirst())
                if line.hasPrefix("--- ") { oldPath = patchPath(String(line.dropFirst(4))) }
                else if line.hasPrefix("+++ ") { newPath = patchPath(String(line.dropFirst(4))) }
                else if line.hasPrefix("new file mode") { oldPath = nil }
                else if line.hasPrefix("deleted file mode") { newPath = nil }
                else if line.hasPrefix("Binary files ") { isBinary = true }
            }

            var hunks: [Hunk] = []
            while let line = lines.first, line.hasPrefix("@@") {
                lines.removeFirst()
                guard let (oldStart, oldCount, newStart, newCount) = parseHunkHeader(line) else { continue }
                var body: [DiffLine] = []
                var oldNo = oldStart, newNo = newStart
                while let next = lines.first, !next.hasPrefix("@@"), !next.hasPrefix("diff --git ") {
                    lines.removeFirst()
                    switch next.first {
                    case " ":
                        body.append(DiffLine(kind: .context, raw: next, oldLine: oldNo, newLine: newNo))
                        oldNo += 1; newNo += 1
                    case "-":
                        body.append(DiffLine(kind: .removed, raw: next, oldLine: oldNo, newLine: nil))
                        oldNo += 1
                    case "+":
                        body.append(DiffLine(kind: .added, raw: next, oldLine: nil, newLine: newNo))
                        newNo += 1
                    case "\\":
                        body.append(DiffLine(kind: .noNewline, raw: next, oldLine: nil, newLine: nil))
                    case nil:
                        // An empty context line whose leading space was stripped.
                        body.append(DiffLine(kind: .context, raw: " ", oldLine: oldNo, newLine: newNo))
                        oldNo += 1; newNo += 1
                    default:
                        continue
                    }
                }
                hunks.append(Hunk(header: line, oldStart: oldStart, oldCount: oldCount,
                                  newStart: newStart, newCount: newCount, lines: body))
            }
            files.append(FileDiff(headerLines: header, oldPath: oldPath, newPath: newPath, hunks: hunks, isBinary: isBinary))
        }
        return files
    }

    private static func patchPath(_ value: String) -> String? {
        if value == "/dev/null" { return nil }
        if value.hasPrefix("a/") || value.hasPrefix("b/") { return String(value.dropFirst(2)) }
        return value
    }

    /// Extracts a path from `diff --git a/x b/x`. Used for binary/mode-only diffs without ---/+++.
    private static func gitHeaderPath(_ line: String, side: String) -> String? {
        let rest = line.dropFirst("diff --git ".count)
        guard let split = rest.range(of: " b/", options: .backwards) else { return nil }
        let value = side == "a/" ? rest[..<split.lowerBound] : rest[split.upperBound...]
        return side == "a/" ? String(value.dropFirst(2)) : String(value)
    }

    private static func parseHunkHeader(_ line: String) -> (Int, Int, Int, Int)? {
        // @@ -oldStart[,oldCount] +newStart[,newCount] @@ optional section
        let parts = line.split(separator: " ")
        guard parts.count >= 3 else { return nil }
        func range(_ s: Substring) -> (Int, Int)? {
            let nums = s.dropFirst().split(separator: ",", omittingEmptySubsequences: false)
            guard let start = Int(nums[0]) else { return nil }
            return (start, nums.count > 1 ? Int(nums[1]) ?? 1 : 1)
        }
        guard let old = range(parts[1]), let new = range(parts[2]) else { return nil }
        return (old.0, old.1, new.0, new.1)
    }
}
