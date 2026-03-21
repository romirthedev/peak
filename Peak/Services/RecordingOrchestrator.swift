import Foundation
import AppKit
import CoreImage

/// Central coordinator: drives all capture services and exposes state to the UI.
@MainActor
final class RecordingOrchestrator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var screenshotCount = 0
    @Published private(set) var audioSegmentCount = 0

    @Published var isOllamaAvailable = false
    @Published var availableModels: [String] = []

    @Published var messages: [ChatMessage] = []
    @Published private(set) var isStreaming = false

    @Published private(set) var recentActivities: [ActivityEvent] = []
    @Published private(set) var storageUsedMB: Double = 0

    // MARK: - Services

    private let screenCapture   = ScreenCaptureService()
    private let ocr             = OCRService()
    private let audioCapture    = AudioCaptureService()
    let transcription           = TranscriptionService()   // `let` so views can observe it
    private let activityMonitor = ActivityMonitorService()
    private let storage         = StorageService()
    private let embedder        = EmbeddingService()
    private let ai              = AIService()

    // MARK: - Settings (read from UserDefaults)

    @AppStorage("ollamaModel")     private var ollamaModel     = "llama3.2"
    @AppStorage("captureInterval") private var captureInterval = 5.0
    @AppStorage("captureScreen")   private var captureScreen   = true
    @AppStorage("captureAudio")    private var captureAudio    = true
    @AppStorage("retentionDays")   private var retentionDays   = 30
    @AppStorage("whisperModel")    private var whisperModel    = "openai_whisper-base"

    private var durationTimer: Timer?

    // MARK: - Initialization

    func initialize() async {
        // Check Ollama
        isOllamaAvailable = await ai.isAvailable()
        if isOllamaAvailable {
            availableModels = (try? await ai.listModels()) ?? []
        }

        // Load Whisper in background
        await transcription.load(modelName: whisperModel)

        // Wire service callbacks
        setupCallbacks()

        // Initial storage stats
        refreshStorageStats()

        // Run retention cleanup
        if retentionDays > 0 {
            storage.deleteDataOlderThan(days: retentionDays)
        }
    }

    // MARK: - Recording Control

    func startRecording() async {
        guard !isRecording else { return }

        do {
            if captureScreen {
                try screenCapture.startCapturing(interval: captureInterval)
            }
            if captureAudio {
                try audioCapture.startRecording()
            }
            activityMonitor.startMonitoring()
        } catch {
            // Surface permission errors as a system message
            let msg = ChatMessage(role: .assistant, content: "⚠️ Could not start recording: \(error.localizedDescription)")
            messages.append(msg)
            return
        }

        isRecording = true
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordingDuration += 1
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        screenCapture.stopCapturing()
        audioCapture.stopRecording()
        activityMonitor.stopMonitoring()

        durationTimer?.invalidate()
        durationTimer = nil
        isRecording = false

        refreshStorageStats()
    }

    // MARK: - Callbacks

    private func setupCallbacks() {
        screenCapture.onScreenCaptured = { [weak self] image, appName, windowTitle in
            guard let self else { return }
            Task { await self.handleScreenCapture(image: image, appName: appName, windowTitle: windowTitle) }
        }

        audioCapture.onSegmentReady = { [weak self] url, duration in
            guard let self else { return }
            Task { await self.handleAudioSegment(url: url, duration: duration) }
        }

        activityMonitor.onActivityChanged = { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                self.recentActivities.insert(event, at: 0)
                if self.recentActivities.count > 200 {
                    self.recentActivities = Array(self.recentActivities.prefix(200))
                }
                self.storage.saveActivity(event)
            }
        }
    }

    // MARK: - Screen Capture Processing

    private func handleScreenCapture(image: CGImage, appName: String, windowTitle: String) async {
        // OCR
        let text: String
        do {
            text = try await ocr.extractText(from: image)
        } catch {
            return
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Save image to disk
        guard let imagePath = saveImage(image) else { return }

        let shot = Screenshot(
            imagePath: imagePath,
            ocrText: text,
            appName: appName,
            windowTitle: windowTitle
        )
        storage.saveScreenshot(shot)

        await MainActor.run { screenshotCount += 1 }

        // Embed asynchronously (best-effort)
        if isOllamaAvailable {
            Task.detached(priority: .background) { [weak self] in
                guard let self else { return }
                let snippet = "[\(appName)] \(windowTitle)\n\(text)".prefix(2000).description
                guard let vector = try? await self.embedder.embed(snippet) else { return }
                self.storage.saveEmbedding(
                    contentId: shot.id,
                    contentType: "screenshot",
                    vector: vector,
                    content: snippet
                )
            }
        }
    }

    // MARK: - Audio Processing

    private func handleAudioSegment(url: URL, duration: TimeInterval) async {
        guard transcription.isReady else { return }

        let text: String
        do {
            text = try await transcription.transcribe(url: url)
        } catch {
            return
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let segment = AudioSegment(
            duration: duration,
            audioPath: url.path,
            transcription: text,
            source: .microphone
        )
        storage.saveAudioSegment(segment)
        await MainActor.run { audioSegmentCount += 1 }

        if isOllamaAvailable {
            Task.detached(priority: .background) { [weak self] in
                guard let self else { return }
                let snippet = "[Audio/Meeting]\n\(text)".prefix(2000).description
                guard let vector = try? await self.embedder.embed(snippet) else { return }
                self.storage.saveEmbedding(
                    contentId: segment.id,
                    contentType: "audio",
                    vector: vector,
                    content: snippet
                )
            }
        }
    }

    // MARK: - AI Query

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        messages.append(ChatMessage(role: .user, content: trimmed))
        isStreaming = true

        // Retrieve semantically similar context
        let context = await relevantContext(for: trimmed)

        // Build system prompt with memory
        let systemPrompt = buildSystemPrompt(context: context)

        // Assemble the conversation history for Ollama
        let history: [[String: String]] = messages.dropLast().suffix(12).map {
            ["role": $0.role.rawValue, "content": $0.content]
        } + [["role": "user", "content": trimmed]]

        // Start streaming assistant response
        var reply = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(reply)
        let idx = messages.count - 1

        do {
            for try await token in ai.chat(messages: history, systemPrompt: systemPrompt) {
                messages[idx].content += token
            }
        } catch {
            messages[idx].content = "I ran into an error: \(error.localizedDescription)\n\n*Make sure Ollama is running and the \(ollamaModel) model is pulled.*"
        }

        messages[idx].isStreaming = false
        isStreaming = false
    }

    // MARK: - Context Retrieval

    private func relevantContext(for query: String) async -> [StorageService.EmbeddingRecord] {
        guard isOllamaAvailable else { return [] }
        guard let queryVec = try? await embedder.embed(query) else { return [] }

        let all = storage.allEmbeddings()
        let scored = all.map { rec -> (StorageService.EmbeddingRecord, Float) in
            let sim = embedder.cosineSimilarity(queryVec, rec.vector)
            return (rec, sim)
        }
        .filter { $0.1 > 0.45 }
        .sorted { $0.1 > $1.1 }
        .prefix(12)
        .map(\.0)

        return Array(scored)
    }

    private func buildSystemPrompt(context: [StorageService.EmbeddingRecord]) -> String {
        let now = Date().formatted(date: .complete, time: .standard)
        var prompt = """
        You are Peak, a personal AI assistant with perfect memory of everything the user has done on their Mac.
        You have access to screen recordings (with text extracted via OCR), meeting transcriptions, and activity logs.
        All data is local and private.

        Current date and time: \(now)

        Your job: answer the user's questions accurately, referencing specific times, applications, and content when relevant.
        If you can't find something in your memory, say so honestly.
        """

        if !context.isEmpty {
            prompt += "\n\n## Memory context (ordered by relevance):\n\n"
            for (i, rec) in context.enumerated() {
                let dateStr = rec.timestamp.formatted(date: .abbreviated, time: .shortened)
                let type = rec.contentType == "screenshot" ? "Screen" : "Audio"
                prompt += "[\(i + 1)] [\(dateStr)] [\(type)]\n\(rec.content.prefix(800))\n\n"
            }
        } else {
            prompt += "\n\n(No relevant memory found for this query. You may not have been recording at the relevant time.)"
        }

        return prompt
    }

    // MARK: - Helpers

    private func saveImage(_ image: CGImage) -> String? {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Peak/screenshots")

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let filename = "shot_\(Int(Date().timeIntervalSince1970)).jpg"
        let fileURL = dir.appendingPathComponent(filename)

        let ciImage = CIImage(cgImage: image)
        let context = CIContext()

        // Scale down to ≤ 1920px wide to save disk space
        let maxW: CGFloat = 1920
        let scale = min(maxW / CGFloat(image.width), 1.0)
        let scaled = scale < 1.0
            ? ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : ciImage

        guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        try? context.writeJPEGRepresentation(
            of: scaled,
            to: fileURL,
            colorSpace: cs,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.65]
        )

        return fileURL.path
    }

    func refreshStorageStats() {
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let bytes = self.storage.totalDatabaseSizeBytes()
            await MainActor.run { self.storageUsedMB = Double(bytes) / 1_000_000 }
        }
    }

    // MARK: - Timeline data

    func activities(for date: Date) -> [ActivityEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return storage.activities(from: start, to: end)
    }

    func screenshots(for date: Date) -> [Screenshot] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return storage.screenshots(from: start, to: end)
    }
}
