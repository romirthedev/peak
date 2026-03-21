import Foundation

struct AudioSegment: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let audioPath: String
    let transcription: String
    let source: AudioSource
    let embeddingId: UUID?

    enum AudioSource: String, Codable, CaseIterable {
        case microphone = "microphone"
        case system = "system"

        var displayName: String {
            switch self {
            case .microphone: return "Microphone"
            case .system: return "System Audio"
            }
        }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        duration: TimeInterval,
        audioPath: String,
        transcription: String,
        source: AudioSource,
        embeddingId: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.duration = duration
        self.audioPath = audioPath
        self.transcription = transcription
        self.source = source
        self.embeddingId = embeddingId
    }
}
