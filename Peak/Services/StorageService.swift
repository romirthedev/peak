import Foundation
import SQLite

/// Manages the on-disk SQLite database for all captured data.
final class StorageService {

    private var db: Connection?

    // MARK: - Table definitions

    private let screenshots   = Table("screenshots")
    private let audioSegments = Table("audio_segments")
    private let activities    = Table("activity_events")
    private let embeddingsT   = Table("embeddings")

    // Shared columns
    private let colId        = Expression<String>("id")
    private let colTimestamp = Expression<Double>("timestamp")   // stored as unix seconds

    // Screenshot-specific
    private let colImagePath    = Expression<String>("image_path")
    private let colOCRText      = Expression<String>("ocr_text")
    private let colAppName      = Expression<String>("app_name")
    private let colWindowTitle  = Expression<String>("window_title")
    private let colEmbeddingId  = Expression<String?>("embedding_id")

    // Audio-specific
    private let colDuration      = Expression<Double>("duration")
    private let colAudioPath     = Expression<String>("audio_path")
    private let colTranscription = Expression<String>("transcription")
    private let colSource        = Expression<String>("source")

    // Activity-specific
    private let colBundleId = Expression<String>("bundle_identifier")
    private let colURL      = Expression<String?>("url")

    // Embedding-specific
    private let colContentId   = Expression<String>("content_id")
    private let colContentType = Expression<String>("content_type")
    private let colVectorData  = Expression<Data>("vector_data")
    private let colContent     = Expression<String>("content")

    // MARK: - Init

    init() {
        setUpDatabase()
    }

    // MARK: - Setup

    private func setUpDatabase() {
        let supportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Peak")

        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)

        let dbPath = supportDir.appendingPathComponent("peak.db").path

