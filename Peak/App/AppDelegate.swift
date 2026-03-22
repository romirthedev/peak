import AppKit

// Minimal delegate — no menu bar logic. The app is a normal windowed app now.
final class AppDelegate: NSObject, NSApplicationDelegate {}

extension Notification.Name {
    static let openMainWindow = Notification.Name("peak.openMainWindow")
    static let recordingStateChanged = Notification.Name("peak.recordingStateChanged")
}
