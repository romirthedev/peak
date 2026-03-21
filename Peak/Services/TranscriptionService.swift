import Foundation
import WhisperKit

/// Wraps WhisperKit to provide fully local audio transcription.
@MainActor
final class TranscriptionService: ObservableObject {

    @Published private(set) var state: LoadState = .idle

    private var whisper: WhisperKit?

    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    // MARK: - Lifecycle

    func load(modelName: String = "openai_whisper-base") async {
        guard state == .idle else { return }
        state = .loading

        do {
            whisper = try await WhisperKit(model: modelName)
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Transcription

    /// Transcribes the audio file at the given URL and returns the full transcript.
    func transcribe(url: URL) async throws -> String {
        guard let whisper, state == .ready else {
            throw TranscriptionError.modelNotReady
        }

        let results = try await whisper.transcribe(audioPath: url.path)
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isReady: Bool { state == .ready }
    var isLoading: Bool { state == .loading }

    enum TranscriptionError: LocalizedError {
        case modelNotReady

        var errorDescription: String? {
            "Whisper model is not loaded yet. Please wait for initialization to complete."
        }
    }
}
