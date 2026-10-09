import AppKit
import SwiftUI

@main
struct MarginApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppState()

    var body: some Scene {
        Window("Margin", id: "main") {
            RootView()
                .environmentObject(app)
                .environmentObject(app.review)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear { delegate.appState = app }
                .task { await app.openFromCommandLine() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") { app.chooseFolder() }.keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { app.saveAll() }.keyboardShortcut("s")
            }
            CommandMenu("Navigate") {
                Button("Go to File…") { app.showQuickOpen = true }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Find in Files…") { app.showFindInFiles = true }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                Divider()
                Button("Project") { app.sidebarMode = .project }.keyboardShortcut("1")
                Button("Changes") { app.sidebarMode = .changes }.keyboardShortcut("0")
            }
        }
    }
}

extension Notification.Name {
    static let marginDoubleShift = Notification.Name("marginDoubleShift")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var lastShiftRelease: TimeInterval = 0
    private var shiftWasDown = false
    weak var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGPIPE, SIG_IGN)
        // Needed when running the bare executable (swift run) instead of the .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // IntelliJ's "double Shift" opens Go to File.
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.trackShift(event)
            return event
        }
        // Any other key between the Shift taps cancels the double-Shift gesture.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.lastShiftRelease = 0
            self?.shiftWasDown = false
            return event
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appState else { return .terminateNow }
        MainActor.assumeIsolated { appState.saveAll() }
        guard MainActor.assumeIsolated({ appState.hasUnsavedChanges }) else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "You have unsaved changes that conflict with files on disk"
        alert.informativeText = "Quitting now will discard those edits."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Quit Anyway")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func trackShift(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shiftOnly = flags == .shift
        if shiftOnly {
            shiftWasDown = true
        } else if shiftWasDown && flags.isEmpty {
            shiftWasDown = false
            if event.timestamp - lastShiftRelease < 0.35 {
                lastShiftRelease = 0
                NotificationCenter.default.post(name: .marginDoubleShift, object: nil)
            } else {
                lastShiftRelease = event.timestamp
            }
        } else {
            shiftWasDown = false
        }
    }
}
