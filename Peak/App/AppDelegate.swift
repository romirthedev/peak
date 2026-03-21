import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    let orchestrator = RecordingOrchestrator()
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu bar app — no Dock icon
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()

        // Close any auto-opened windows
        NSApp.windows.forEach { $0.close() }

        // Listen for open-main-window notification from menu bar view
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenMainWindow),
            name: .openMainWindow,
            object: nil
        )

        Task { @MainActor in
            await orchestrator.initialize()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        orchestrator.stopRecording()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Peak")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 380)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(orchestrator)
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Main Window

    @objc func handleOpenMainWindow() {
        openMainWindow()
    }

    func openMainWindow() {
        popover?.performClose(nil)

        // Find existing Peak window
        for window in NSApp.windows where window.title == "Peak" {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create a new window via SwiftUI
        let hostingController = NSHostingController(
            rootView: MainWindowView()
                .environmentObject(orchestrator)
                .frame(minWidth: 900, minHeight: 600)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Peak"
        window.setContentSize(NSSize(width: 1100, height: 700))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        mainWindow = window
    }
}

extension Notification.Name {
    static let openMainWindow = Notification.Name("peak.openMainWindow")
    static let recordingStateChanged = Notification.Name("peak.recordingStateChanged")
}
