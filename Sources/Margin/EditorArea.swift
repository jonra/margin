import SwiftUI

struct EditorArea: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            if !app.documents.isEmpty {
                TabBar()
                Divider()
            }
            if let document = app.activeDocument {
                EditorPane(document: document)
                    .id(document.id)
            } else {
                Text("Open a file from the project tree, or press ⇧⌘O")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct TabBar: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(app.documents) { document in
                    TabButton(document: document, isActive: document.id == app.activeDocumentID)
                }
            }
        }
        .frame(height: 30)
    }
}

private struct TabButton: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject var document: EditorDocument
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(document.name).lineLimit(1)
            if document.isDirty { Circle().frame(width: 6, height: 6) }
            Button { app.close(document) } label: { Image(systemName: "xmark").font(.caption2) }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            app.saveAll()
            app.activeDocumentID = document.id
        }
        .help(document.id)
    }
}

private struct EditorPane: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var document: EditorDocument

    var body: some View {
        VStack(spacing: 0) {
            if let conflict = document.conflict {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(conflict == .deletedOnDisk
                        ? "\(document.name) was deleted on disk."
                        : "\(document.name) changed on disk while you were editing it.")
                    Spacer()
                    if conflict == .modifiedOnDisk {
                        Button("Load Disk Version") { document.reloadFromDisk(report: app.report) }
                    }
                    if conflict == .deletedOnDisk {
                        Button("Discard My Changes") {
                            document.discardChanges()
                            app.close(document)
                        }
                    }
                    Button("Keep Mine") { document.keepMine() }
                }
                .padding(8)
                .background(Color.yellow.opacity(0.2))
            }
            CodeTextView(document: document)
        }
    }
}
