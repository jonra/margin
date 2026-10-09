import Foundation
import Testing
@testable import MarginSyntax

private func captures(_ source: String, _ language: SourceLanguage) -> [String: String] {
    let ns = source as NSString
    var result: [String: String] = [:]
    for span in SyntaxHighlighter.highlights(in: source, language: language) {
        let text = ns.substring(with: span.range)
        if result[text] == nil { result[text] = span.capture }
    }
    return result
}

@Test func detectsLanguageFromExtension() {
    #expect(SourceLanguage.detect(path: "src/Main.java") == .java)
    #expect(SourceLanguage.detect(path: "app/models.py") == .python)
    #expect(SourceLanguage.detect(path: "stubs/x.PYI") == .python)
    #expect(SourceLanguage.detect(path: "README.md") == nil)
}

@Test func highlightsJavaKeywordsStringsAndTypes() {
    let found = captures("public class Greeter { String hi = \"hello\"; }", .java)
    #expect(found["public"] == "keyword")
    #expect(found["class"] == "keyword")
    #expect(found["\"hello\""] == "string")
    #expect(found["String"] == "type")
}

@Test func highlightsPythonKeywordsFunctionsAndStrings() {
    let found = captures("def greet(name):\n    return 'hi ' + name\n", .python)
    #expect(found["def"] == "keyword")
    #expect(found["return"] == "keyword")
    #expect(found["greet"] == "function")
    #expect(found["'hi '"] == "string")
}

@Test func spansAreSortedAndUseUTF16Ranges() {
    let source = "// héllo 🎉\nclass A {}"
    let spans = SyntaxHighlighter.highlights(in: source, language: .java)
    #expect(spans == spans.sorted { $0.range.location < $1.range.location || ($0.range.location == $1.range.location && $0.range.length >= $1.range.length) })
    let classSpan = spans.first { (source as NSString).substring(with: $0.range) == "class" }
    #expect(classSpan?.capture == "keyword")
}
