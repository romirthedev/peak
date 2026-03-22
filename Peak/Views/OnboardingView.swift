import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator
    @Binding var isPresented: Bool
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            progressBar

            TabView(selection: $step) {
                WelcomeStep().tag(0)
                PermissionsStep().tag(1)
                OllamaStep().environmentObject(orchestrator).tag(2)
            }
            .tabViewStyle(.automatic)
            .animation(.easeInOut(duration: 0.25), value: step)

            Divider().foregroundStyle(Color.creamDark)

            // Navigation
            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .font(.system(size: 13))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.inkLight)
                }
                Spacer()
                Button(step < 2 ? "Continue" : "Get Started") {
                    if step < 2 { step += 1 }
                    else { isPresented = false }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.peachAccent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
                .keyboardShortcut(.return)
            }
            .padding(20)
        }
        .frame(width: 520, height: 440)
        .background(Color.cream)
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i <= step ? Color.peachAccent : Color.creamDark)
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(Color.peachAccent)

            VStack(spacing: 8) {
                Text("Welcome to Peak")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.ink)

                Text("AI-powered memory for your Mac.\nLocal and private — nothing leaves your machine.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkLight)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            HStack(spacing: 32) {
                FeaturePill(icon: "lock.shield", label: "100% local")
                FeaturePill(icon: "camera", label: "Screen recall")
                FeaturePill(icon: "waveform", label: "Meeting notes")
            }

            Spacer()
        }
        .padding(28)
    }
}

private struct FeaturePill: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color.peachAccent)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.inkLight)
        }
    }
}

// MARK: - Permissions (auto-opens all)

private struct PermissionsStep: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Permissions")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.ink)
                Text("Peak needs these to work. Click each to grant access.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkLight)
            }
            .padding(.top, 20)

            VStack(spacing: 8) {
                PermissionRow(icon: "camera.viewfinder", title: "Screen Recording", desc: "Captures what's on screen") {
                    CGRequestScreenCaptureAccess()
                }
                PermissionRow(icon: "mic", title: "Microphone", desc: "Transcribes meetings locally") {
                    AVCaptureDevice.requestAccess(for: .audio) { _ in }
                }
                PermissionRow(icon: "hand.raised", title: "Accessibility", desc: "Reads window titles") {
                    let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
                    AXIsProcessTrustedWithOptions(opts)
                }
            }

            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.peachAccent)
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 28)
        .onAppear {
            // Auto-request permissions on arrival
            CGRequestScreenCaptureAccess()
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
            let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let desc: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Color.peachAccent)
                    .frame(width: 32, height: 32)
                    .background(Color.peach.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.inkLight)
                }

                Spacer()

                Text("Grant")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.peachAccent)
            }
            .padding(10)
            .background(Color.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ollama

private struct OllamaStep: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Local AI Setup")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.ink)
                Text("Peak uses Ollama to run AI on your Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkLight)
            }
            .padding(.top, 20)

            HStack(spacing: 10) {
                Circle()
                    .fill(orchestrator.isOllamaAvailable ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(orchestrator.isOllamaAvailable ? "Ollama is running" : "Ollama not detected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.ink)
                Spacer()
                if !orchestrator.isOllamaAvailable {
                    Link("Install", destination: URL(string: "https://ollama.ai")!)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.peachAccent)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text("Then run in Terminal:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.inkLight)
                CodeLine("ollama pull llama3.2")
                CodeLine("ollama pull nomic-embed-text")
            }

            Button {
                Task { orchestrator.isOllamaAvailable = await AIService().isAvailable() }
            } label: {
                Label("Check Again", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

private struct CodeLine: View {
    let code: String
    @State private var copied = false

    init(_ code: String) { self.code = code }

    var body: some View {
        HStack {
            Text(code)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.ink)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(copied ? .green : Color.inkLight)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.creamDark)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
