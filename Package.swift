// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Margin",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MarginSupport"),
        .testTarget(name: "MarginSupportTests", dependencies: ["MarginSupport"]),
    ],
    swiftLanguageModes: [.v5]
)
