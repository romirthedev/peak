import SwiftUI
import AppKit

@main
struct PeakApp: App {
    @StateObject private var orchestrator = RecordingOrchestrator()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "didCompleteOnboarding")

    var body: some Scene {
        WindowGroup {
            MainWindowView(showOnboarding: $showOnboarding)
                .environmentObject(orchestrator)
                .frame(minWidth: 900, minHeight: 620)
                .task {
                    await orchestrator.initialize()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))

        Settings {
            SettingsView()
                .environmentObject(orchestrator)
        }
    }
}