        do {
            db = try Connection(dbPath)
            db?.busyTimeout = 5
            try createTables()
        } catch {
            print("[StorageService] Database setup failed: \(error)")
        }
    }

    private func createTables() throws {
        guard let db else { return }

        try db.run(screenshots.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: true)
            t.column(colTimestamp)
            t.column(colImagePath)
            t.column(colOCRText)
            t.column(colAppName)
            t.column(colWindowTitle)
            t.column(colEmbeddingId)
        })

        try db.run(audioSegments.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: true)
            t.column(colTimestamp)
            t.column(colDuration)
            t.column(colAudioPath)
            t.column(colTranscription)
            t.column(colSource)
            t.column(colEmbeddingId)
        })

        try db.run(activities.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: true)
            t.column(colTimestamp)
            t.column(colAppName)
            t.column(colBundleId)
            t.column(colWindowTitle)
            t.column(colURL)
            t.column(colDuration)
        })

        try db.run(embeddingsT.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: true)
            t.column(colContentId)
            t.column(colContentType)
            t.column(colVectorData)
            t.column(colContent)
            t.column(colTimestamp)
        })

        // Indexes
        try db.run(screenshots.createIndex(colTimestamp, ifNotExists: true))
        try db.run(audioSegments.createIndex(colTimestamp, ifNotExists: true))
        try db.run(activities.createIndex(colTimestamp, ifNotExists: true))
        try db.run(embeddingsT.createIndex(colContentId, ifNotExists: true))
    }

    // MARK: - Screenshots

    func saveScreenshot(_ s: Screenshot) {
        guard let db else { return }
        do {
            try db.run(screenshots.insert(or: .replace,
                colId          <- s.id.uuidString,
                colTimestamp   <- s.timestamp.timeIntervalSince1970,
                colImagePath   <- s.imagePath,
                colOCRText     <- s.ocrText,
                colAppName     <- s.appName,
                colWindowTitle <- s.windowTitle,
                colEmbeddingId <- s.embeddingId?.uuidString
            ))
        } catch {
            print("[StorageService] saveScreenshot failed: \(error)")
        }
    }

    func screenshots(from start: Date, to end: Date) -> [Screenshot] {
        guard let db else { return [] }
        let q = screenshots
            .filter(colTimestamp >= start.timeIntervalSince1970 &&
                    colTimestamp <= end.timeIntervalSince1970)
            .order(colTimestamp.desc)

        return (try? db.prepare(q).map(rowToScreenshot)) ?? []
    }

    func recentScreenshots(limit: Int = 20) -> [Screenshot] {
        guard let db else { return [] }
        let q = screenshots.order(colTimestamp.desc).limit(limit)
        return (try? db.prepare(q).map(rowToScreenshot)) ?? []
    }

    private func rowToScreenshot(_ row: Row) -> Screenshot {
        Screenshot(
            id: UUID(uuidString: row[colId]) ?? UUID(),
            timestamp: Date(timeIntervalSince1970: row[colTimestamp]),
            imagePath: row[colImagePath],
            ocrText: row[colOCRText],
            appName: row[colAppName],
            windowTitle: row[colWindowTitle],
            embeddingId: row[colEmbeddingId].flatMap { UUID(uuidString: $0) }
        )
    }

    // MARK: - Audio Segments

    func saveAudioSegment(_ seg: AudioSegment) {
        guard let db else { return }
        do {
            try db.run(audioSegments.insert(or: .replace,
                colId          <- seg.id.uuidString,
                colTimestamp   <- seg.timestamp.timeIntervalSince1970,
                colDuration    <- seg.duration,
                colAudioPath   <- seg.audioPath,
                colTranscription <- seg.transcription,
                colSource      <- seg.source.rawValue,
                colEmbeddingId <- seg.embeddingId?.uuidString
            ))
        } catch {
            print("[StorageService] saveAudioSegment failed: \(error)")
        }
    }

    func audioSegments(from start: Date, to end: Date) -> [AudioSegment] {
        guard let db else { return [] }
        let q = audioSegments
            .filter(colTimestamp >= start.timeIntervalSince1970 &&
                    colTimestamp <= end.timeIntervalSince1970)
            .order(colTimestamp.desc)

        return (try? db.prepare(q).map(rowToAudioSegment)) ?? []
    }

    private func rowToAudioSegment(_ row: Row) -> AudioSegment {
        AudioSegment(
            id: UUID(uuidString: row[colId]) ?? UUID(),
            timestamp: Date(timeIntervalSince1970: row[colTimestamp]),
            duration: row[colDuration],
            audioPath: row[colAudioPath],
            transcription: row[colTranscription],
            source: AudioSegment.AudioSource(rawValue: row[colSource]) ?? .microphone,
            embeddingId: row[colEmbeddingId].flatMap { UUID(uuidString: $0) }
        )
    }

    // MARK: - Activity Events

    func saveActivity(_ event: ActivityEvent) {
        guard let db else { return }
        do {
            try db.run(activities.insert(or: .replace,
                colId          <- event.id.uuidString,
                colTimestamp   <- event.timestamp.timeIntervalSince1970,
                colAppName     <- event.appName,
                colBundleId    <- event.bundleIdentifier,
                colWindowTitle <- event.windowTitle,
                colURL         <- event.url,
                colDuration    <- event.duration
            ))
        } catch {
            print("[StorageService] saveActivity failed: \(error)")
        }
    }

    func activities(from start: Date, to end: Date) -> [ActivityEvent] {
        guard let db else { return [] }
        let q = activities
            .filter(colTimestamp >= start.timeIntervalSince1970 &&
                    colTimestamp <= end.timeIntervalSince1970)
            .order(colTimestamp)

        return (try? db.prepare(q).map(rowToActivity)) ?? []
    }

    private func rowToActivity(_ row: Row) -> ActivityEvent {
        ActivityEvent(
            id: UUID(uuidString: row[colId]) ?? UUID(),
            timestamp: Date(timeIntervalSince1970: row[colTimestamp]),
            appName: row[colAppName],
            bundleIdentifier: row[colBundleId],
            windowTitle: row[colWindowTitle],
            url: row[colURL],
            duration: row[colDuration]
        )
    }

    // MARK: - Embeddings

    func saveEmbedding(contentId: UUID, contentType: String, vector: [Float], content: String) {
        guard let db else { return }
        let data = vector.withUnsafeBytes { Data($0) }
        do {
            try db.run(embeddingsT.insert(or: .replace,
                colId          <- UUID().uuidString,
                colContentId   <- contentId.uuidString,
                colContentType <- contentType,
                colVectorData  <- data,
                colContent     <- content,
                colTimestamp   <- Date().timeIntervalSince1970
            ))
        } catch {
            print("[StorageService] saveEmbedding failed: \(error)")
        }
    }

    struct EmbeddingRecord {
        let id: String
        let contentId: String
        let contentType: String
        let vector: [Float]
        let content: String
        let timestamp: Date
    }

    func allEmbeddings() -> [EmbeddingRecord] {
        guard let db else { return [] }
        return (try? db.prepare(embeddingsT).map { row -> EmbeddingRecord in
            let data = row[colVectorData]
            let vector: [Float] = data.withUnsafeBytes { ptr in
                Array(ptr.bindMemory(to: Float.self))
            }
            return EmbeddingRecord(
                id: row[colId],
                contentId: row[colContentId],
                contentType: row[colContentType],
                vector: vector,
                content: row[colContent],
                timestamp: Date(timeIntervalSince1970: row[colTimestamp])
            )
        }) ?? []
    }

    // MARK: - Housekeeping

    func deleteDataOlderThan(days: Int) {
        guard let db, days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400).timeIntervalSince1970

        try? db.run(screenshots.filter(colTimestamp < cutoff).delete())
        try? db.run(audioSegments.filter(colTimestamp < cutoff).delete())
        try? db.run(activities.filter(colTimestamp < cutoff).delete())
        try? db.run(embeddingsT.filter(colTimestamp < cutoff).delete())
    }

    func totalDatabaseSizeBytes() -> Int64 {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Peak")
        return FileManager.default.directorySize(at: dir)
    }
}
