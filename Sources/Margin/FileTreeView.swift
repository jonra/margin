import MarginCore
import SwiftUI

struct FileTreeView: View {
    @EnvironmentObject private var app: AppState
    @State private var selection: String?

    var body: some View {
        List(app.tree, children: \.children, selection: $selection) { node in
            Label(node.name, systemImage: node.isDirectory ? "folder" : "doc.text")
                .lineLimit(1)
        }
        .onChange(of: selection) { _, path in
            guard let path, app.isFile(path) else { return }
            app.openFile(path)
        }
    }
}
