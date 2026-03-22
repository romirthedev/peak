import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator
    @State private var selectedDate = Date()
    @State private var screenshots: [Screenshot] = []
    @State private var audioSegments: [AudioSegment] = []
    @State private var activities: [ActivityEvent] = []
    @State private var embeddings: [StorageService.EmbeddingRecord] = []
    @State private var selectedSection: Section = .all

    enum Section: String, CaseIterable {
        case all = "All"
        case screens = "Screenshots"
        case audio = "Audio"
        case context = "AI Context"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                Text("History")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.ink)

                Spacer()

                // Section picker
                Picker("", selection: $selectedSection) {
                    ForEach(Section.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)

                Spacer()

                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()

                Button("Today") { selectedDate = Date() }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Divider().foregroundStyle(Color.creamDark)

            // Content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if filteredItems.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredItems) { item in
                            HistoryItemRow(item: item)
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Color.cream)
        .onAppear { reload() }
        .onChange(of: selectedDate) { _ in reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 60)
            Image(systemName: "archivebox")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(Color.inkLight.opacity(0.4))
            Text("No recordings")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundStyle(Color.ink)
            Text("Start recording to see your history here.")
                .font(.system(size: 12))
                .foregroundStyle(Color.inkLight)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    struct HistoryItem: Identifiable {
        let id: String
        let timestamp: Date
        let type: String          // "screenshot", "audio", "activity", "embedding"
        let title: String
        let detail: String
        let extraDetail: String?
    }

    private var filteredItems: [HistoryItem] {
        var items: [HistoryItem] = []

        if selectedSection == .all || selectedSection == .screens {
            items += screenshots.map { s in
                HistoryItem(
                    id: s.id.uuidString,
                    timestamp: s.timestamp,
                    type: "screenshot",
                    title: "\(s.appName) — \(s.windowTitle)",
                    detail: String(s.ocrText.prefix(300)),
                    extraDetail: s.imagePath
                )
            }
        }

        if selectedSection == .all || selectedSection == .audio {
            items += audioSegments.map { a in
                HistoryItem(
                    id: a.id.uuidString,
                    timestamp: a.timestamp,
                    type: "audio",
                    title: "Audio (\(Int(a.duration))s)",
                    detail: String(a.transcription.prefix(300)),
                    extraDetail: nil
                )
            }
        }

        if selectedSection == .context {
            let dayEmbeddings = embeddings.filter { emb in
                Calendar.current.isDate(emb.timestamp, inSameDayAs: selectedDate)
            }
            items += dayEmbeddings.map { e in
                HistoryItem(
                    id: e.id,
                    timestamp: e.timestamp,
                    type: "embedding",
                    title: "[\(e.contentType)] Context chunk",
                    detail: String(e.content.prefix(400)),
                    extraDetail: nil
                )
            }
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }

    private func reload() {
        screenshots = orchestrator.screenshots(for: selectedDate)
        audioSegments = orchestrator.audioSegments(for: selectedDate)
        activities = orchestrator.activities(for: selectedDate)
        embeddings = orchestrator.allEmbeddingRecords()
    }
}

// MARK: - History Item Row

private struct HistoryItemRow: View {
    let item: HistoryView.HistoryItem
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } } label: {
                HStack(spacing: 10) {
                    // Type icon
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(iconColor)
                        .frame(width: 28, height: 28)
                        .background(iconColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                    // Time
                    Text(item.timestamp, style: .time)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.inkLight)
                        .frame(width: 56, alignment: .leading)

                    // Type badge
                    Text(item.type.capitalized)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(iconColor)
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    // Title
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.inkLight)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if expanded {
                Text(item.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkLight)
                    .lineSpacing(2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .padding(.leading, 38)
                    .textSelection(.enabled)
            }

            Divider().foregroundStyle(Color.creamDark).padding(.leading, 50)
        }
    }

    private var iconName: String {
        switch item.type {
        case "screenshot": return "camera"
        case "audio":      return "waveform"
        case "embedding":  return "brain"
        default:           return "doc"
        }
    }

    private var iconColor: Color {
        switch item.type {
        case "screenshot": return Color.peachAccent
        case "audio":      return Color(red: 0.3, green: 0.7, blue: 0.5)
        case "embedding":  return Color(red: 0.5, green: 0.4, blue: 0.8)
        default:           return Color.inkLight
        }
    }
}
