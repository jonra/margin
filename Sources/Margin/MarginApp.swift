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
                .frame(minWidth: 900, minHeight: 600)
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when running the bare executable (swift run) instead of the .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // IntelliJ's "double Shift" opens Go to File.
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.trackShift(event)
            return event
        }
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
