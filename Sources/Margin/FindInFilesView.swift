import MarginCore
import SwiftUI

/// Find in Files (⇧⌘F), backed by ripgrep.
struct FindInFilesView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var regex = false
    @State private var results: [TextMatch] = []
    @State private var message: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Find in files", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(search)
                    .onKeyPress(.escape) { dismiss(); return .handled }
                Toggle("Regex", isOn: $regex)
                Button("Search", action: search)
            }
            if let message {
                Text(message).foregroundStyle(.secondary)
            }
            List(results) { match in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(match.path):\(match.line)").font(.caption).foregroundStyle(.secondary)
                    Text(Self.highlighted(match)).font(.system(.body, design: .monospaced)).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    app.openFile(match.path, line: match.line)
                    app.sidebarMode = .project
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 760, height: 480)
    }

    private func search() {
        guard let root = app.workspace?.root else { return }
        searchTask?.cancel()
        message = "Searching…"
        let query = query, regex = regex
        searchTask = Task {
            do {
                let found = try await TextSearch(root: root).search(query, regex: regex)
                guard !Task.isCancelled else { return }
                results = found
                message = found.isEmpty ? "No matches." : "\(found.count) matches"
            } catch {
                results = []
                message = String(describing: error)
            }
        }
    }

    /// Bolds the matched byte ranges.
    static func highlighted(_ match: TextMatch) -> AttributedString {
        let bytes = Array(match.text.utf8)
        var result = AttributedString()
        var cursor = 0
        for range in match.byteRanges where range.lowerBound >= cursor && range.upperBound <= bytes.count {
            result += AttributedString(String(decoding: bytes[cursor..<range.lowerBound], as: UTF8.self))
            var hit = AttributedString(String(decoding: bytes[range], as: UTF8.self))
            hit.font = .system(.body, design: .monospaced).bold()
            hit.backgroundColor = .yellow.opacity(0.35)
            result += hit
            cursor = range.upperBound
        }
        result += AttributedString(String(decoding: bytes[cursor...], as: UTF8.self))
        return result
    }
}
