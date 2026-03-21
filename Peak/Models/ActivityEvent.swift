import Foundation

struct ActivityEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let appName: String
    let bundleIdentifier: String
    let windowTitle: String
    let url: String?
    let duration: TimeInterval

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        appName: String,
        bundleIdentifier: String,
        windowTitle: String,
        url: String? = nil,
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.url = url
        self.duration = duration
    }

    var displayTitle: String {
        if let url, let host = URL(string: url)?.host {
            return "\(appName) · \(host)"
        }
        return windowTitle.isEmpty ? appName : "\(appName) · \(windowTitle)"
    }

    var isBrowser: Bool {
        ["com.apple.Safari",
         "com.google.Chrome",
         "org.mozilla.firefox",
         "com.microsoft.edgemac",
         "com.brave.Browser"].contains(bundleIdentifier)
    }
}
