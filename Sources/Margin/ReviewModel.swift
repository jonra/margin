import Foundation
import MarginCore

/// UI state for reviewing changes. All data comes from ReviewEngine (git + disk).
@MainActor
final class ReviewModel: ObservableObject {
    @Published private(set) var targets: [ReviewTarget] = []
    @Published var target: ReviewTarget? {
        didSet { if oldValue != target { targetChanged() } }
    }
    @Published private(set) var changes: [ChangedFile] = []
    @Published var selectedFileID: String?
    @Published private(set) var timeline = ChangeTimeline()
    @Published private(set) var isLive = false
    @Published var commitMessage = ""
    @Published var inlineMode = false

    var onError: (Error) -> Void = { _ in }

    private var workspaceRoot: URL?
    private var targetWatcher: FileWatcher?
    private var targetWatchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var liveTimer: Timer?

    var selectedFile: ChangedFile? { changes.first { $0.id == selectedFileID } }
    private var engine: ReviewEngine?
    /// Paths (relative to the current target) of other worktrees nested inside it; kept current as `targets` changes.
    private var nestedPrefixes: [String] = []

    init() {
        liveTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let live = self.timeline.isLive()
                if live != self.isLive { self.isLive = live }
            }
        }
    }

    func load(workspace: Workspace) async {
        workspaceRoot = workspace.root
        changes = []
        selectedFileID = nil
        timeline = ChangeTimeline()
        // Force didSet to fire even when reopening the same folder, so watching restarts.
        target = nil
        guard workspace.isGitRepository else {
            targets = []
            return
        }
        await reloadTargets()
    }

    /// Called with every change batch from the workspace watcher.
    func workspaceChanged(_ paths: [String]) async {
        if paths.contains(where: { $0.hasPrefix(".git/worktrees") }) { await reloadTargets() }
    }

    private func reloadTargets() async {
        guard let root = workspaceRoot else { return }
        do {
            let all = ReviewTarget.all(from: try await Git(root: root).worktrees())
            targets = all
            updateNestedPrefixes()
            if let current = target, all.contains(current) { return }
            target = all.first { $0.root.path == root.path } ?? all.first
        } catch {
            onError(error)
        }
    }

    private func targetChanged() {
        selectedFileID = nil
        timeline = ChangeTimeline()
        targetWatchTask?.cancel()
        targetWatcher?.stop()
        targetWatcher = nil
        engine = nil
        guard let target else {
            changes = []
            return
        }
        do { engine = try ReviewEngine(target: target) } catch {
            changes = []
            onError(error)
            return
        }
        updateNestedPrefixes()
        let watcher = FileWatcher(root: target.root)
        targetWatcher = watcher
        targetWatchTask = Task { [weak self] in
            for await batch in watcher.events {
                guard let self else { return }
                let nested = self.nestedPrefixes
                let own = batch.filter { path in !nested.contains(where: { path.hasPrefix($0) }) }
                guard !own.isEmpty else { continue }
                // Deleted files stay in the timeline; editor temp files are dropped by ChangeTimeline itself.
                self.timeline.record(own)
                self.isLive = self.timeline.isLive()
                self.scheduleRefresh()
            }
        }
        scheduleRefresh()
    }

    private func updateNestedPrefixes() {
        guard let target else { nestedPrefixes = []; return }
        let prefix = target.root.path + "/"
        nestedPrefixes = targets.compactMap { other in
            other != target && other.root.path.hasPrefix(prefix) ? String(other.root.path.dropFirst(prefix.count)) + "/" : nil
        }
    }

    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    func refresh() async {
        guard let engine else {
            changes = []
            return
        }
        do {
            let latest = try await engine.changes()
            // The target may have been switched while git was running; drop stale results.
            guard engine.target == target else { return }
            if latest != changes { changes = latest }
        } catch {
            onError(error)
        }
    }

    func contents(of file: ChangedFile) async -> (old: String?, new: String?) {
        guard let engine else { return (nil, nil) }
        do {
            let result = try await engine.contents(of: file)
            return engine.target == target ? result : (nil, nil)
        } catch {
            onError(error)
            return (nil, nil)
        }
    }

    // MARK: Actions

    func revert(_ hunk: Hunk, in file: ChangedFile) { perform { try await $0.revert(hunk, in: file) } }
    func revert(_ file: ChangedFile) { perform { try await $0.revert(file) } }
    func stage(_ hunk: Hunk, in file: ChangedFile) { perform { try await $0.stage(hunk, in: file) } }
    func stage(_ file: ChangedFile) { perform { try await $0.stage(file) } }

    func commit() {
        let message = commitMessage
        perform { [weak self] engine in
            try await engine.commit(message: message)
            self?.commitMessage = ""
        }
    }

    private func perform(_ action: @escaping (ReviewEngine) async throws -> Void) {
        guard let engine else { return }
        Task {
            do { try await action(engine) } catch { onError(error) }
            await refresh()
        }
    }
}
