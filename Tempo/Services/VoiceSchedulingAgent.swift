import Foundation
import Speech
import AVFoundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Coordinates the voice scheduling flow:
/// 1. Captures microphone audio via SFSpeechRecognizer (on-device STT)
/// 2. Sends transcript text to Apple Foundation Model for intent/scheduling
/// 3. Plays response audio via GeminiLiveService (with AVSpeechSynthesizer fallback)
@available(iOS 16, *)
@MainActor
final class VoiceSchedulingAgent: ObservableObject {

    // MARK: - State

    enum AgentState {
        case idle
        case listening
        case processing
        case responding
        case error(String)
    }

    @Published var state: AgentState = .idle
    @Published var liveTranscript: String = ""
    @Published var lastResponse: String = ""
    @Published var isAgentAvailable: Bool = false

    // MARK: - Dependencies

    private let geminiService: GeminiLiveService
    weak var sleepManager: SleepManager?

    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Apple Foundation Model session (iOS 26+) — stored as Any? to avoid @available on stored property
    private var _fmSessionBox: Any?

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private var fmSession: LanguageModelSession? {
        get { _fmSessionBox as? LanguageModelSession }
        set { _fmSessionBox = newValue }
    }

    @available(iOS 26, *)
    private func ensureFMSession() -> LanguageModelSession? {
        if let existing = fmSession { return existing }
        guard SystemLanguageModel.default.isAvailable else { return nil }
        let session = LanguageModelSession(instructions: """
            You are a scheduling assistant inside the Tempo productivity app.
            Your ONLY job is to interpret the user's voice request and output a scheduling action.
            Be concise. Respond in plain natural language (no markdown, no lists).
            Today's date is context you will receive in the prompt.
            """)
        fmSession = session
        return session
    }
    #endif

    // MARK: - Init

    init(sleepManager: SleepManager?) {
        self.sleepManager = sleepManager
        self.geminiService = GeminiLiveService(apiKey: Secrets.geminiAPIKey)
    }

    // MARK: - Setup

    func setup() async {
        let speechAuthorized = await requestSpeechPermission()
        let micAuthorized = await requestMicPermission()
        isAgentAvailable = speechAuthorized && micAuthorized
        if isAgentAvailable {
            await geminiService.connect()
        }
    }

    func teardown() {
        stopListening()
        geminiService.disconnect()
    }

    // MARK: - Listening

    func startListening() {
        guard isAgentAvailable else { return }
        guard case .idle = state else { return }

        liveTranscript = ""
        state = .listening

        do {
            try beginRecognition()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        if case .listening = state { state = .idle }
    }

    func commitTranscriptAndProcess(
        scheduleItems: [ScheduleItem],
        taskDefinitions: [TaskDefinition]
    ) async {
        let transcript = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListening()
        guard !transcript.isEmpty else { state = .idle; return }
        await processIntent(transcript, scheduleItems: scheduleItems, taskDefinitions: taskDefinitions)
    }

    // MARK: - Speech Recognition

    private func beginRecognition() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.liveTranscript = result.bestTranscription.formattedString
                }
                if let error, (error as NSError).code != 301 { // 301 = cancelled
                    self.state = .error(error.localizedDescription)
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Intent Processing (Apple Foundation Model)

    private func processIntent(
        _ transcript: String,
        scheduleItems: [ScheduleItem],
        taskDefinitions: [TaskDefinition]
    ) async {
        state = .processing

        let prompt = buildIntentPrompt(
            transcript: transcript,
            scheduleItems: scheduleItems,
            taskDefinitions: taskDefinitions
        )

        let responseText: String

        #if canImport(FoundationModels)
        if #available(iOS 26, *), let session = ensureFMSession() {
            do {
                let result = try await session.respond(
                    to: prompt,
                    generating: VoiceSchedulingResponse.self
                )
                let parsed = result.content
                responseText = parsed.spokenResponse
                await applySchedulingAction26(parsed, scheduleItems: scheduleItems, taskDefinitions: taskDefinitions)
            } catch {
                responseText = "Sorry, I had trouble understanding that. Could you try again?"
            }
        } else {
            responseText = fallbackResponse(for: transcript)
        }
        #else
        responseText = fallbackResponse(for: transcript)
        #endif

        lastResponse = responseText
        await speakResponse(responseText)
    }

    // MARK: - Scheduling Action Application

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func applySchedulingAction26(
        _ response: VoiceSchedulingResponse,
        scheduleItems: [ScheduleItem],
        taskDefinitions: [TaskDefinition]
    ) async {
        // Notify observers so the ScheduleView can apply the change
        let userInfo: [String: Any] = [
            "action": response.action,
            "taskTitle": response.taskTitle ?? "",
            "durationMinutes": response.durationMinutes ?? 30,
            "targetDate": response.targetDate ?? "today",
            "preferredTime": response.preferredTime ?? "",
            "libraryTaskId": response.libraryTaskId ?? ""
        ]
        NotificationCenter.default.post(
            name: .voiceAgentSchedulingAction,
            object: nil,
            userInfo: userInfo
        )
    }
    #endif

