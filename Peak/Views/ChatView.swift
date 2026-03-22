import SwiftUI

struct ChatView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    private let suggestions: [String] = [
        "What was I working on this morning?",
        "Summarize my work from yesterday",
        "What meetings did I have this week?",
        "What apps have I used the most today?",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if orchestrator.messages.isEmpty {
                            emptyChatState
                        } else {
                            ForEach(orchestrator.messages) { msg in
                                MessageRow(message: msg)
                                    .id(msg.id)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 6)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                    }
                }
                .onChange(of: orchestrator.messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom") }
                }
                .onChange(of: orchestrator.messages.last?.content) { _ in
                    proxy.scrollTo("bottom")
                }
            }

            // Input
            inputBar
        }
        .background(Color.cream)
        .onAppear { inputFocused = true }
    }

    // MARK: - Empty State

    private var emptyChatState: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 80)

            VStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundStyle(Color.peachAccent)
                Text("Ask me anything")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.ink)
                Text("I can recall everything from your recordings.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkLight)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(suggestions, id: \.self) { q in
                    Button {
                        inputText = q
                        sendMessage()
                    } label: {
                        HStack(spacing: 8) {
                            Text(q)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.peachAccent)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 400)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about anything you've worked on…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Color.ink)
                .lineLimit(1...5)
                .focused($inputFocused)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(canSend ? Color.peachAccent : Color.creamDark)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(alignment: .top) { Divider().foregroundStyle(Color.creamDark) }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !orchestrator.isStreaming
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !orchestrator.isStreaming else { return }
        inputText = ""
        Task { await orchestrator.sendMessage(text) }
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 100)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 100)
            }
        }
    }

    private var userBubble: some View {
        Text(message.content)
            .textSelection(.enabled)
            .font(.system(size: 13.5))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.peachAccent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if message.content.isEmpty && message.isStreaming {
                ThinkingDots()
            } else {
                Text(message.content)
                    .textSelection(.enabled)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            // Context transparency
            if !message.contextSnippets.isEmpty {
                ContextDisclosure(snippets: message.contextSnippets)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ThinkingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.peachAccent)
                    .frame(width: 5, height: 5)
                    .opacity(phase == i ? 1.0 : 0.25)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Context Transparency

private struct ContextDisclosure: View {
    let snippets: [ChatMessage.ContextSnippet]
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                        .font(.system(size: 9))
                    Text("\(snippets.count) context source\(snippets.count == 1 ? "" : "s") used")
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(Color.peachAccent)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(snippets) { snippet in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: snippet.type == "screenshot" ? "camera" : "waveform")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.peachAccent)
                                Text(snippet.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.inkLight)
                                Text("(\(Int(snippet.similarity * 100))% match)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.inkLight.opacity(0.7))
                            }
                            Text(snippet.preview)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.inkLight)
                                .lineLimit(3)
                                .lineSpacing(1)
                        }
                        .padding(6)
                        .background(Color.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.top, 4)
    }
}
