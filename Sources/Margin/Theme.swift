import AppKit
import MarginCore
import SwiftUI

enum Theme {
    static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    static func color(for capture: String) -> NSColor {
        switch capture.split(separator: ".").first.map(String.init) ?? capture {
        case "keyword", "include", "conditional", "repeat", "exception": return .systemOrange
        case "string", "character", "escape": return .systemGreen
        case "number", "float", "boolean": return .systemBlue
        case "comment": return .secondaryLabelColor
        case "type", "constructor": return .systemTeal
        case "function", "method": return .systemIndigo
        case "constant": return .systemPurple
        case "attribute", "annotation": return .systemBrown
        default: return .labelColor
        }
    }

    /// Highlights a whole file and returns one AttributedString per line (index = line - 1).
    static func highlightedLines(_ text: String?, path: String) -> [AttributedString] {
        guard let text else { return [] }
        let ns = text as NSString
        var colors = [NSColor?](repeating: nil, count: ns.length)
        if let language = SourceLanguage.detect(path: path) {
            for span in SyntaxHighlighter.highlights(in: text, language: language) {
                let color = color(for: span.capture)
                for i in span.range.location..<min(NSMaxRange(span.range), ns.length) { colors[i] = color }
            }
        }
        var lines: [AttributedString] = []
        var lineStart = 0
        while lineStart <= ns.length {
            let lineRange = ns.lineRange(for: NSRange(location: lineStart, length: 0))
            var contentEnd = NSMaxRange(lineRange)
            while contentEnd > lineRange.location, [10, 13].contains(ns.character(at: contentEnd - 1)) { contentEnd -= 1 }
            var line = AttributedString()
            var runStart = lineRange.location
            while runStart < contentEnd {
                var runEnd = runStart + 1
                while runEnd < contentEnd, colors[runEnd] == colors[runStart] { runEnd += 1 }
                var piece = AttributedString(ns.substring(with: NSRange(location: runStart, length: runEnd - runStart)))
                if let color = colors[runStart] { piece.foregroundColor = Color(nsColor: color) }
                line += piece
                runStart = runEnd
            }
            lines.append(line)
            if NSMaxRange(lineRange) == lineStart { break }
            lineStart = NSMaxRange(lineRange)
            if lineStart == ns.length { break }
        }
        return lines
    }
}
