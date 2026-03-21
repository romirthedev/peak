import SwiftUI

struct ChatView: View {
    @EnvironmentObject var orchestrator: RecordingOrchestrator
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool
    @State private var scrollID: UUID?

    private let suggestions: [String] = [
        "What was I working on last Monday?",
        "Summarize my work from yesterday",
        "What meetings did I have this week?",
        "What apps have I used the most lately?",
        "Write a progress update based on my recent work"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // ── Message list ───────────────────────────────────────────────
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if orchestrator.messages.isEmpty {
                            EmptyChat(suggestions: suggestions) { text in
                                inputText = text
                                sendMessage()
                            }
                            .padding()
                        } else {
                            ForEach(orchestrator.messages) { msg in
                                MessageRow(message: msg)
                                    .id(msg.id)
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                            }
                            // Scroll anchor
                            Color.clear.frame(height: 1).id("bottom")
                        }
                    }
                }
                .onChange(of: orchestrator.messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom") }
                }
                .onChange(of: orchestrator.messages.last?.content) { _ in
                    proxy.scrollTo("bottom")
                }
            }

            // ── Input bar ─────────────────────────────────────────────────
            Divider()
            inputBar
        }
        .background(Color(NSColor.textBackgroundColor))
        .navigationTitle("Ask Peak")
        .onAppear { inputFocused = true }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about anything you've worked on…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($inputFocused)
                .onSubmit { sendMessage() }
                .padding(.vertical, 4)

            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var sendButton: some View {
        Button(action: sendMessage) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(canSend ? Color.blue : Color.secondary.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .keyboardShortcut(.return, modifiers: .command)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !orchestrator.isStreaming
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !orchestrator.isStreaming else { return }
        inputText = ""
        Task { await orchestrator.sendMessage(text) }
    }
}

// MARK: - Empty state

private struct EmptyChat: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 36) {
            Spacer(minLength: 40)

            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.blue.opacity(0.8))

                Text("Perfect Recall")
                    .font(.title2.weight(.semibold))

                Text("I remember everything you've been working on.\nAsk me anything — dates, projects, meetings, writing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Try asking:")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)

                ForEach(suggestions, id: \.self) { q in
                    Button {
                        onSelect(q)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(q)
                                .font(.callout)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Message row

private struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 60)
                userBubble
                avatar(systemImage: "person.circle.fill", color: .secondary)
            } else {
                avatar(systemImage: "brain.head.profile", color: .blue)
                assistantBubble
                Spacer(minLength: 60)
            }
        }
    }

    private var userBubble: some View {
        Text(message.content)
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(BubbleShape(role: .user))
    }

    @ViewBuilder
    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.content.isEmpty && message.isStreaming {
                ThinkingIndicator()
            } else {
                Text(message.content)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.06))
        .clipShape(BubbleShape(role: .assistant))
    }

    private func avatar(systemImage: String, color: Color) -> some View {
        Image(systemName: systemImage)
            .font(.title3)
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
    }
}

private struct BubbleShape: Shape {
    enum Role { case user, assistant }
    let role: Role

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        return path
    }
}

private struct ThinkingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1.0 : 0.3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: false)) {
                phase = (phase + 1) % 3
            }
        }
    }
}
