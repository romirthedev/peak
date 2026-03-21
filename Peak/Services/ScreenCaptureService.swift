import Foundation
import CoreGraphics
import AppKit

/// Periodically captures the entire display and delivers CGImages to its handler.
@MainActor
final class ScreenCaptureService: NSObject {

    // Called with (image, frontmost app name, active window title) on each capture.
    var onScreenCaptured: ((CGImage, String, String) -> Void)?

    private var captureTimer: Timer?
    private(set) var isCapturing = false

    // MARK: - Public API

    func startCapturing(interval: TimeInterval = 5.0) throws {
        guard !isCapturing else { return }

        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            throw CaptureError.permissionDenied
        }

        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.captureFrame()
            }
        }
        captureTimer?.tolerance = 0.5
        isCapturing = true

        // First capture immediately
        captureFrame()
    }

    func stopCapturing() {
        captureTimer?.invalidate()
        captureTimer = nil
        isCapturing = false
    }

    // MARK: - Private

    private func captureFrame() {
        let activeApp = NSWorkspace.shared.frontmostApplication
        let appName = activeApp?.localizedName ?? "Unknown"
        let windowTitle = activeWindowTitle(for: activeApp?.processIdentifier) ?? ""

        guard let image = captureDisplay() else { return }
        onScreenCaptured?(image, appName, windowTitle)
    }

    private func captureDisplay() -> CGImage? {
        let displayID = CGMainDisplayID()
        return CGDisplayCreateImage(displayID)
    }

    private func activeWindowTitle(for pid: pid_t?) -> String? {
        guard let pid else { return nil }
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

    // MARK: - Errors

    enum CaptureError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            "Screen recording permission is required. Please grant access in System Settings > Privacy & Security > Screen Recording."
        }
    }
}
