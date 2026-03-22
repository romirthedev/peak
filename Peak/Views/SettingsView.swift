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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("Settings")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)

                Divider().foregroundStyle(Color.creamDark)

                VStack(spacing: 24) {
                    // Recording
                    SettingsSection(title: "Recording") {
                        Toggle("Record screen", isOn: $captureScreen)
                        Toggle("Record microphone / meetings", isOn: $captureAudio)

                        HStack {
                            Text("Capture interval")
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
                    }

                    // AI
                    SettingsSection(title: "AI Models") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ollama")
                                Text(orchestrator.isOllamaAvailable ? "Connected" : "Not connected")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(orchestrator.isOllamaAvailable ? .green : .red)
                            }
                            Spacer()
                            Button("Refresh") {
                                Task { orchestrator.isOllamaAvailable = await AIService().isAvailable() }
                            }
                            .font(.system(size: 12, design: .rounded))
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
                                Text("Small (accurate)").tag("openai_whisper-small")
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
                    }

                    // Storage
                    SettingsSection(title: "Storage") {
                        HStack {
                            Text("Keep recordings for")
                            Spacer()
                            Picker("", selection: $retentionDays) {
                                Text("7 days").tag(7)
                                Text("30 days").tag(30)
                                Text("90 days").tag(90)
                                Text("Forever").tag(0)
                            }
                            .frame(width: 180)
                            .labelsHidden()
                        }

                        HStack {
                            Text("Storage used")
                            Spacer()
                            Text(String(format: "%.1f MB", orchestrator.storageUsedMB))
                                .foregroundStyle(Color.inkLight)
                        }

                        HStack(spacing: 12) {
                            Button("Open Data Folder") {
                                let dir = FileManager.default
                                    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                                    .appendingPathComponent("Peak")
                                NSWorkspace.shared.open(dir)
                            }
                            .font(.system(size: 12, design: .rounded))

                            Button("Clear All Data") {
                                showDeleteConfirmation = true
                            }
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.red)
                        }
                        .confirmationDialog(
                            "Delete all Peak data?",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Delete Everything", role: .destructive) { clearAllData() }
                        } message: {
                            Text("This permanently deletes all screenshots, audio, transcriptions, and memory.")
                        }
                    }

                    // About
                    SettingsSection(title: "About") {
                        LabeledContent("Version", value: "1.0.0")
                        LabeledContent("AI backend", value: "Ollama (local)")
                        LabeledContent("Transcription", value: "Whisper (local)")
                    }
                }
                .padding(24)
            }
        }
        .font(.system(size: 13, design: .rounded))
        .foregroundStyle(Color.ink)
        .background(Color.cream)
    }

    @ViewBuilder
    private var transcriptionStatus: some View {
        switch orchestrator.transcription.state {
        case .idle:
            Text("Not loaded")
                .font(.system(size: 11, design: .rounded)).foregroundStyle(Color.inkLight)
        case .loading:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Loading Whisper…")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(Color.inkLight)
            }
        case .ready:
            Text("Ready")
                .font(.system(size: 11, design: .rounded)).foregroundStyle(.green)
        case .failed(let msg):
            Text("Failed: \(msg)")
                .font(.system(size: 11, design: .rounded)).foregroundStyle(.red)
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

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkLight)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(Color.peachLight.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
