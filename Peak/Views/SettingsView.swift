import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator

    @AppStorage("captureScreen")   private var captureScreen   = true
    @AppStorage("captureAudio")    private var captureAudio    = true
    @AppStorage("captureInterval") private var captureInterval = 5.0
    @AppStorage("ollamaModel")     private var ollamaModel     = "llama3.2"
    @AppStorage("whisperModel")    private var whisperModel    = "openai_whisper-base"
    @AppStorage("retentionDays")   private var retentionDays   = 30

    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            // ── Recording ─────────────────────────────────────────────────
            Section {
                Toggle("Record screen", isOn: $captureScreen)
                Toggle("Record microphone / meetings", isOn: $captureAudio)

                HStack {
                    Text("Screen capture interval")
                    Spacer()
                    Picker("", selection: $captureInterval) {
                        Text("3 s").tag(3.0)
                        Text("5 s").tag(5.0)
                        Text("10 s").tag(10.0)
                        Text("30 s").tag(30.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .labelsHidden()
                }
            } header: {
                Text("Recording")
            }

            // ── AI ────────────────────────────────────────────────────────
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ollama status")
                        Text(orchestrator.isOllamaAvailable ? "Connected" : "Not connected — make sure Ollama is running")
                            .font(.caption)
                            .foregroundStyle(orchestrator.isOllamaAvailable ? .green : .red)
                    }
                    Spacer()
                    Button("Refresh") {
                        Task { orchestrator.isOllamaAvailable = await AIService().isAvailable() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack {
                    Text("Language model")
                    Spacer()
                    if orchestrator.availableModels.isEmpty {
                        TextField("e.g. llama3.2", text: $ollamaModel)
                            .frame(width: 180)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Picker("", selection: $ollamaModel) {
                            ForEach(orchestrator.availableModels, id: \.self) { m in
                                Text(m).tag(m)
                            }
                        }
                        .frame(width: 180)
                        .labelsHidden()
                    }
                }

                HStack {
                    Text("Whisper model")
                    Spacer()
                    Picker("", selection: $whisperModel) {
                        Text("Tiny (fastest)").tag("openai_whisper-tiny")
                        Text("Base (recommended)").tag("openai_whisper-base")
                        Text("Small (more accurate)").tag("openai_whisper-small")
                        Text("Medium").tag("openai_whisper-medium")
                    }
                    .frame(width: 180)
                    .labelsHidden()
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Transcription")
                        transcriptionStatus
                    }
                    Spacer()
                }
            } header: {
                Text("AI Models")
            }

            // ── Storage ───────────────────────────────────────────────────
            Section {
                HStack {
                    Text("Keep recordings for")
                    Spacer()
                    Picker("", selection: $retentionDays) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("1 year").tag(365)
                        Text("Forever").tag(0)
                    }
                    .frame(width: 180)
                    .labelsHidden()
                }

                HStack {
                    Text("Storage used")
                    Spacer()
                    Text(String(format: "%.1f MB", orchestrator.storageUsedMB))
                        .foregroundStyle(.secondary)
                    Button("Refresh") { orchestrator.refreshStorageStats() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Open Data Folder") {
                    let dir = FileManager.default
                        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("Peak")
                    NSWorkspace.shared.open(dir)
                }

                Button("Clear All Data", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .confirmationDialog(
                    "Delete all Peak data?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Everything", role: .destructive) {
                        clearAllData()
                    }
                } message: {
                    Text("This permanently deletes all screenshots, audio, transcriptions, and memory. This cannot be undone.")
                }
            } header: {
                Text("Storage")
            }

            // ── About ──────────────────────────────────────────────────────
            Section {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Platform", value: "macOS 13+")
                LabeledContent("AI backend", value: "Ollama (local)")
                LabeledContent("Transcription", value: "Whisper (local)")

                Link("View on GitHub", destination: URL(string: "https://github.com/peak-ai/peak")!)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private var transcriptionStatus: some View {
        switch orchestrator.transcription.state {
        case .idle:
            Text("Not loaded")
                .font(.caption).foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Loading Whisper…")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .ready:
            Text("Ready")
                .font(.caption).foregroundStyle(.green)
        case .failed(let msg):
            Text("Failed: \(msg)")
                .font(.caption).foregroundStyle(.red)
        }
    }

    private func clearAllData() {
        let peakDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Peak")

        try? FileManager.default.removeItem(at: peakDir)
        try? FileManager.default.createDirectory(at: peakDir, withIntermediateDirectories: true)
        orchestrator.refreshStorageStats()
    }
}
