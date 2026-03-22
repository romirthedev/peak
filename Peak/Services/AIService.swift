import Foundation

/// Streams chat completions from a locally-running Ollama instance.
final class AIService {

    let baseURL: URL
    private(set) var model: String

    init(baseURL: URL = URL(string: "http://localhost:11434")!, model: String = "llama3.2") {
        self.baseURL = baseURL
        self.model = model
    }

    func setModel(_ name: String) { model = name }

    // MARK: - Availability

    func isAvailable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func listModels() async throws -> [String] {
        let url = baseURL.appendingPathComponent("api/tags")
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let models = json["models"] as? [[String: Any]] ?? []
        return models.compactMap { $0["name"] as? String }
    }

    // MARK: - Streaming Chat

    /// Streams response tokens as an AsyncThrowingStream<String>.
    func chat(
        messages: [[String: String]],
        systemPrompt: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var allMessages = messages
                    if let sys = systemPrompt {
                        allMessages.insert(["role": "system", "content": sys], at: 0)
                    }

                    let url = self.baseURL.appendingPathComponent("api/chat")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "model": self.model,
                        "messages": allMessages,
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (byteStream, _) = try await URLSession.shared.bytes(for: request)

                    for try await line in byteStream.lines {
                        guard !line.isEmpty else { continue }

                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let msg = json["message"] as? [String: Any],
                           let token = msg["content"] as? String {
                            continuation.yield(token)
                        }

                        // Check for done signal
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let done = json["done"] as? Bool, done {
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Single-shot Completion (non-streaming)

    func complete(prompt: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["model": model, "prompt": prompt, "stream": false]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["response"] as? String ?? ""
    }
}
