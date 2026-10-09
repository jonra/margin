import Foundation
import MarginSupport

public struct TextMatch: Equatable, Sendable, Identifiable {
    public let path: String
    /// 1-based line number.
    public let line: Int
    public let text: String
    /// Matched ranges as UTF-8 byte offsets into `text`.
    public let byteRanges: [Range<Int>]

    public var id: String { "\(path):\(line)" }
}

/// Full-text search backed by ripgrep (`rg --json`).
public struct TextSearch: Sendable {
    public let root: URL
    public var maxResults = 2_000

    public init(root: URL) { self.root = root }

    public func search(_ query: String, regex: Bool = false) async throws -> [TextMatch] {
        guard !query.isEmpty else { return [] }
        let rg = try ToolLocator.require("rg", installHint: "brew install ripgrep")
        var args = ["--json", "--smart-case", "--max-columns", "500", "--max-columns-preview"]
        if !regex { args.append("--fixed-strings") }
        args += ["--", query, "."]
        let result = try await ProcessRunner.run(rg, args, cwd: root)
        // ripgrep exits 1 when nothing matched.
        guard result.status <= 1 else {
            throw ProcessError(command: "rg", status: result.status, stderr: result.stderrString)
        }
        return Self.parse(result.stdoutString, limit: maxResults)
    }

    static func parse(_ output: String, limit: Int) -> [TextMatch] {
        struct Event: Decodable {
            struct Text: Decodable { let text: String? }
            struct Submatch: Decodable { let start: Int; let end: Int }
            struct DataPayload: Decodable {
                let path: Text?
                let lines: Text?
                let line_number: Int?
                let submatches: [Submatch]?
            }
            let type: String
            let data: DataPayload
        }
        let decoder = JSONDecoder()
        var matches: [TextMatch] = []
        for line in output.split(separator: "\n") {
            guard matches.count < limit,
                  let event = try? decoder.decode(Event.self, from: Data(line.utf8)),
                  event.type == "match",
                  var path = event.data.path?.text,
                  let number = event.data.line_number,
                  let text = event.data.lines?.text else { continue }
            if path.hasPrefix("./") { path.removeFirst(2) }
            let trimmed = text.hasSuffix("\n") ? String(text.dropLast()) : text
            let ranges = (event.data.submatches ?? []).map { $0.start..<$0.end }
            matches.append(TextMatch(path: path, line: number, text: trimmed, byteRanges: ranges))
        }
        return matches
    }
}
