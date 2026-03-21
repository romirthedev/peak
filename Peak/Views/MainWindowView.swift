import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator
    @State private var selection: SidebarItem = .chat
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "didCompleteOnboarding")

    enum SidebarItem: String, CaseIterable {
        case chat     = "Ask Peak"
        case timeline = "Timeline"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .chat:     return "bubble.left.and.bubble.right.fill"
            case .timeline: return "clock.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } detail: {
            detail
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .environmentObject(orchestrator)
                .onDisappear {
                    UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
                }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(SidebarItem.allCases, id: \.self, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)

            Divider()
            RecordingStatusBar()
                .environmentObject(orchestrator)
                .padding(12)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 230)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .chat:
            ChatView()
                .environmentObject(orchestrator)
        case .timeline:
            TimelineView()
                .environmentObject(orchestrator)
        case .settings:
            SettingsView()
                .environmentObject(orchestrator)
        }
    }
}

// MARK: - Recording status bar at bottom of sidebar

struct RecordingStatusBar: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator

    var body: some View {
        HStack(spacing: 8) {
            RecordingDot(isRecording: orchestrator.isRecording)

            VStack(alignment: .leading, spacing: 1) {
                Text(orchestrator.isRecording ? "Recording" : "Not recording")
                    .font(.caption.weight(.medium))
                if orchestrator.isRecording {
                    Text(formatDuration(orchestrator.recordingDuration))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task {
                    if orchestrator.isRecording {
                        orchestrator.stopRecording()
                    } else {
                        await orchestrator.startRecording()
                    }
                }
            } label: {
                Text(orchestrator.isRecording ? "Stop" : "Start")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(orchestrator.isRecording ? .red : .green)
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct RecordingDot: View {
    let isRecording: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            if isRecording {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .opacity(pulse ? 0 : 1)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
            }
            Circle()
                .fill(isRecording ? Color.red : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)
        }
        .frame(width: 16, height: 16)
        .onAppear { pulse = isRecording }
        .onChange(of: isRecording) { pulse = $0 }
    }
}
