import SwiftUI

/// Animated floating microphone button that triggers the voice scheduling agent.
/// Shows waveform bars while listening, a spinner while processing/responding.
@available(iOS 16, *)
struct FloatingMicButton: View {

    @ObservedObject var agent: VoiceSchedulingAgent
    var onTap: () -> Void

    private var isListening: Bool {
        if case .listening = agent.state { return true }
        return false
    }

    private var isProcessing: Bool {
        if case .processing = agent.state { return true }
        if case .responding = agent.state { return true }
        return false
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Main button circle
                Circle()
                    .fill(buttonColor)
                    .frame(width: 56, height: 56)
                    .shadow(color: buttonColor.opacity(0.4), radius: 8, x: 0, y: 4)

                // Content: waveform when listening, spinner when busy, mic icon otherwise
                if isListening {
                    FloatingWaveformBars(level: agent.micLevel)
                        .frame(width: 32, height: 24)
                } else if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isProcessing || !agent.isAgentAvailable)
    }

    private var buttonColor: Color {
        if isListening  { return .orange }
        if isProcessing { return .blue }
        if !agent.isAgentAvailable { return Color(.systemGray3) }
        return .blue
    }
}

// MARK: - Waveform Bars (inside button)

@available(iOS 16, *)
private struct FloatingWaveformBars: View {
    var level: Float

    private let barCount = 5
    private let phaseOffsets: [Float] = [0.65, 0.95, 0.55, 1.0, 0.70]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 3.5, height: height(for: i))
                    .animation(.easeInOut(duration: 0.12), value: level)
            }
        }
    }

    private func height(for index: Int) -> CGFloat {
        let minH: CGFloat = 4
        let maxH: CGFloat = 22
        let scaled = CGFloat(level * phaseOffsets[index])
        return minH + scaled * (maxH - minH)
    }
}
