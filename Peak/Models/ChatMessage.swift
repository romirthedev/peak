import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let role: Role
    var content: String
    var isStreaming: Bool

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        role: Role,
        content: String,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.content = content
        self.isStreaming = isStreaming
    }
}
