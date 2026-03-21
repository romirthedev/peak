import Foundation

struct Screenshot: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let imagePath: String
    let ocrText: String
    let appName: String
    let windowTitle: String
    let embeddingId: UUID?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        imagePath: String,
        ocrText: String,
        appName: String,
        windowTitle: String,
        embeddingId: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.imagePath = imagePath
        self.ocrText = ocrText
        self.appName = appName
        self.windowTitle = windowTitle
        self.embeddingId = embeddingId
    }

    /// Summarized label for display in the timeline
    var displayLabel: String {
        windowTitle.isEmpty ? appName : "\(appName) — \(windowTitle)"
    }
}
