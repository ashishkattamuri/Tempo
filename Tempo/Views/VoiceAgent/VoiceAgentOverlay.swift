import SwiftUI

/// Full-height sheet showing a multi-turn conversation with the Tempo voice agent.
/// STT → Apple FM (tools) → TTS, session persists until user taps End.
@available(iOS 16, *)
struct VoiceAgentOverlay: View {

    @ObservedObject var agent: VoiceSchedulingAgent
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            conversationList
            inputArea
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tempo")
                    .font(.headline)
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                    Text("On Device · Apple Intelligence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("End") { onDismiss() }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }

    // MARK: - Conversation

    private var conversationList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if agent.conversation.isEmpty {
                        emptyPrompt
                    } else {
                        ForEach(agent.conversation) { turn in
                            ConversationBubble(turn: turn)
                                .id(turn.id)
                        }
                    }

                    // Live transcript while listening
                    if case .listening = agent.state, !agent.liveTranscript.isEmpty {
                        HStack {
                            Spacer()
                            Text("\"\(agent.liveTranscript)\"")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .italic()
                                .multilineTextAlignment(.trailing)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 16))
                                .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .id("liveTranscript")
                        .transition(.opacity)
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: agent.conversation.count) { _, _ in
                if let last = agent.conversation.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: agent.liveTranscript) { _, t in
                if !t.isEmpty { withAnimation { proxy.scrollTo("liveTranscript", anchor: .bottom) } }
            }
        }
    }

    private var emptyPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue.opacity(0.6))
            Text("Ask me anything about your schedule")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("\"How does Sunday look?\"\n\"Schedule gym 1 hour tomorrow morning\"\n\"What did I finish this week?\"")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, 32)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 12) {
                // Waveform while listening
                if case .listening = agent.state {
                    MicWaveformBars(level: agent.micLevel, color: .orange)
                        .frame(height: 28)
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .scale))
                }

                // State + action row
                HStack(spacing: 16) {
                    // State label
                    Label(stateLabel, systemImage: stateIcon)
                        .font(.subheadline)
                        .foregroundStyle(stateColor)
                    Spacer()

                    // Action buttons
                    switch agent.state {
                    case .listening:
                        Button {
                            agent.commitAndProcess()
                        } label: {
                            Text("Done")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(Color.blue, in: Capsule())
                        }

                    case .idle where !agent.conversation.isEmpty:
                        Button {
                            agent.startListening()
                        } label: {
                            Label("Speak", systemImage: "mic.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(Color.orange, in: Capsule())
                        }

                    case .processing:
                        HStack(spacing: 6) {
                            ProgressView().progressViewStyle(.circular).scaleEffect(0.75)
                            Text("Thinking…").font(.subheadline).foregroundStyle(.secondary)
                        }

                    case .responding:
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.green)
                                .symbolEffect(.pulse)
                            Text("Speaking…").font(.subheadline).foregroundStyle(.secondary)
                        }

                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
        .animation(.easeInOut(duration: 0.2), value: agent.state == .listening)
    }

    // MARK: - State Appearance

    private var stateLabel: String {
        switch agent.state {
        case .idle       where agent.conversation.isEmpty: return "Listening for you…"
        case .idle:                                         return "Ready"
        case .listening:                                    return "Listening…"
        case .processing:                                   return "Thinking…"
        case .responding:                                   return "Speaking…"
        case .error(let msg):                               return "Error: \(msg)"
        }
    }

    private var stateIcon: String {
        switch agent.state {
        case .idle:       return "mic"
        case .listening:  return "mic.fill"
        case .processing: return "ellipsis.circle"
        case .responding: return "speaker.wave.2.fill"
        case .error:      return "exclamationmark.triangle"
        }
    }

    private var stateColor: Color {
        switch agent.state {
        case .listening:  return .orange
        case .processing: return .blue
        case .responding: return .green
        case .error:      return .red
        default:          return .secondary
        }
    }
}

// MARK: - Conversation Bubble

@available(iOS 16, *)
private struct ConversationBubble: View {
    let turn: ConversationTurn

    var isUser: Bool { turn.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            if !isUser {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.blue)
                    .padding(.bottom, 2)
            }

            Text(turn.text)
                .font(.body)
                .foregroundStyle(isUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser ? AnyShapeStyle(Color.blue) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 16)
        .transition(.opacity.combined(with: .move(edge: isUser ? .trailing : .leading)))
    }
}

// MARK: - Waveform Bars

@available(iOS 16, *)
private struct MicWaveformBars: View {
    var level: Float
    var color: Color
    var animated: Bool = false

    private let phaseOffsets: [Float] = [0.7, 1.0, 0.55, 0.85, 0.65, 0.90, 0.60]

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(color)
                    .frame(width: 4, height: barHeight(index: i))
                    .animation(.easeInOut(duration: animated ? 0.5 : 0.12)
                        .repeatForever(autoreverses: animated)
                        .delay(animated ? Double(i) * 0.07 : 0),
                               value: level)
            }
        }
    }

    private func barHeight(index: Int) -> CGFloat {
        let minH: CGFloat = 4; let maxH: CGFloat = 28
        return minH + CGFloat(level * phaseOffsets[index]) * (maxH - minH)
    }
}
