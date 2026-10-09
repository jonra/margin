import Foundation
import Testing
import MarginTestSupport
@testable import MarginSearch

private let paths = [
    "src/main/java/com/acme/UserService.java",
    "src/main/java/com/acme/user/UserRepository.java",
    "src/test/java/com/acme/UserServiceTest.java",
    "scripts/useless_tool.py",
    "docs/README.md",
]

@Test func fuzzyMatchRequiresCharactersInOrder() {
    #expect(FuzzyMatcher.score(query: "usvc", candidate: "UserService.java") != nil)
    #expect(FuzzyMatcher.score(query: "xyz", candidate: "UserService.java") == nil)
    #expect(FuzzyMatcher.score(query: "", candidate: "anything") == 0)
}

@Test func camelCaseInitialsRankFileNameMatchesFirst() {
    #expect(FileFinder.search("US", in: paths).first == "src/main/java/com/acme/UserService.java")
}

@Test func exactFileNamePrefixBeatsLongerVariant() {
    let results = FileFinder.search("UserService", in: paths)
    #expect(Array(results.prefix(2)) == [
        "src/main/java/com/acme/UserService.java",
        "src/test/java/com/acme/UserServiceTest.java",
    ])
}

@Test func emptyQueryReturnsPathsUpToLimit() {
    #expect(FileFinder.search("", in: paths, limit: 2).count == 2)
}

@Test func parsesRipgrepJsonOutput() {
    let output = """
    {"type":"begin","data":{"path":{"text":"./src/a.py"}}}
    {"type":"match","data":{"path":{"text":"./src/a.py"},"lines":{"text":"def foo():\\n"},"line_number":3,"absolute_offset":10,"submatches":[{"match":{"text":"foo"},"start":4,"end":7}]}}
    {"type":"end","data":{"path":{"text":"./src/a.py"}}}
    """

    let matches = TextSearch.parse(output, limit: 10)

    #expect(matches == [TextMatch(path: "src/a.py", line: 3, text: "def foo():", byteRanges: [4..<7])])
}

@Test(.enabled(if: FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/rg") || FileManager.default.isExecutableFile(atPath: "/usr/local/bin/rg")))
func searchesRepositoryWithRipgrep() async throws {
    let repo = try await TestRepo(files: [
        "src/A.java": "class A {\n  void handleOrder() {}\n}\n",
        "src/b.py": "def handle_order():\n    pass\n",
    ])

    let matches = try await TextSearch(root: repo.root).search("handleOrder")

    #expect(matches.map(\.path) == ["src/A.java"])
    #expect(matches.first?.line == 2)
}

@Test func lowercaseQueryStillMatchesAnywhere() {
    #expect(FileFinder.search("useless", in: paths) == ["scripts/useless_tool.py"])
}
