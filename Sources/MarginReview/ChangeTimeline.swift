import Foundation

/// Files touched during this session, most recent first — lets you follow an agent as it works.
public struct ChangeTimeline: Sendable {
    public struct Entry: Equatable, Sendable, Identifiable {
        public let path: String
        public let date: Date
        public var id: String { path }
    }

    public private(set) var entries: [Entry] = []
    public var liveWindow: TimeInterval = 3
    public var maxEntries = 200

    public init() {}

    /// Editor scratch files (`.!123!A.java` from sed -i, `A.java~`, `.swp`, `.tmp`) are not real changes.
    public static func isTemporary(_ path: String) -> Bool {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return name.hasPrefix(".!") || name.hasSuffix("~") || name.hasSuffix(".swp") || name.hasSuffix(".tmp")
    }

    /// Records changed paths. Paths inside `.git/` and editor temp files are ignored.
    public mutating func record(_ paths: [String], at date: Date = Date()) {
        let relevant = paths.filter { !$0.hasPrefix(".git/") && $0 != ".git" && !Self.isTemporary($0) }
        guard !relevant.isEmpty else { return }
        let touched = Set(relevant)
        entries.removeAll { touched.contains($0.path) }
        entries.insert(contentsOf: relevant.sorted().map { Entry(path: $0, date: date) }, at: 0)
        if entries.count > maxEntries { entries.removeLast(entries.count - maxEntries) }
    }

    /// True when something changed within the live window — an agent is probably working.
    public func isLive(now: Date = Date()) -> Bool {
        guard let latest = entries.first else { return false }
        return now.timeIntervalSince(latest.date) <= liveWindow
    }
}
