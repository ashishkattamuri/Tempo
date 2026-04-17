import Foundation
import Speech
import AVFoundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Conversation

struct ConversationTurn: Identifiable {
    let id = UUID()
    enum Role { case user, agent }
    let role: Role
    let text: String
}

// MARK: - Agent Actions (bridge to SwiftData in ContentView)

enum VoiceAgentAction: Equatable {
    case createTask(title: String, startTime: Date, durationMinutes: Int,
                   category: TaskCategory, notes: String?, taskDefinitionId: UUID?)
    case rescheduleTask(id: UUID, newStartTime: Date)
    case completeTask(id: UUID)
    case deleteTask(id: UUID)
}

// MARK: - VoiceSchedulingAgent

/// Multi-turn voice agent powered by Apple Foundation Models (iOS 26+).
/// Apple STT → Apple FM with tool calling → Apple TTS. 100% on-device.
@available(iOS 16, *)
@MainActor
final class VoiceSchedulingAgent: NSObject, ObservableObject {

    enum AgentState: Equatable {
        case idle, listening, processing, responding, error(String)
    }

    @Published var state: AgentState = .idle
    @Published var liveTranscript: String = ""
    @Published var isAgentAvailable: Bool = false
    @Published var micLevel: Float = 0
    @Published var conversation: [ConversationTurn] = []
    @Published var pendingAction: VoiceAgentAction?

    /// Always false — Gemini is not used.
    let isUsingGeminiLive = false

    weak var sleepManager: SleepManager?

    // Live schedule snapshot — updated optimistically when tools act
    private(set) var scheduleItems: [ScheduleItem] = []
    private var taskDefinitions: [TaskDefinition] = []
    private var habitDefinitions: [HabitDefinition] = []
    private var goalDefinitions: [GoalDefinition] = []

    // MARK: STT
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: TTS
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: FM session (stored as Any? to dodge @available on stored property)
    private var _sessionBox: Any?

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private var fmSession: LanguageModelSession? {
        get { _sessionBox as? LanguageModelSession }
        set { _sessionBox = newValue }
    }
    #endif

    // MARK: - Init

    init(sleepManager: SleepManager?) {
        self.sleepManager = sleepManager
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Lifecycle

    func setup() async {
        let micOK    = await requestMicPermission()
        let speechOK = await requestSpeechPermission()
        isAgentAvailable = micOK && speechOK
    }

    func teardown() {
        stopSTT()
        synthesizer.stopSpeaking(at: .immediate)
        _sessionBox = nil
    }

    // MARK: - Conversation

    /// Call when the user opens the voice overlay.
    func startConversation(
        scheduleItems: [ScheduleItem],
        taskDefinitions: [TaskDefinition],
        habitDefinitions: [HabitDefinition],
        goalDefinitions: [GoalDefinition]
    ) {
        self.scheduleItems    = scheduleItems
        self.taskDefinitions  = taskDefinitions
        self.habitDefinitions = habitDefinitions
        self.goalDefinitions  = goalDefinitions
        conversation  = []
        liveTranscript = ""

        #if canImport(FoundationModels)
        if #available(iOS 26, *) { fmSession = buildSession() }
        #endif

        startListening()
    }

    /// Call when the user dismisses the overlay.
    func endConversation() {
        stopSTT()
        synthesizer.stopSpeaking(at: .immediate)
        _sessionBox = nil
        state = .idle
    }

    /// ContentView calls this after applying a pendingAction so the agent sees the updated schedule.
    func refreshSchedule(_ items: [ScheduleItem]) {
        scheduleItems = items
    }

    // MARK: - STT

    func startListening() {
        guard isAgentAvailable else { return }
        liveTranscript = ""
        do { try beginSTT() }
        catch { state = .error(error.localizedDescription) }
    }

    func stopListening() { stopSTT() }

    /// User tapped "Done" — commit transcript and send to FM.
    func commitAndProcess() {
        let text = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        stopSTT()
        guard !text.isEmpty else { speak("I didn't catch that — try again."); return }
        conversation.append(.init(role: .user, text: text))
        liveTranscript = ""
        state = .processing
        Task { await processWithFM(text) }
    }

    private func beginSTT() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let req = recognitionRequest else { return }
        req.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format    = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
            let lvl = Self.rms(of: buf)
            Task { @MainActor [weak self] in self?.micLevel = min(lvl * 8, 1.0) }
        }
        audioEngine.prepare()
        try audioEngine.start()
        state = .listening

