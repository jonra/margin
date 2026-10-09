import MarginCore
import SwiftUI

/// Go to File (⇧⌘O or double Shift).
struct QuickOpenView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selected = 0

    var body: some View {
        let results = FileFinder.search(query, in: app.files, limit: 50)
        VStack(alignment: .leading, spacing: 8) {
            TextField("Go to file", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit { open(results) }
                .onKeyPress(.downArrow) { selected = min(selected + 1, max(results.count - 1, 0)); return .handled }
                .onKeyPress(.upArrow) { selected = max(selected - 1, 0); return .handled }
                .onKeyPress(.escape) { dismiss(); return .handled }
                .onChange(of: query) { selected = 0 }
            ScrollViewReader { proxy in
                List(Array(results.enumerated()), id: \.element) { index, path in
                    VStack(alignment: .leading) {
                        Text((path as NSString).lastPathComponent)
                        Text((path as NSString).deletingLastPathComponent).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(index == selected ? Color.accentColor.opacity(0.25) : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { selected = index; open(results) }
                    .id(index)
                }
                .onChange(of: selected) { _, index in proxy.scrollTo(index) }
            }
        }
        .padding()
        .frame(width: 640, height: 420)
    }

    private func open(_ results: [String]) {
        guard results.indices.contains(selected) else { return }
        app.openFile(results[selected])
        dismiss()
    }
}
