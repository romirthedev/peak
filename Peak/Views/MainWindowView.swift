import SwiftUI

// MARK: - Color Palette

extension Color {
    static let peach       = Color(red: 1.0,  green: 0.85, blue: 0.75)
    static let peachLight  = Color(red: 0.99, green: 0.95, blue: 0.91)
    static let cream       = Color(red: 0.99, green: 0.97, blue: 0.94)
    static let creamDark   = Color(red: 0.94, green: 0.91, blue: 0.86)
    static let ink         = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let inkLight    = Color(red: 0.40, green: 0.37, blue: 0.34)
    static let peachAccent = Color(red: 0.90, green: 0.52, blue: 0.35)
}

// MARK: - Main Window

struct MainWindowView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator
    @Binding var showOnboarding: Bool
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home     = "Home"
        case chat     = "Ask Peak"
        case history  = "History"
        case timeline = "Timeline"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home:     return "house"
            case .chat:     return "message"
            case .history:  return "archivebox"
            case .timeline: return "clock"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .background(Color.cream)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .environmentObject(orchestrator)
                .onDisappear {
                    UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
                }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Logo
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.peachAccent)
                Text("Peak")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Color.ink)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            // Tabs
            VStack(spacing: 2) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    SidebarButton(
                        label: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.12)) { selectedTab = tab }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            // Recording control
            RecordingCard()
                .environmentObject(orchestrator)
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
        }
        .frame(width: 180)
        .background(Color.peachLight)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selectedTab {
        case .home:
            HomeView()
                .environmentObject(orchestrator)
        case .chat:
            ChatView()
                .environmentObject(orchestrator)
        case .history:
            HistoryView()
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

// MARK: - Sidebar Button

private struct SidebarButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .default))
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.ink : Color.inkLight)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.7) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recording Card

struct RecordingCard: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(orchestrator.isRecording ? Color.red : Color.inkLight.opacity(0.25))
                    .frame(width: 7, height: 7)
                Text(orchestrator.isRecording ? "Recording" : "Idle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.ink)
                Spacer()
                if orchestrator.isRecording {
                    Text(fmt(orchestrator.recordingDuration))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.inkLight)
                }
            }

            Button {
                Task {
                    if orchestrator.isRecording { orchestrator.stopRecording() }
                    else { await orchestrator.startRecording() }
                }
            } label: {
                Text(orchestrator.isRecording ? "Stop" : "Start Recording")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(orchestrator.isRecording ? Color.red.opacity(0.8) : Color.peachAccent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func fmt(_ t: TimeInterval) -> String {
        let m = Int(t) / 60; let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(Color.peachAccent)

                VStack(spacing: 6) {
                    Text("Welcome to Peak")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.ink)
                    Text("Everything you do on your Mac, remembered locally.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkLight)
                }
            }

            Spacer().frame(height: 36)

            // Status row
            HStack(spacing: 12) {
                StatusPill(
                    label: "Ollama",
                    value: orchestrator.isOllamaAvailable ? "Connected" : "Offline",
                    color: orchestrator.isOllamaAvailable ? .green : .orange
                )
                StatusPill(label: "Screenshots", value: "\(orchestrator.screenshotCount)", color: Color.peachAccent)
                StatusPill(label: "Audio", value: "\(orchestrator.audioSegmentCount)", color: Color.peachAccent)
                StatusPill(label: "Storage", value: String(format: "%.1f MB", orchestrator.storageUsedMB), color: Color.inkLight)
            }
            .frame(maxWidth: 560)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream)
    }
}

private struct StatusPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.inkLight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Legacy helpers

struct RecordingStatusBar: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator
    var body: some View { RecordingCard().environmentObject(orchestrator) }
}

struct RecordingDot: View {
    let isRecording: Bool
    var body: some View {
        Circle()
            .fill(isRecording ? Color.red : Color.gray.opacity(0.4))
            .frame(width: 8, height: 8)
    }
}