        recognitionTask = speechRecognizer?.recognitionTask(with: req) { [weak self] result, err in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let r = result { self.liveTranscript = r.bestTranscription.formattedString }
                if let e = err, (e as NSError).code != 301 { self.state = .error(e.localizedDescription) }
            }
        }
    }

    private func stopSTT() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask    = nil
        micLevel = 0
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        if case .listening = state { state = .idle }
    }

    private static func rms(of buf: AVAudioPCMBuffer) -> Float {
        guard let d = buf.floatChannelData?[0], buf.frameLength > 0 else { return 0 }
        var s: Float = 0
        for i in 0..<Int(buf.frameLength) { s += d[i] * d[i] }
        return sqrt(s / Float(buf.frameLength))
    }

    // MARK: - FM Processing

    private func processWithFM(_ text: String) async {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), let session = fmSession {
            do {
                let response = try await session.respond(to: text)
                let reply = response.content
                conversation.append(.init(role: .agent, text: reply))
                speak(reply)
                return
            } catch {
                let msg = "Something went wrong — \(error.localizedDescription)"
                conversation.append(.init(role: .agent, text: msg))
                speak(msg)
                return
            }
        }
        #endif
        let msg = "Apple Intelligence isn't available. Make sure iOS 26 with Apple Intelligence is enabled in Settings."
        conversation.append(.init(role: .agent, text: msg))
        speak(msg)
    }

    // MARK: - TTS

    func speak(_ text: String) {
        state = .responding
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let u = AVSpeechUtterance(string: text)
        u.rate = 0.50
        synthesizer.speak(u)
    }

    // MARK: - FM Session Builder

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func buildSession() -> LanguageModelSession {
        let df = DateFormatter(); df.dateFormat = "EEEE, MMMM d, yyyy"
        let tf = DateFormatter(); tf.dateFormat = "h:mm a"
        let now = Date()

        // Summarise today's schedule so the model has immediate context
        let todaySummary = scheduleItems
            .filter { Calendar.current.isDateInToday($0.scheduledDate) && !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }
            .map { i -> String in
                let fmt = DateFormatter(); fmt.dateFormat = "h:mm a"
                return "  • \(i.title) [\(i.category.displayName)] \(fmt.string(from: i.startTime))–\(fmt.string(from: i.endTime))"
            }.joined(separator: "\n")

        let instructions = """
        You are Tempo, a smart personal scheduling assistant built into the user's iPhone.
        Today is \(df.string(from: now)). Current time is \(tf.string(from: now)).

        \(todaySummary.isEmpty ? "Today's schedule is empty." : "Today's schedule:\n\(todaySummary)")

        You help users manage their entire schedule conversationally. You can:
        • View the schedule for any day (get_schedule)
        • Find free time slots for a given duration (find_free_slots)
        • Schedule new tasks, habits, events, or goals (schedule_task)
        • Mark a task as done (complete_task)
        • Move a task to a new time or day (reschedule_task)
        • Delete a task (delete_task)
        • Report this week's productivity stats (get_week_insights)

        Task categories — always clarify if ambiguous:
        • "event" — Non-negotiable appointment (meeting, doctor, class). Cannot be moved.
        • "habit" — Identity habit (workout, meditation, journaling). Protect at all costs; duration can be compressed.
        • "task" — Flexible work item. Can be moved or deferred.
        • "goal" — Optional aspiration. First to defer on a busy day; tracks makeup debt when missed.

        Scheduling rules — follow exactly:
        A. User gives an explicit time (e.g. "at 7pm", "at 3:30", "at noon"):
           → Call schedule_task immediately with that time. Do NOT ask what time. Do NOT call find_free_slots first.
        B. User gives a day but no time (e.g. "schedule gym tomorrow"):
           → Call find_free_slots to get options, then propose the first slot and ask "Does that work?"
        C. schedule_task returns a result starting with "[conflict]":
           → The task was NOT scheduled. Rephrase naturally and ask ONE question:
              "There's already [existing item] at that time. Want me to move it to make room, pick a different time for [new task], or schedule both?"
           → Based on reply: move existing → reschedule_task then schedule_task again;
              different time → find_free_slots, then schedule_task; both → schedule_task with forceSchedule='yes'

        NEVER call find_free_slots when the user already stated a time.
        NEVER ask "which time?" when the user already stated a time.
        When you receive a [conflict] result, NEVER show the raw text — always rephrase naturally.

        When referencing tasks for reschedule/complete/delete, use the 8-char id shown
        in parentheses (e.g. id:a3b4c5d6) from get_schedule output.

        Style: warm, brief, natural. Confirm actions concisely.
        Good: "Done — gym set for 3 pm Saturday."
        Good: "You have 4 things on Sunday. Afternoons are free."
        Bad: "[conflict] 'task' at 3pm overlaps with..." — never say this to the user.
        Ask one focused question when you need clarification.
        """

        return LanguageModelSession(tools: buildTools(), instructions: instructions)
    }

    @available(iOS 26, *)
    private func buildTools() -> [any Tool] {
        // All handlers extract @Generable struct values to plain primitives BEFORE
        // crossing into MainActor.run, so only Sendable types cross the boundary.
        [
            GetScheduleTool(handler: { [weak self] date in
                let d = date
                return await MainActor.run { self?.toolGetSchedule(date: d) ?? "Unavailable" }
            }),
            FindFreeSlotsTool(handler: { [weak self] date, dur in
                let d = date
                let m = Int(dur) ?? 30
                return await MainActor.run { self?.toolFindFreeSlots(date: d, durationMinutes: m) ?? "Unavailable" }
            }),
            ScheduleTaskTool(handler: { [weak self] args in
                let title     = args.title
                let category  = args.category
                let date      = args.date
                let startTime = args.startTime
                let duration  = Int(args.durationMinutes) ?? 30
                let force     = args.forceSchedule.lowercased() == "yes"
                return await MainActor.run { [weak self] in
                    self?.toolScheduleTask(
                        title: title, category: category, date: date,
                        startTime: startTime, durationMinutes: duration,
                        notes: "", forceSchedule: force
                    ) ?? "Unavailable"
                }
            }),
            RescheduleTaskTool(handler: { [weak self] taskId, date, time in
                let i = taskId; let d = date; let t = time
                return await MainActor.run { self?.toolReschedule(taskId: i, date: d, time: t) ?? "Unavailable" }
            }),
            CompleteTaskTool(handler: { [weak self] taskId in
                let i = taskId
                return await MainActor.run { self?.toolComplete(taskId: i) ?? "Unavailable" }
            }),
            DeleteTaskTool(handler: { [weak self] taskId in
                let i = taskId
                return await MainActor.run { self?.toolDelete(taskId: i) ?? "Unavailable" }
            }),
            WeekInsightsTool(handler: { [weak self] in
                return await MainActor.run { self?.toolWeekInsights() ?? "Unavailable" }
            }),
        ]
    }
    #endif

    // MARK: - Tool Implementations

    func toolGetSchedule(date: String) -> String {
        guard let target = parseDate(date) else { return "Couldn't parse date '\(date)'." }
        let cal   = Calendar.current
        let items = scheduleItems
            .filter { cal.isDate($0.scheduledDate, inSameDayAs: target) }
            .sorted { $0.startTime < $1.startTime }
        let tf  = DateFormatter(); tf.dateFormat = "h:mm a"
        let label = dateLabel(target)
        if items.isEmpty { return "Nothing scheduled \(label)." }
        let lines = items.map { i in
            let done = i.isCompleted ? "✓" : "•"
            return "\(done) \(i.title) [\(i.category.displayName)] \(tf.string(from: i.startTime))–\(tf.string(from: i.endTime)) (id:\(i.id.uuidString.prefix(8)))"
        }
        return "\(label.capitalized):\n" + lines.joined(separator: "\n")
    }

    func toolFindFreeSlots(date: String, durationMinutes: Int) -> String {
        guard let target = parseDate(date) else { return "Couldn't parse date '\(date)'." }
        let cal   = Calendar.current
        let items = scheduleItems
            .filter { cal.isDate($0.scheduledDate, inSameDayAs: target) && !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }

        let dayStart: Date
        if cal.isDateInToday(target) {
            let earliest = cal.date(bySettingHour: 7, minute: 0, second: 0, of: target) ?? target
            dayStart = max(Date(), earliest)
        } else {
            dayStart = cal.date(bySettingHour: 7, minute: 0, second: 0, of: target) ?? target
        }
        let sleepCutoff: Date = sleepManager?.getSleepBlockedRange(for: target)?.bufferStart
            ?? cal.date(bySettingHour: 22, minute: 0, second: 0, of: target) ?? target

        var cursor = dayStart
        var slots: [(Date, Date)] = []
        let needed = TimeInterval(durationMinutes * 60)

        for item in items {
            if item.startTime > cursor + needed { slots.append((cursor, item.startTime)) }
            if item.endTime > cursor { cursor = item.endTime }
        }
        if sleepCutoff > cursor + needed { slots.append((cursor, sleepCutoff)) }

        let tf    = DateFormatter(); tf.dateFormat = "h:mm a"
        let label = dateLabel(target)
        if slots.isEmpty { return "No free slots of \(durationMinutes)+ min \(label)." }
        let lines = slots.prefix(5).map { "  \(tf.string(from: $0.0)) – \(tf.string(from: $0.1))" }
        return "Free slots \(label) (\(durationMinutes)+ min):\n" + lines.joined(separator: "\n")
    }

    func toolScheduleTask(title: String, category: String, date: String,
                          startTime: String, durationMinutes: Int,
                          notes: String, forceSchedule: Bool) -> String {
        guard let target = parseDate(date) else { return "Couldn't parse date '\(date)'." }
        let cal = Calendar.current
        let dur = durationMinutes > 0 ? durationMinutes : 30

        // If user gave an explicit time, honour it exactly — never silently move it.
        // Only auto-find a free slot when no time was specified.
        let start: Date
        if !startTime.isEmpty, let t = parseHHmm(startTime, onDate: target) {
            start = t
        } else {
            let dayStart: Date
            if cal.isDateInToday(target) {
                let earliest = cal.date(bySettingHour: 7, minute: 0, second: 0, of: target) ?? target
                dayStart = max(Date(), earliest)
            } else {
                dayStart = cal.date(bySettingHour: 9, minute: 0, second: 0, of: target) ?? target
            }
            start = firstFreeSlot(after: dayStart, duration: dur) ?? dayStart
        }

        let end = cal.date(byAdding: .minute, value: dur, to: start) ?? start

        if !forceSchedule {
            let conflicts = scheduleItems.filter { i in
                cal.isDate(i.scheduledDate, inSameDayAs: target) &&
                !i.isCompleted && i.startTime < end && i.endTime > start
            }
            if !conflicts.isEmpty {
                let tf = DateFormatter(); tf.dateFormat = "h:mm a"
                let conflictDesc = conflicts
                    .map { "'\($0.title)' \(tf.string(from: $0.startTime))–\(tf.string(from: $0.endTime)) (id:\($0.id.uuidString.prefix(8)))" }
                    .joined(separator: "; ")
                return "[conflict] '\(title)' at \(tf.string(from: start)) overlaps with \(conflictDesc). Not scheduled."
            }
        }

        let taskCategory = TaskCategory.from(voiceLabel: category)
        let matchedDef   = taskDefinitions.first { !$0.isCompleted && $0.title.lowercased() == title.lowercased() }
        let finalTitle   = matchedDef?.title ?? title
        let finalDur     = matchedDef?.durationMinutes ?? dur

        let newItem = ScheduleItem(
            title: finalTitle, category: taskCategory,
            startTime: start, durationMinutes: finalDur,
            notes: notes.isEmpty ? nil : notes,
            taskDefinitionId: matchedDef?.id
        )
        scheduleItems.append(newItem)
        pendingAction = .createTask(
            title: finalTitle, startTime: start, durationMinutes: finalDur,
            category: taskCategory,
            notes: notes.isEmpty ? nil : notes,
            taskDefinitionId: matchedDef?.id
        )

        let tf = DateFormatter(); tf.dateFormat = "EEEE 'at' h:mm a"
        return "Scheduled '\(finalTitle)' on \(tf.string(from: start)) for \(finalDur) min. (id:\(newItem.id.uuidString.prefix(8)))"
    }

    func toolReschedule(taskId: String, date: String, time: String) -> String {
        guard let uuid   = resolveTaskId(taskId)                    else { return "Task not found: \(taskId)." }
        guard let target = parseDate(date), let start = parseHHmm(time, onDate: target) else {
            return "Couldn't parse date/time ('\(date)' / '\(time)')."
        }
        let title = scheduleItems.first(where: { $0.id == uuid })?.title ?? taskId
        if let idx = scheduleItems.firstIndex(where: { $0.id == uuid }) {
            scheduleItems[idx].startTime    = start
            scheduleItems[idx].scheduledDate = Calendar.current.startOfDay(for: start)
        }
        pendingAction = .rescheduleTask(id: uuid, newStartTime: start)
        let tf = DateFormatter(); tf.dateFormat = "EEEE 'at' h:mm a"
        return "'\(title)' moved to \(tf.string(from: start))."
    }

    func toolComplete(taskId: String) -> String {
        guard let uuid = resolveTaskId(taskId) else { return "Task not found: \(taskId)." }
        let title = scheduleItems.first(where: { $0.id == uuid })?.title ?? taskId
        if let idx = scheduleItems.firstIndex(where: { $0.id == uuid }) { scheduleItems[idx].isCompleted = true }
        pendingAction = .completeTask(id: uuid)
        return "'\(title)' marked complete. ✓"
    }

    func toolDelete(taskId: String) -> String {
        guard let uuid = resolveTaskId(taskId) else { return "Task not found: \(taskId)." }
        let title = scheduleItems.first(where: { $0.id == uuid })?.title ?? taskId
        scheduleItems.removeAll { $0.id == uuid }
        pendingAction = .deleteTask(id: uuid)
        return "Deleted '\(title)'."
    }

    func toolWeekInsights() -> String {
        let stats = WeeklyStats.forCurrentWeek(items: scheduleItems)
        let df = DateFormatter(); df.dateFormat = "MMM d"
        var lines: [String] = [
            "Week of \(df.string(from: stats.weekStart)):",
            "  \(stats.totalCompleted)/\(stats.totalScheduled) tasks done (\(Int(stats.completionRate * 100))%)",
            "  Time invested: \(stats.totalHoursCompleted)h \(stats.totalMinutesCompleted % 60)m",
        ]
        if stats.identityHabitStreak > 0 {
            lines.append("  Habit streak: \(stats.identityHabitStreak) day\(stats.identityHabitStreak == 1 ? "" : "s") 🔥")
        }
        for row in stats.byCategory {
            lines.append("  \(row.category.displayName): \(row.completed)/\(row.scheduled) (\(Int(row.rate * 100))%)")
        }
        if let best = stats.bestDay {
            let bf = DateFormatter(); bf.dateFormat = "EEEE"
            lines.append("  Best day: \(bf.string(from: best.date)) (\(best.completed) done)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func parseDate(_ s: String) -> Date? {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let lower = s.lowercased().trimmingCharacters(in: .whitespaces)
        if lower == "today"    { return today }
        if lower == "tomorrow" { return cal.date(byAdding: .day, value: 1, to: today) }
        let days = ["sunday","monday","tuesday","wednesday","thursday","friday","saturday"]
        for (i, name) in days.enumerated() where lower == name {
            let wd    = cal.component(.weekday, from: today)  // 1=Sun
            var ahead = (i + 1) - wd
            if ahead <= 0 { ahead += 7 }
            return cal.date(byAdding: .day, value: ahead, to: today)
        }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: s)
    }

    private func parseHHmm(_ s: String, onDate base: Date) -> Date? {
        let cal = Calendar.current
        let raw = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !raw.isEmpty else { return nil }

        // Try multiple formatters in order
        let formatters: [(DateFormatter, String)] = [
            ({ let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }(), "HH:mm"),   // 18:00
            ({ let f = DateFormatter(); f.dateFormat = "h:mma"; return f }(), "h:mma"),   // 6:30pm
            ({ let f = DateFormatter(); f.dateFormat = "h:mm a"; return f }(), "h:mm a"), // 6:30 pm
            ({ let f = DateFormatter(); f.dateFormat = "ha"; return f }(), "ha"),         // 6pm
            ({ let f = DateFormatter(); f.dateFormat = "h a"; return f }(), "h a"),       // 6 pm
        ]
        for (fmt, _) in formatters {
            if let parsed = fmt.date(from: raw) {
                let comps = cal.dateComponents([.hour, .minute], from: parsed)
                if let h = comps.hour, let m = comps.minute {
                    return cal.date(bySettingHour: h, minute: m, second: 0, of: base)
                }
            }
        }
        // Fallback: HH:mm split
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            return cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: base)
        }
        return nil
    }

    private func resolveTaskId(_ prefix: String) -> UUID? {
        scheduleItems.first {
            $0.id.uuidString.hasPrefix(prefix) || $0.id.uuidString == prefix
        }?.id
    }

    private func firstFreeSlot(after start: Date, duration: Int) -> Date? {
        let cal = Calendar.current
        var candidate = start
        let cutoff: Date = sleepManager?.getSleepBlockedRange(for: candidate)?.bufferStart
            ?? cal.date(bySettingHour: 22, minute: 0, second: 0, of: candidate) ?? candidate
        let dayItems = scheduleItems
            .filter { cal.isDate($0.scheduledDate, inSameDayAs: candidate) && !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }
        for _ in 0..<30 {
            let end = cal.date(byAdding: .minute, value: duration, to: candidate) ?? candidate
            if end > cutoff { return nil }
            if let c = dayItems.first(where: { candidate < $0.endTime && end > $0.startTime }) {
                candidate = c.endTime
            } else { return candidate }
        }
        return nil
    }

    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)    { return "today" }
        if cal.isDateInTomorrow(date) { return "tomorrow" }
        return date.formatted(.dateTime.weekday(.wide).month().day())
    }

    // MARK: - Permissions

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            if #available(iOS 17, *) {
                AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }
}

