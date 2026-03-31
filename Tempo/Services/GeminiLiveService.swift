import Foundation
import AVFoundation

/// WebSocket client for Gemini Live API real-time audio streaming.
/// Handles bidirectional audio: sends microphone PCM, receives TTS PCM back.
/// Falls back to AVSpeechSynthesizer when the WebSocket is unavailable.
@available(iOS 16, *)
@MainActor
final class GeminiLiveService: NSObject, ObservableObject {

    // MARK: - State

    enum ConnectionState {
        case disconnected, connecting, connected, error(String)
    }

    @Published var connectionState: ConnectionState = .disconnected
    @Published var spokenText: String = ""          // last phrase spoken by Gemini TTS
    @Published var isSpeaking: Bool = false

    // MARK: - Private

    private var webSocket: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)
    private let audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private let synthesizer = AVSpeechSynthesizer()
    private var receiveTask: Task<Void, Never>?

    private let sampleRate: Double = 24_000
    private let apiKey: String

    // Gemini Live endpoint — model that supports audio output
    private var endpointURL: URL? {
        URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)")
    }

    // MARK: - Init

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
        synthesizer.delegate = self
        setupAudioEngine()
    }

    // MARK: - Connection

    func connect() async {
        guard apiKey != "YOUR_GEMINI_API_KEY_HERE", !apiKey.isEmpty else {
            connectionState = .error("No API key configured")
            return
        }
        guard let url = endpointURL else { return }
        connectionState = .connecting
        webSocket = urlSession.webSocketTask(with: url)
        webSocket?.resume()
        await sendSetup()
        connectionState = .connected
        startReceiving()
    }

    func disconnect() {
        receiveTask?.cancel()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        connectionState = .disconnected
    }

    // MARK: - Send Setup Message

    private func sendSetup() async {
        let setup: [String: Any] = [
            "setup": [
                "model": "models/gemini-2.0-flash-live-001",
                "generation_config": [
                    "response_modalities": ["AUDIO"],
                    "speech_config": [
                        "voice_config": [
                            "prebuilt_voice_config": ["voice_name": "Aoede"]
                        ]
                    ]
                ],
                "system_instruction": [
                    "parts": [[
                        "text": "You are a friendly, concise scheduling assistant for the Tempo productivity app. Help the user schedule tasks and manage their day. Keep spoken responses brief — 1-3 sentences. Do not use markdown."
                    ]]
                ]
            ]
        ]
        await sendJSON(setup)
    }

    // MARK: - Send Text Turn

    func sendUserText(_ text: String) async {
        let message: [String: Any] = [
            "client_content": [
                "turns": [[
                    "role": "user",
                    "parts": [["text": text]]
                ]],
                "turn_complete": true
            ]
        ]
        await sendJSON(message)
    }

    // MARK: - Send Realtime Audio Chunk

    func sendAudioChunk(_ pcmData: Data) async {
        let base64 = pcmData.base64EncodedString()
        let message: [String: Any] = [
            "realtime_input": [
                "media_chunks": [[
                    "mime_type": "audio/pcm;rate=16000",
                    "data": base64
                ]]
            ]
        ]
        await sendJSON(message)
    }

    // MARK: - Receive Loop

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let socket = self.webSocket else { break }
                do {
                    let message = try await socket.receive()
                    await self.handleMessage(message)
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.connectionState = .error(error.localizedDescription)
                        }
                    }
                    break
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            await parseServerMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                await parseServerMessage(text)
            }
        @unknown default:
            break
        }
    }

    private func parseServerMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // Handle audio data from Gemini TTS
        if let serverContent = json["serverContent"] as? [String: Any],
           let parts = (serverContent["modelTurn"] as? [String: Any])?["parts"] as? [[String: Any]] {
            for part in parts {
                if let inlineData = part["inlineData"] as? [String: Any],
                   let b64 = inlineData["data"] as? String,
                   let audioData = Data(base64Encoded: b64) {
                    await playAudioData(audioData)
                }
                if let textPart = part["text"] as? String, !textPart.isEmpty {
                    spokenText = textPart
                }
            }
        }

        // Handle transcript from Gemini
        if let transcript = (json["serverContent"] as? [String: Any])?["outputTranscript"] as? String {
            spokenText = transcript
        }
    }

    // MARK: - Audio Playback

    private func setupAudioEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        try? audioEngine.start()
    }

    private func playAudioData(_ data: Data) async {
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                   sampleRate: sampleRate,
                                   channels: 1,
                                   interleaved: false)!
        let frameCount = UInt32(data.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        data.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            buffer.int16ChannelData?[0].update(from: int16Ptr.baseAddress!, count: Int(frameCount))
        }

        isSpeaking = true
        playerNode.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor [weak self] in
                self?.isSpeaking = false
            }
        }
        if !playerNode.isPlaying { playerNode.play() }
    }

    // MARK: - Fallback TTS

    /// Speaks text using on-device AVSpeechSynthesizer (no API key required).
    func speakFallback(_ text: String) {
        spokenText = text
        isSpeaking = true
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    // MARK: - Helpers

    private func sendJSON(_ dict: [String: Any]) async {
        guard let socket = webSocket,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        try? await socket.send(.string(text))
    }
}

// MARK: - AVSpeechSynthesizerDelegate

@available(iOS 16, *)
extension GeminiLiveService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
