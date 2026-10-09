import Foundation

/// IntelliJ-style "Go to file" matching: query characters must appear in order;
/// an uppercase query character must hit a word start ("US" → UserService);
/// matches at word starts, in the file name, and consecutive runs score higher.
public enum FuzzyMatcher {
    public static func score(query: String, candidate: String) -> Int? {
        let q = Array(query.filter { !$0.isWhitespace })
        guard !q.isEmpty else { return 0 }
        let original = Array(candidate)
        let lower = Array(candidate.lowercased())
        guard lower.count == original.count else { return nil }
        let fileNameStart = original.lastIndex(of: "/").map { $0 + 1 } ?? 0

        // Prefer matching the query inside the file name: try there first, then the whole path.
        for start in [fileNameStart, 0] {
            if let score = match(q, lower: lower, original: original, from: start, fileNameStart: fileNameStart) {
                return score
            }
        }
        return nil
    }

    private static func match(_ q: [Character], lower: [Character], original: [Character], from start: Int, fileNameStart: Int) -> Int? {
        var score = 0
        var qi = 0
        var previousMatch = -2
        var i = start
        while i < lower.count, qi < q.count {
            let wanted = Character(q[qi].lowercased())
            let wordStart = isWordStart(original, i)
            if lower[i] == wanted, !q[qi].isUppercase || wordStart {
                score += 1
                if i == previousMatch + 1 { score += 5 }
                if wordStart { score += 8 }
                if i >= fileNameStart { score += 2 }
                previousMatch = i
                qi += 1
            }
            i += 1
        }
        guard qi == q.count else { return nil }
        return score * 100 - original.count
    }

    private static func isWordStart(_ chars: [Character], _ i: Int) -> Bool {
        if i == 0 { return true }
        let prev = chars[i - 1]
        if "/_-. ".contains(prev) { return true }
        return chars[i].isUppercase && prev.isLowercase
    }
}

public enum FileFinder {
    /// Returns up to `limit` paths ranked best first.
    public static func search(_ query: String, in paths: [String], limit: Int = 50) -> [String] {
        guard !query.isEmpty else { return Array(paths.prefix(limit)) }
        return paths
            .compactMap { path in FuzzyMatcher.score(query: query, candidate: path).map { (path, $0) } }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            .prefix(limit)
            .map(\.0)
    }
}