// MARK: - TTS Delegate

@available(iOS 16, *)
extension VoiceSchedulingAgent: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synth: AVSpeechSynthesizer, didFinish utt: AVSpeechUtterance) {
        Task { @MainActor in self.state = .idle }
    }
}

// MARK: - TaskCategory voice helper

extension TaskCategory {
    static func from(voiceLabel label: String) -> TaskCategory {
        switch label.lowercased() {
        case "event", "non-negotiable", "nonnegotiable", "appointment": return .nonNegotiable
        case "habit", "identity habit", "identityhabit":                 return .identityHabit
        case "goal", "optional goal", "optionalgoal":                    return .optionalGoal
        default:                                                          return .flexibleTask
        }
    }
}

// MARK: - Apple FM Tool Definitions (iOS 26+)

#if canImport(FoundationModels)

// ── Argument structs ─────────────────────────────────────────────────────────

@available(iOS 26, *)
@Generable struct GetScheduleArgs {
    @Guide(description: "Target date: 'today', 'tomorrow', a weekday name like 'sunday', or YYYY-MM-DD.")
    var date: String
}

@available(iOS 26, *)
@Generable struct FindFreeSlotsArgs {
    @Guide(description: "Target date: 'today', 'tomorrow', weekday name, or YYYY-MM-DD.")
    var date: String
    @Guide(description: "Required duration in minutes as a plain number string, e.g. '30' or '60'.")
    var durationMinutes: String
}

