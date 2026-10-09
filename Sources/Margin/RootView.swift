import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var review: ReviewModel

    var body: some View {
        Group {
            if app.workspace == nil {
                WelcomeView()
            } else {
                NavigationSplitView {
                    VStack(spacing: 0) {
                        Picker("Sidebar", selection: $app.sidebarMode) {
                            ForEach(AppState.SidebarMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .padding(8)
                        switch app.sidebarMode {
                        case .project: FileTreeView()
                        case .changes: ChangesView()
                        }
                    }
                    .navigationSplitViewColumnWidth(min: 220, ideal: 300)
                } detail: {
                    if app.sidebarMode == .changes, let file = review.selectedFile {
                        DiffView(file: file)
                            .id(file.id)
                    } else {
                        EditorArea()
                    }
                }
            }
        }
        .navigationTitle(app.workspace?.root.lastPathComponent ?? "Margin")
        .sheet(isPresented: $app.showQuickOpen) { QuickOpenView().environmentObject(app) }
        .sheet(isPresented: $app.showFindInFiles) { FindInFilesView().environmentObject(app) }
        .alert("Something went wrong", isPresented: Binding(
            get: { app.errorMessage != nil }, set: { if !$0 { app.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(app.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .marginDoubleShift)) { _ in
            if app.workspace != nil { app.showQuickOpen = true }
        }
    }
}

private struct WelcomeView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 12) {
            Text("Margin").font(.largeTitle.weight(.semibold))
            Text("Browse code. Review what your agents changed.").foregroundStyle(.secondary)
            Button("Open Folder…") { app.chooseFolder() }
                .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
