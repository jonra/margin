import CoreServices
import MarginSupport
import Foundation

/// Watches a directory tree with FSEvents and yields batches of changed repo-relative paths.
/// Paths inside `.git/` are included so callers can react to index/HEAD changes.
public final class FileWatcher: @unchecked Sendable {
    public let root: URL
    public let events: AsyncStream<[String]>
    private let continuation: AsyncStream<[String]>.Continuation
    private let rootPath: String
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "margin.filewatcher")
    private let queueKey = DispatchSpecificKey<Void>()

    public init(root: URL, latency: TimeInterval = 0.2) {
        self.root = root
        self.rootPath = root.path.resolvingRealPath()
        queue.setSpecific(key: queueKey, value: ())
        (events, continuation) = AsyncStream.makeStream(of: [String].self, bufferingPolicy: .unbounded)
        start(latency: latency)
    }

    deinit { stop() }

    public func stop() {
        // deinit can run on `queue` if the last reference is dropped inside a callback;
        // queue.sync from the queue itself would trap, so tear down inline in that case.
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            tearDownStream()
        } else {
            queue.sync { tearDownStream() }
        }
        continuation.finish()
    }

    private func tearDownStream() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func start(latency: TimeInterval) {
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            let array = unsafeBitCast(paths, to: NSArray.self)
            watcher.handle((0..<count).compactMap { array[$0] as? String })
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            nil, callback, &context, [rootPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags) else {
            continuation.finish()
            return
        }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    private func handle(_ absolutePaths: [String]) {
        let prefix = rootPath + "/"
        var seen = Set<String>()
        let relative = absolutePaths.compactMap { path -> String? in
            guard path.hasPrefix(prefix) else { return nil }
            let rel = String(path.dropFirst(prefix.count))
            return seen.insert(rel).inserted ? rel : nil
        }
        if !relative.isEmpty { continuation.yield(relative) }
    }
}
