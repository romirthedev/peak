import Foundation

struct SearchResult: Identifiable {
    let id: UUID
    let timestamp: Date
    let content: String
    let source: Source
    let similarity: Float
    let metadata: [String: String]

    enum Source: String {
        case screenshot = "screenshot"
        case audio = "audio"
        case activity = "activity"

        var systemImage: String {
            switch self {
            case .screenshot: return "camera"
            case .audio: return "waveform"
            case .activity: return "app.badge"
            }
        }

        var label: String {
            switch self {
            case .screenshot: return "Screen"
            case .audio: return "Audio"
            case .activity: return "Activity"
            }
        }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date,
        content: String,
        source: Source,
        similarity: Float,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
        self.source = source
        self.similarity = similarity
        self.metadata = metadata
    }

    var appName: String { metadata["appName"] ?? "" }
    var windowTitle: String { metadata["windowTitle"] ?? "" }
}
