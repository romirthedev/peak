import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let role: Role
    var content: String
    var isStreaming: Bool
    var contextSnippets: [ContextSnippet]

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    struct ContextSnippet: Identifiable, Codable {
        let id: UUID
        let type: String        // "screenshot" or "audio"
        let capturedAt: Date
        let preview: String     // first ~200 chars of the content
        let similarity: Float

        init(id: UUID = UUID(), type: String, capturedAt: Date, preview: String, similarity: Float) {
            self.id = id
            self.type = type
            self.capturedAt = capturedAt
            self.preview = preview
            self.similarity = similarity
        }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        role: Role,
        content: String,
        isStreaming: Bool = false,
        contextSnippets: [ContextSnippet] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.content = content
        self.isStreaming = isStreaming
        self.contextSnippets = contextSnippets
    }
}