    // MARK: - TTS Response

    private func speakResponse(_ text: String) async {
        state = .responding
        switch geminiService.connectionState {
        case .connected:
            await geminiService.sendUserText("Speak this scheduling response to the user: \(text)")
        default:
            geminiService.speakFallback(text)
        }
        // Brief wait then return to idle
        try? await Task.sleep(nanoseconds: 500_000_000)
        state = .idle
    }

    // MARK: - Prompt Builder

    private func buildIntentPrompt(
        transcript: String,
        scheduleItems: [ScheduleItem],
        taskDefinitions: [TaskDefinition]
    ) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let hhmm = DateFormatter()
        hhmm.dateFormat = "HH:mm"
        let today = fmt.string(from: Date())
        let now = hhmm.string(from: Date())

        var lines = [
            "Today: \(today), Current time: \(now)",
            ""
        ]

        // Add sleep constraints
        if let sleep = sleepManager?.getSleepBlockedRange(for: Date()) {
            lines.append("Wind-down buffer starts: \(hhmm.string(from: sleep.bufferStart))")
            lines.append("Bedtime: \(hhmm.string(from: sleep.bedtime))")
            lines.append("")
        }

        // Today's schedule
        let todayItems = scheduleItems
            .filter { Calendar.current.isDateInToday($0.scheduledDate) && !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }

        if !todayItems.isEmpty {
            lines.append("Today's schedule:")
            for item in todayItems {
                lines.append("  \(hhmm.string(from: item.startTime))–\(hhmm.string(from: item.endTime)): \(item.title)")
            }
            lines.append("")
        } else {
            lines.append("Today's schedule: empty")
            lines.append("")
        }

        // Unscheduled tasks from library
        let scheduledIds = Set(scheduleItems.compactMap { $0.taskDefinitionId })
        let unscheduled = taskDefinitions.filter { !$0.isCompleted && !scheduledIds.contains($0.id) }
        if !unscheduled.isEmpty {
            lines.append("Unscheduled tasks in library:")
            for task in unscheduled.prefix(10) {
                var desc = "  - \(task.title) (\(task.durationMinutes)min)"
                if let deadline = task.deadline {
                    let deadlineFmt = DateFormatter()
                    deadlineFmt.dateFormat = "MMM d"
                    desc += " [deadline: \(deadlineFmt.string(from: deadline))]"
                }
                lines.append(desc)
            }
            lines.append("")
        }

        lines.append("User said: \"\(transcript)\"")
        lines.append("")
        lines.append("Interpret the user's scheduling request and respond with the appropriate action.")

        return lines.joined(separator: "\n")
    }

    // MARK: - Fallback

    private func fallbackResponse(for transcript: String) -> String {
        let lower = transcript.lowercased()
        if lower.contains("free") || lower.contains("available") || lower.contains("slot") {
            return "I can see your schedule. You have some free time today. Would you like me to find a specific slot?"
        } else if lower.contains("schedule") || lower.contains("add") || lower.contains("block") {
            return "I'd like to schedule that for you. Apple Intelligence isn't available on this device, so please use the timeline to add it manually."
        }
        return "I heard you, but I need Apple Intelligence to help schedule tasks. Please use the timeline directly."
    }

    // MARK: - Permissions

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicPermission() async -> Bool {
        if #available(iOS 17, *) {
            return await withCheckedContinuation { cont in
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }
}

// MARK: - VoiceSchedulingResponse (Apple Foundation Model structured output)

#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
struct VoiceSchedulingResponse {
    @Guide(description: """
        The scheduling action to perform. One of:
        schedule_new_task: create a new task and schedule it
        schedule_from_library: schedule an existing unscheduled library task
        get_free_slots: user is asking about availability (no action needed)
        cannot_fulfill: cannot understand or fulfill the request
        """)
    var action: String

    @Guide(description: "Brief, friendly spoken response to the user (1-3 sentences, no markdown).")
    var spokenResponse: String

    @Guide(description: "Task title — required for schedule_new_task. Omit otherwise.")
    var taskTitle: String?

    @Guide(description: "Duration in minutes — required for schedule_new_task. Omit otherwise.")
    var durationMinutes: Int?

    @Guide(description: "Target date as 'today', 'tomorrow', or 'YYYY-MM-DD'. Required for scheduling actions.")
    var targetDate: String?

    @Guide(description: "Preferred start time in HH:mm 24-hour format. Optional.")
    var preferredTime: String?

    @Guide(description: "Exact title of the library task to schedule — required for schedule_from_library. Must match exactly.")
    var libraryTaskId: String?
}
#endif

// MARK: - Notification Name

extension Notification.Name {
    static let voiceAgentSchedulingAction = Notification.Name("VoiceAgentSchedulingAction")
}
