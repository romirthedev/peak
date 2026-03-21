import Foundation
import CoreFoundation

enum Constants {

    enum App {
        static let name     = "Peak"
        static let bundleId = "com.peak.app"
        static let version  = "1.0.0"
    }

    enum Defaults {
        static let captureIntervalSeconds: TimeInterval = 5
        static let audioSegmentSeconds:    TimeInterval = 30
        static let ollamaModel             = "llama3.2"
        static let embeddingModel          = "nomic-embed-text"
        static let whisperModel            = "openai_whisper-base"
        static let ollamaBaseURL           = "http://localhost:11434"
        static let similarityThreshold:   Float = 0.45
        static let maxContextResults       = 12
        static let retentionDays           = 30
        static let maxScreenshotWidth:    CGFloat = 1920
        static let jpegQuality:           CGFloat = 0.65
    }

    enum Storage {
        static let screenshotsFolder = "Peak/screenshots"
        static let audioFolder       = "Peak/audio"
        static let databaseFile      = "Peak/peak.db"
    }
}
