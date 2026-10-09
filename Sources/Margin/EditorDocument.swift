import Foundation
import MarginCore
import MarginWorkspace

/// Thin observable wrapper around the engine's `TextDocument` save/conflict state machine.
@MainActor
final class EditorDocument: ObservableObject, Identifiable {
    /// Repo-relative path.
    let id: String
    let language: SourceLanguage?
    @Published private var model: TextDocument
    /// A line to reveal next time the editor updates (1-based).
    @Published var pendingLine: Int?

    init(root: URL, path: String) throws {
        id = path
        language = SourceLanguage.detect(path: path)
        model = try TextDocument(url: root.appendingPathComponent(path))
    }

    var url: URL { model.url }
    var name: String { model.url.lastPathComponent }
    var isDirty: Bool { model.isDirty }
    var conflict: TextDocument.Conflict? { model.conflict }

    var text: String {
        get { model.text }
        set { if newValue != model.text { model.text = newValue } }
    }

    func save() throws { try model.save() }

    /// Saves unless that would clobber a disk change. Returns true if the document is clean afterwards.
    @discardableResult
    func saveIfSafe(report: (Error) -> Void) -> Bool {
        do { return try model.saveIfSafe() } catch {
            report(error)
            return false
        }
    }

    /// Called when the file changed on disk (e.g. an agent edited it).
    func diskChanged() { model.diskChanged() }

    func reloadFromDisk(report: (Error) -> Void) {
        do { try model.reloadFromDisk() } catch { report(error) }
    }

    func keepMine() { model.keepMine() }

    func discardChanges() { model.discardChanges() }
}
