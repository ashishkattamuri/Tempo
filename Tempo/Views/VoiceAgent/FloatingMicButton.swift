import SwiftUI

/// Animated floating microphone button that triggers the voice scheduling agent.
/// Sits in the bottom-right of the screen as a persistent overlay.
@available(iOS 16, *)
struct FloatingMicButton: View {

    @ObservedObject var agent: VoiceSchedulingAgent
    var onTap: () -> Void

    @State private var pulseScale: CGFloat = 1.0

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
                // Pulse ring (listening only)
                if isListening {
                    Circle()
                        .fill(Color.orange.opacity(0.25))
                        .frame(width: 68, height: 68)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                }

                // Main button
                Circle()
                    .fill(buttonColor)
                    .frame(width: 56, height: 56)
                    .shadow(color: buttonColor.opacity(0.4), radius: 8, x: 0, y: 4)

                // Icon
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isProcessing || !agent.isAgentAvailable)
        .onAppear { pulseScale = 1.15 }
        .onChange(of: isListening) { _, listening in
            pulseScale = listening ? 1.15 : 1.0
        }
    }

    private var buttonColor: Color {
        if isListening { return .orange }
        if isProcessing { return .blue }
        if !agent.isAgentAvailable { return Color(.systemGray3) }
        return .blue
    }
}
