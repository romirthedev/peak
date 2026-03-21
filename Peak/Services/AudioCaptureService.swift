import Foundation
import AVFoundation

/// Captures microphone audio in rolling segments and delivers completed audio file URLs.
final class AudioCaptureService: NSObject {

    /// Called with (fileURL, duration) when a segment is ready for transcription.
    var onSegmentReady: ((URL, TimeInterval) -> Void)?

    private var audioEngine: AVAudioEngine?
    private var currentAudioFile: AVAudioFile?
    private var currentSegmentURL: URL?
    private var segmentTimer: Timer?
    private let segmentDuration: TimeInterval

    private(set) var isRecording = false

    init(segmentDuration: TimeInterval = 30.0) {
        self.segmentDuration = segmentDuration
    }

    // MARK: - Public API

    func startRecording() throws {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Open the first segment
        try beginNewSegment(format: format, inputNode: inputNode)

        try engine.start()
        isRecording = true

        // Rotate segments on a timer
        segmentTimer = Timer.scheduledTimer(withTimeInterval: segmentDuration, repeats: true) { [weak self] _ in
            self?.rotateSegment()
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        segmentTimer?.invalidate()
        segmentTimer = nil

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false

        // Deliver the final partial segment
        if let url = currentSegmentURL {
            currentAudioFile = nil
            onSegmentReady?(url, segmentDuration)
            currentSegmentURL = nil
        }
    }

    // MARK: - Private

    private func beginNewSegment(format: AVAudioFormat, inputNode: AVAudioInputNode) throws {
        let url = makeSegmentURL()
        currentSegmentURL = url
        currentAudioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            try? self?.currentAudioFile?.write(from: buffer)
        }
    }

    private func rotateSegment() {
        guard let engine = audioEngine, isRecording else { return }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Finish current segment
        let completedURL = currentSegmentURL
        currentAudioFile = nil
        inputNode.removeTap(onBus: 0)

        if let url = completedURL {
            onSegmentReady?(url, segmentDuration)
        }

        // Start fresh segment
        try? beginNewSegment(format: format, inputNode: inputNode)
    }

    private func makeSegmentURL() -> URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Peak/audio", isDirectory: true)

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let name = "audio_\(Int(Date().timeIntervalSince1970)).m4a"
        return dir.appendingPathComponent(name)
    }
}
