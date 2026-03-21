import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator
    @Binding var isPresented: Bool
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar

            // Step content
            TabView(selection: $step) {
                WelcomeStep().tag(0)
                PermissionsStep().tag(1)
                OllamaStep().environmentObject(orchestrator).tag(2)
            }
            .tabViewStyle(.automatic)
            .animation(.easeInOut, value: step)

            Divider()

            // Navigation
            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if step < 2 {
                    Button("Continue") { step += 1 }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return)
                } else {
                    Button("Get Started") { isPresented = false }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return)
                }
            }
            .padding(20)
        }
        .frame(width: 560, height: 480)
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i <= step ? Color.blue : Color.secondary.opacity(0.25))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(spacing: 10) {
                Text("Welcome to Peak")
                    .font(.largeTitle.weight(.bold))

                Text("Your AI-powered memory for everything on your Mac.\nPeak captures your screen and audio locally — never uploaded anywhere.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 40) {
                FeaturePill(icon: "lock.shield.fill", label: "100% local")
                FeaturePill(icon: "camera.fill", label: "Screen memory")
                FeaturePill(icon: "waveform", label: "Meeting recall")
            }

            Spacer()
        }
        .padding(32)
    }
}

private struct FeaturePill: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Step 2: Permissions

private struct PermissionsStep: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Grant Permissions")
                    .font(.title2.weight(.semibold))
                Text("Peak needs these to record and analyse your activity.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            VStack(spacing: 12) {
                PermissionCard(
                    icon: "camera.viewfinder",
                    title: "Screen Recording",
                    description: "Captures what's on screen so Peak can remember it.",
                    buttonLabel: "Grant Access"
                ) {
                    CGRequestScreenCaptureAccess()
                }

                PermissionCard(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Transcribes meetings and voice notes locally.",
                    buttonLabel: "Grant Access"
                ) {
                    AVCaptureDevice.requestAccess(for: .audio) { _ in }
                }

                PermissionCard(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Reads window titles so Peak knows what you're working on.",
                    buttonLabel: "Open Settings"
                ) {
                    let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
                    AXIsProcessTrustedWithOptions(opts)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonLabel: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(buttonLabel, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Step 3: Ollama setup

private struct OllamaStep: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Set Up Local AI")
                    .font(.title2.weight(.semibold))
                Text("Peak uses Ollama to run AI entirely on your Mac — no cloud required.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            // Ollama status card
            HStack(spacing: 12) {
                Circle()
                    .fill(orchestrator.isOllamaAvailable ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(orchestrator.isOllamaAvailable ? "Ollama is running" : "Ollama not detected")
                        .font(.callout.weight(.medium))
                    Text(orchestrator.isOllamaAvailable
                         ? "You're all set!"
                         : "Install Ollama from ollama.ai, then come back.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !orchestrator.isOllamaAvailable {
                    Link("Install →", destination: URL(string: "https://ollama.ai")!)
                        .font(.callout)
                }
            }
            .padding(14)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Terminal commands
            VStack(alignment: .leading, spacing: 10) {
                Text("After installing Ollama, run these in Terminal:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                CopyableCodeBlock("ollama pull llama3.2")
                CopyableCodeBlock("ollama pull nomic-embed-text")
            }

            Button {
                Task { orchestrator.isOllamaAvailable = await AIService().isAvailable() }
            } label: {
                Label("Check Again", systemImage: "arrow.clockwise")
                    .font(.callout)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

private struct CopyableCodeBlock: View {
    let code: String
    @State private var copied = false

    init(_ code: String) { self.code = code }

    var body: some View {
        HStack {
            Text(code)
                .font(.system(.callout, design: .monospaced))
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
