import Foundation

/// Generates text embeddings via Ollama's local embedding endpoint and performs vector search.
final class EmbeddingService {

    private let baseURL: URL
    let modelName: String

    init(baseURL: URL = URL(string: "http://localhost:11434")!, modelName: String = "nomic-embed-text") {
        self.baseURL = baseURL
        self.modelName = modelName
    }

    // MARK: - Embedding Generation

    func embed(_ text: String) async throws -> [Float] {
        let url = baseURL.appendingPathComponent("api/embeddings")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: String] = ["model": modelName, "prompt": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw EmbeddingError.serverError
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let doubles = json["embedding"] as? [Double]
        else {
            throw EmbeddingError.invalidResponse
        }

        return doubles.map { Float($0) }
    }

    // MARK: - Similarity Search

    /// Returns cosine similarity in [0, 1].
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dot: Float = 0
        var magA: Float = 0
        var magB: Float = 0

        for i in 0 ..< a.count {
            dot  += a[i] * b[i]
            magA += a[i] * a[i]
            magB += b[i] * b[i]
        }

        let denom = magA.squareRoot() * magB.squareRoot()
        return denom > 0 ? dot / denom : 0
    }

    // MARK: - Errors

    enum EmbeddingError: LocalizedError {
        case serverError
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .serverError: return "Ollama server returned an error. Make sure Ollama is running."
            case .invalidResponse: return "Unexpected response format from Ollama embedding endpoint."
            }
        }
    }
}
