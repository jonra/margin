import Foundation
import SwiftTreeSitter
import TreeSitterJava
import TreeSitterPython

/// A highlighted region. `range` is in UTF-16 units (NSString/NSTextView coordinates);
/// `capture` is the tree-sitter capture name, e.g. "keyword", "string", "function.method".
public struct HighlightSpan: Equatable, Sendable {
    public let range: NSRange
    public let capture: String

    public init(range: NSRange, capture: String) {
        self.range = range
        self.capture = capture
    }
}

public enum SyntaxHighlighter {
    private struct Grammar {
        let language: Language
        let query: Query
    }

    private static let grammars: [SourceLanguage: Grammar] = {
        var result: [SourceLanguage: Grammar] = [:]
        for source in SourceLanguage.allCases {
            let language: Language
            let queryText: String
            switch source {
            case .java:
                language = Language(language: tree_sitter_java())
                queryText = HighlightQueries.java
            case .python:
                language = Language(language: tree_sitter_python())
                queryText = HighlightQueries.python
            }
            if let query = try? Query(language: language, data: Data(queryText.utf8)) {
                result[source] = Grammar(language: language, query: query)
            }
        }
        return result
    }()

    /// Returns spans sorted by location. When several captures hit the same range,
    /// the first one from the query wins (tree-sitter's precedence convention).
    public static func highlights(in source: String, language: SourceLanguage) -> [HighlightSpan] {
        guard let grammar = grammars[language] else { return [] }
        let parser = Parser()
        guard (try? parser.setLanguage(grammar.language)) != nil,
              let tree = parser.parse(source) else { return [] }
        var seen = Set<NSRange>()
        var spans: [HighlightSpan] = []
        for match in grammar.query.execute(in: tree) {
            for capture in match.captures {
                guard let name = capture.name, capture.range.length > 0,
                      seen.insert(capture.range).inserted else { continue }
                spans.append(HighlightSpan(range: capture.range, capture: name))
            }
        }
        return spans.sorted { ($0.range.location, -$0.range.length) < ($1.range.location, -$1.range.length) }
    }
}
