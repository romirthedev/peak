import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit

/// Periodically captures the entire display and delivers CGImages to its handler.
@MainActor
final class ScreenCaptureService: NSObject {

    var onScreenCaptured: ((CGImage, String, String) -> Void)?

    private var captureTimer: Timer?
    private(set) var isCapturing = false
    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private var latestFrame: CGImage?

    // MARK: - Public API

    func startCapturing(interval: TimeInterval = 5.0) throws {
        guard !isCapturing else { return }

        isCapturing = true

        // Set up ScreenCaptureKit stream for full screen capture
        Task {
            do {
                try await setupStream()
            } catch {
                print("[ScreenCapture] Failed to set up stream: \(error)")
            }
        }

        // Timer to deliver frames at the configured interval
        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.deliverFrame()
            }
        }
        captureTimer?.tolerance = 0.5

        // Deliver first frame after a short delay to let stream start
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { self.deliverFrame() }
        }
    }

    func stopCapturing() {
        captureTimer?.invalidate()
        captureTimer = nil
        isCapturing = false

        if let stream {
            Task {
                try? await stream.stopCapture()
            }
        }
        stream = nil
        streamOutput = nil
        latestFrame = nil
    }

    // MARK: - ScreenCaptureKit Setup

    private func setupStream() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            print("[ScreenCapture] No display found")
            return
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 2) // max 2fps, we only need periodic snapshots
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false

        let output = StreamOutput()
        streamOutput = output

        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
        try await newStream.startCapture()
        stream = newStream
    }

    // MARK: - Frame Delivery

    private func deliverFrame() {
        guard let image = streamOutput?.latestImage else { return }

        let activeApp = NSWorkspace.shared.frontmostApplication
        let appName = activeApp?.localizedName ?? "Unknown"
        let windowTitle = activeWindowTitle(for: activeApp?.processIdentifier) ?? ""

        // Skip tiny/invalid images
        if image.width <= 1 || image.height <= 1 { return }

        onScreenCaptured?(image, appName, windowTitle)
    }

    private func activeWindowTitle(for pid: pid_t?) -> String? {
        guard let pid else { return nil }
        let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        for info in list {
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                ownerPID == pid,
                let title = info[kCGWindowName as String] as? String,
                !title.isEmpty
            else { continue }
            return title
        }
        return nil
    }

    // MARK: - Errors

    enum CaptureError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            "Screen recording permission is required. Please grant access in System Settings > Privacy & Security > Screen Recording, then restart Peak."
        }
    }
}

// MARK: - Stream Output Handler

private class StreamOutput: NSObject, SCStreamOutput {
    private let lock = NSLock()
    private var _latestImage: CGImage?

    var latestImage: CGImage? {
        lock.lock()
        defer { lock.unlock() }
        return _latestImage
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        lock.lock()
        _latestImage = cgImage
        lock.unlock()
    }
}