@available(iOS 26, *)
@Generable struct ScheduleTaskArgs {
    @Guide(description: "Task or event title")
    var title: String
    @Guide(description: "One of: event, habit, task, goal")
    var category: String
    @Guide(description: "Date: today, tomorrow, weekday name like monday, or YYYY-MM-DD")
    var date: String
    @Guide(description: "Start time in 24-hour HH:MM format e.g. 18:00 for 6pm, 09:30 for 9:30am. Leave empty string if unspecified")
    var startTime: String
    @Guide(description: "Duration in minutes as digits e.g. 30 or 60")
    var durationMinutes: String
    @Guide(description: "Write yes to override a conflict and force-schedule anyway, otherwise write no")
    var forceSchedule: String
}

@available(iOS 26, *)
@Generable struct RescheduleTaskArgs {
    @Guide(description: "Task id prefix from get_schedule output (e.g. 'a3b4c5d6').")
    var taskId: String
    @Guide(description: "New date: 'today', 'tomorrow', weekday name, or YYYY-MM-DD.")
    var date: String
    @Guide(description: "New start time string e.g. '18:00', '6pm', '9:30am'.")
    var startTime: String
}

@available(iOS 26, *)
@Generable struct TaskIdArgs {
    @Guide(description: "Task id prefix from get_schedule output (e.g. 'a3b4c5d6').")
    var taskId: String
}

