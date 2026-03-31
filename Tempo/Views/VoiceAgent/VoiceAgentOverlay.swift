import SwiftUI

/// Slide-up overlay panel that appears while the voice agent is active.
/// Shows live transcript, current state, and last spoken response.
@available(iOS 16, *)
struct VoiceAgentOverlay: View {

    @ObservedObject var agent: VoiceSchedulingAgent
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 12)

            // State label
            Label(stateLabel, systemImage: stateIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(stateColor)
                .padding(.bottom, 16)

            // Live transcript
            if !agent.liveTranscript.isEmpty {
                Text("\"\(agent.liveTranscript)\"")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeOut, value: agent.liveTranscript)
            }

            // Last response
            if !agent.lastResponse.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.top, 2)
                    Text(agent.lastResponse)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .transition(.opacity)
                .animation(.easeIn, value: agent.lastResponse)
            }

            // Dismiss button
            Button("Done") { onDismiss() }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.blue)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - State appearance

    private var stateLabel: String {
        switch agent.state {
        case .idle:        return "Tap mic to start"
        case .listening:   return "Listening..."
        case .processing:  return "Thinking..."
        case .responding:  return "Speaking..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    private var stateIcon: String {
        switch agent.state {
        case .idle:        return "mic.slash"
        case .listening:   return "mic.fill"
        case .processing:  return "cpu"
        case .responding:  return "speaker.wave.2.fill"
        case .error:       return "exclamationmark.triangle"
        }
    }

    private var stateColor: Color {
        switch agent.state {
        case .listening:   return .orange
        case .processing:  return .blue
        case .responding:  return .green
        case .error:       return .red
        default:           return .secondary
        }
    }
}
