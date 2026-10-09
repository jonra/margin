import Foundation

extension String {
    /// Resolves symlinks (e.g. /var -> /private/var) the same way FSEvents and git report paths.
    public func resolvingRealPath() -> String {
        guard let resolved = realpath(self, nil) else { return self }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
