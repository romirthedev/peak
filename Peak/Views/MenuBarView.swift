import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            recordingButton
            if orchestrator.isRecording {
                statsRow
            }
            Divider()
            footerButtons
        }
        .frame(width: 300)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(orchestrator.isRecording ? Color.red.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundStyle(orchestrator.isRecording ? .red : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Peak")
                    .font(.headline)
                Text(orchestrator.isRecording ? "Recording…" : "Ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if orchestrator.isRecording {
                Text(formatDuration(orchestrator.recordingDuration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
            }
        }
        .padding(14)
    }

    private var recordingButton: some View {
        Button {
            Task {
                if orchestrator.isRecording {
                    orchestrator.stopRecording()
                } else {
                    await orchestrator.startRecording()
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: orchestrator.isRecording ? "stop.circle.fill" : "record.circle.fill")
                    .font(.title3)
                    .foregroundStyle(orchestrator.isRecording ? .red : .green)

                Text(orchestrator.isRecording ? "Stop Recording" : "Start Recording")
                    .fontWeight(.medium)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.04))
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            StatPill(icon: "camera.fill", value: "\(orchestrator.screenshotCount)", label: "shots")
            StatPill(icon: "waveform", value: "\(orchestrator.audioSegmentCount)", label: "clips")
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var footerButtons: some View {
        VStack(spacing: 0) {
            MenuBarActionButton(label: "Open Peak", icon: "arrow.up.forward.app") {
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            }
            MenuBarActionButton(label: "Quit", icon: "power", role: .destructive) {
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = Int(t) / 60 % 60
        let s = Int(t) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

// MARK: - Small helpers

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MenuBarActionButton: View {
    let label: String
    let icon: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(role == .destructive ? .red : .primary)
                Text(label)
                    .foregroundStyle(role == .destructive ? .red : .primary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }
}
