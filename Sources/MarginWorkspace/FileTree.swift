import Foundation

public struct FileNode: Identifiable, Hashable, Sendable {
    /// Repo-relative path; unique within a tree.
    public let id: String
    public let name: String
    /// nil for files, so SwiftUI's OutlineGroup shows no disclosure triangle.
    public let children: [FileNode]?

    public var isDirectory: Bool { children != nil }
}

public enum FileTree {
    /// Builds a sorted tree (directories first, then case-insensitive by name) from relative file paths.
    public static func build(paths: [String]) -> [FileNode] {
        final class Dir {
            var dirs: [String: Dir] = [:]
            var files: Set<String> = []
        }
        let root = Dir()
        for path in paths {
            let parts = path.split(separator: "/").map(String.init)
            guard let fileName = parts.last else { continue }
            var dir = root
            for part in parts.dropLast() {
                if let next = dir.dirs[part] { dir = next } else {
                    let next = Dir()
                    dir.dirs[part] = next
                    dir = next
                }
            }
            dir.files.insert(fileName)
        }
        func nodes(_ dir: Dir, prefix: String) -> [FileNode] {
            let order: (String, String) -> Bool = { $0.localizedStandardCompare($1) == .orderedAscending }
            let dirNodes = dir.dirs.keys.sorted(by: order).map { name in
                FileNode(id: prefix + name, name: name, children: nodes(dir.dirs[name]!, prefix: prefix + name + "/"))
            }
            let fileNodes = dir.files.sorted(by: order).map { FileNode(id: prefix + $0, name: $0, children: nil) }
            return dirNodes + fileNodes
        }
        return nodes(root, prefix: "")
    }
}
