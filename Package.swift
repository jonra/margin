// swift-tools-version:6.0
import PackageDescription

/// Vendored tree-sitter grammar (C). See scripts/vendor-grammars.sh.
func grammar(_ name: String) -> Target {
    .target(name: name, path: "Sources/\(name)", exclude: ["LICENSE"], sources: ["src"],
            publicHeadersPath: "include", cSettings: [.headerSearchPath("src")])
}

let package = Package(
    name: "Margin",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter", exact: "0.25.0"),
    ],
    targets: [
        grammar("TreeSitterJava"),
        grammar("TreeSitterPython"),
        .target(name: "MarginSupport"),
        .target(name: "MarginSyntax", dependencies: [
            .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            "TreeSitterJava", "TreeSitterPython",
        ]),
        .target(name: "MarginGit", dependencies: ["MarginSupport"]),
        .target(name: "MarginTestSupport", dependencies: ["MarginSupport"], path: "Tests/MarginTestSupport"),
        .testTarget(name: "MarginSupportTests", dependencies: ["MarginSupport"]),
        .testTarget(name: "MarginSyntaxTests", dependencies: ["MarginSyntax"]),
        .testTarget(name: "MarginGitTests", dependencies: ["MarginGit", "MarginTestSupport"]),
    ],
    swiftLanguageModes: [.v5]
)
