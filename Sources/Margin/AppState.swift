import AppKit
import MarginCore
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var workspace: Workspace?
    @Published private(set) var files: [String] = []
    @Published private(set) var tree: [FileNode] = []
    @Published private(set) var documents: [EditorDocument] = []
    @Published var activeDocumentID: String?
    @Published var showQuickOpen = false
    @Published var showFindInFiles = false
    @Published var errorMessage: String?

    private var fileSet: Set<String> = []
    private var watcher: FileWatcher?
    private var watchTask: Task<Void, Never>?

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveAll() }
        }
    }

    var activeDocument: EditorDocument? { documents.first { $0.id == activeDocumentID } }

    func isFile(_ path: String) -> Bool { fileSet.contains(path) }

    // MARK: Workspace

    /// `Margin -workspace /path/to/repo` (AppKit maps `-key value` arguments into UserDefaults;
    /// a bare path argument would be treated as an open-document event and suppress the window).
    func openFromCommandLine() async {
        guard workspace == nil, let path = UserDefaults.standard.string(forKey: "workspace") else { return }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            await open(URL(fileURLWithPath: path))
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Open"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await open(url) }
    }

    func open(_ url: URL) async {
        saveAll()
        let opened = await Workspace.open(url)
        workspace = opened
        documents = []
        activeDocumentID = nil
        await reloadFiles()
        startWatching(opened.root)
    }

    private func reloadFiles() async {
        guard let workspace else { return }
        do {
            files = try await workspace.listFiles()
            fileSet = Set(files)
            tree = FileTree.build(paths: files)
        } catch {
            report(error)
        }
    }

    private func startWatching(_ root: URL) {
        watchTask?.cancel()
        watcher?.stop()
        let watcher = FileWatcher(root: root)
        self.watcher = watcher
        watchTask = Task { [weak self] in
            for await batch in watcher.events {
                await self?.handleChanges(batch)
            }
        }
    }

    private func handleChanges(_ paths: [String]) async {
        let workingFiles = paths.filter { !$0.hasPrefix(".git/") && $0 != ".git" }
        let rootPath = workspace?.root.path ?? ""
        let treeChanged = workingFiles.contains { path in
            fileSet.contains(path) != FileManager.default.fileExists(atPath: rootPath + "/" + path)
        }
        if treeChanged { await reloadFiles() }
        for document in documents where workingFiles.contains(document.id) {
            document.diskChanged()
        }
    }

    // MARK: Documents

    func openFile(_ path: String, line: Int? = nil) {
        if let existing = documents.first(where: { $0.id == path }) {
            existing.pendingLine = line
            activeDocumentID = path
            return
        }
        guard let workspace else { return }
        do {
            let document = try EditorDocument(root: workspace.root, path: path)
            document.pendingLine = line
            documents.append(document)
            activeDocumentID = path
        } catch {
            report(error)
        }
    }

    func close(_ document: EditorDocument) {
        document.saveIfSafe(report: report)
        documents.removeAll { $0.id == document.id }
        if activeDocumentID == document.id { activeDocumentID = documents.last?.id }
    }

    /// IntelliJ-style autosave: dirty documents are saved unless they conflict with a disk change.
    func saveAll() {
        for document in documents { document.saveIfSafe(report: report) }
    }

    func report(_ error: Error) {
        errorMessage = String(describing: error)
    }
}
