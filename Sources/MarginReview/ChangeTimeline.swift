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

    /// Records changed paths. Paths inside `.git/` are ignored.
    public mutating func record(_ paths: [String], at date: Date = Date()) {
        let relevant = paths.filter { !$0.hasPrefix(".git/") && $0 != ".git" }
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
