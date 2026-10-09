import Foundation
import MarginCore

@MainActor
final class EditorDocument: ObservableObject, Identifiable {
    /// Repo-relative path.
    let id: String
    let url: URL
    let language: SourceLanguage?
    @Published var text: String
    @Published private(set) var savedText: String
    /// The file changed on disk while this document had unsaved edits.
    @Published private(set) var changedOnDisk = false
    /// A line to reveal next time the editor updates (1-based).
    @Published var pendingLine: Int?

    init(root: URL, path: String) throws {
        id = path
        url = root.appendingPathComponent(path)
        language = SourceLanguage.detect(path: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        text = content
        savedText = content
    }

    var name: String { url.lastPathComponent }
    var isDirty: Bool { text != savedText }

    func save() throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
        savedText = text
        changedOnDisk = false
    }

    func saveIfSafe(report: (Error) -> Void) {
        guard isDirty, !changedOnDisk else { return }
        do { try save() } catch { report(error) }
    }

    /// Called when the file changed on disk (e.g. an agent edited it).
    func diskChanged() {
        guard let disk = try? String(contentsOf: url, encoding: .utf8), disk != savedText else { return }
        if isDirty {
            changedOnDisk = true
        } else {
            text = disk
            savedText = disk
        }
    }

    func reloadFromDisk() {
        if let disk = try? String(contentsOf: url, encoding: .utf8) {
            text = disk
            savedText = disk
        }
        changedOnDisk = false
    }

    func keepMine() {
        changedOnDisk = false
    }
}