@available(iOS 26, *)
@Generable struct NoArgs {}

// ── Tool structs ─────────────────────────────────────────────────────────────

@available(iOS 26, *)
struct GetScheduleTool: Tool {
    typealias Arguments = GetScheduleArgs
    typealias Output    = String
    let name        = "get_schedule"
    let description = "Get all scheduled items for a specific date, including their IDs for use with other tools."
    let handler: @Sendable (String) async -> String
    func call(arguments: GetScheduleArgs) async throws -> String {
        await handler(arguments.date)
    }
}

@available(iOS 26, *)
struct FindFreeSlotsTool: Tool {
    typealias Arguments = FindFreeSlotsArgs
    typealias Output    = String
    let name        = "find_free_slots"
    let description = "Find available free time blocks on a given date that fit the requested duration."
    let handler: @Sendable (String, String) async -> String
    func call(arguments: FindFreeSlotsArgs) async throws -> String {
        await handler(arguments.date, arguments.durationMinutes)
    }
}

@available(iOS 26, *)
struct ScheduleTaskTool: Tool {
    typealias Arguments = ScheduleTaskArgs
    typealias Output    = String
    let name        = "schedule_task"
    let description = "Create a new scheduled task. Returns CONFLICT info if an overlap is detected and forceSchedule is false — ask the user how to resolve before retrying."
    let handler: @Sendable (ScheduleTaskArgs) async -> String
    func call(arguments: ScheduleTaskArgs) async throws -> String {
        await handler(arguments)
    }
}

