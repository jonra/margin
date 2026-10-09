import Foundation

public struct MissingToolError: Error, CustomStringConvertible, Sendable {
    public let tool: String
    public let installHint: String

    public var description: String { "\(tool) not found. Install it with: \(installHint)" }
}

/// Finds external CLIs. Apps launched from Finder get a minimal PATH, so the
/// usual Homebrew locations are always searched too.
public enum ToolLocator {
    static let fallbackDirectories = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]

    public static func find(
        _ name: String, environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        let pathDirectories = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        for directory in pathDirectories + fallbackDirectories {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    public static func require(_ name: String, installHint: String) throws -> URL {
        guard let url = find(name) else { throw MissingToolError(tool: name, installHint: installHint) }
        return url
    }
}
