import Foundation

/// An open text file plus the save/conflict state machine that keeps user edits and
/// on-disk changes (e.g. by AI agents) from silently clobbering each other.
public struct TextDocument {
    public enum Conflict: Equatable, Sendable {
        case modifiedOnDisk
        case deletedOnDisk
    }

    public let url: URL
    /// Saves go to the resolved path so a symlinked file stays a symlink.
    private var resolvedURL: URL { url.resolvingSymlinksInPath() }
    public var text: String
    public private(set) var conflict: Conflict?
    /// What we believe is on disk; nil means the file is absent.
    private var baseline: String?

    public init(url: URL) throws {
        self.url = url
        let content = try String(contentsOf: url.resolvingSymlinksInPath(), encoding: .utf8)
        text = content
        baseline = content
    }

    public var isDirty: Bool { text != baseline }

    /// Unconditional write (explicit user intent). Clears any conflict.
    public mutating func save() throws {
        try text.write(to: resolvedURL, atomically: true, encoding: .utf8)
        baseline = text
        conflict = nil
    }

    /// Writes only when the disk still matches what we last saw. Returns true if clean afterwards.
    public mutating func saveIfSafe() throws -> Bool {
        guard isDirty else { return true }
        guard conflict == nil else { return false }
        if let found = detectConflict() {
            conflict = found
            return false
        }
        try save()
        return true
    }

    /// Call when the file may have changed on disk.
    public mutating func diskChanged() {
        guard let found = detectConflict() else {
            conflict = nil // disk matches the baseline again (restored by git, etc.)
            return
        }
        if isDirty || conflict != nil || found == .deletedOnDisk {
            conflict = found
        } else if let disk = readDisk() {
            text = disk
            baseline = disk
        }
    }

    /// Drops unsaved edits without touching the disk (e.g. closing a tab whose file was deleted).
    public mutating func discardChanges() {
        text = baseline ?? ""
        baseline = text
        conflict = nil
    }

    public mutating func reloadFromDisk() throws {
        let disk = try String(contentsOf: resolvedURL, encoding: .utf8)
        text = disk
        baseline = disk
        conflict = nil
    }

    /// Accept the current disk state as the baseline; the next save writes the user's text.
    public mutating func keepMine() {
        baseline = readDisk()
        conflict = nil
    }

    private func readDisk() -> String? { try? String(contentsOf: resolvedURL, encoding: .utf8) }

    private func detectConflict() -> Conflict? {
        let disk = readDisk()
        if disk == baseline { return nil }
        return disk == nil ? .deletedOnDisk : .modifiedOnDisk
    }
}
