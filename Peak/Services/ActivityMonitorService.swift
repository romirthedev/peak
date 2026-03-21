import Foundation
import AppKit

/// Polls the frontmost application and reports focus changes as ActivityEvents.
final class ActivityMonitorService {

    var onActivityChanged: ((ActivityEvent) -> Void)?

    private var pollingTimer: Timer?
    private let interval: TimeInterval
    private var lastKey: String = ""

    init(interval: TimeInterval = 2.0) {
        self.interval = interval
    }

    // MARK: - Public API

    func startMonitoring() {
        guard pollingTimer == nil else { return }
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        pollingTimer?.tolerance = 0.2
        poll()
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Private

    private func poll() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }

        let appName = app.localizedName ?? "Unknown"
        let bundleId = app.bundleIdentifier ?? ""
        let windowTitle = activeWindowTitle(for: app.processIdentifier) ?? ""
        let url = browserURL(bundleId: bundleId)

        let key = "\(appName)|\(windowTitle)|\(url ?? "")"
        guard key != lastKey else { return }
        lastKey = key

        let event = ActivityEvent(
            appName: appName,
            bundleIdentifier: bundleId,
            windowTitle: windowTitle,
            url: url,
            duration: interval
        )
        onActivityChanged?(event)
    }

    private func activeWindowTitle(for pid: pid_t) -> String? {
        let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        for info in list {
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                ownerPID == pid,
                let title = info[kCGWindowName as String] as? String,
                !title.isEmpty
            else { continue }
            return title
        }
        return nil
    }

    /// Fetch the active tab URL from common browsers via AppleScript.
    private func browserURL(bundleId: String) -> String? {
        let scripts: [String: String] = [
            "com.apple.Safari": "tell application \"Safari\" to get URL of current tab of front window",
            "com.google.Chrome": "tell application \"Google Chrome\" to get URL of active tab of front window",
            "org.mozilla.firefox": "tell application \"Firefox\" to get URL of active tab of front window",
            "com.microsoft.edgemac": "tell application \"Microsoft Edge\" to get URL of active tab of front window",
            "com.brave.Browser": "tell application \"Brave Browser\" to get URL of active tab of front window"
        ]

        guard let script = scripts[bundleId] else { return nil }

        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        return result?.stringValue
    }
}