@available(iOS 26, *)
struct RescheduleTaskTool: Tool {
    typealias Arguments = RescheduleTaskArgs
    typealias Output    = String
    let name        = "reschedule_task"
    let description = "Move an existing task to a new date and start time."
    let handler: @Sendable (String, String, String) async -> String
    func call(arguments: RescheduleTaskArgs) async throws -> String {
        await handler(arguments.taskId, arguments.date, arguments.startTime)
    }
}

@available(iOS 26, *)
struct CompleteTaskTool: Tool {
    typealias Arguments = TaskIdArgs
    typealias Output    = String
    let name        = "complete_task"
    let description = "Mark a task as completed."
    let handler: @Sendable (String) async -> String
    func call(arguments: TaskIdArgs) async throws -> String {
        await handler(arguments.taskId)
    }
}

@available(iOS 26, *)
struct DeleteTaskTool: Tool {
    typealias Arguments = TaskIdArgs
    typealias Output    = String
    let name        = "delete_task"
    let description = "Permanently delete a task from the schedule."
    let handler: @Sendable (String) async -> String
    func call(arguments: TaskIdArgs) async throws -> String {
        await handler(arguments.taskId)
    }
}

@available(iOS 26, *)
struct WeekInsightsTool: Tool {
    typealias Arguments = NoArgs
    typealias Output    = String
    let name        = "get_week_insights"
    let description = "Get the user's productivity statistics for the current week."
    let handler: @Sendable () async -> String
    func call(arguments: NoArgs) async throws -> String {
        await handler()
    }
}

#endif
