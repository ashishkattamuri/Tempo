import Foundation
import FoundationModels

/// On-device AI scheduling assistant using Apple Intelligence (iOS 26+).
/// Proposes intelligent rescheduling decisions for overdue tasks — not just a summary.
/// Returns nil on any failure so callers always fall back to the rule-based engine.
@available(iOS 26, *)
@MainActor
final class SchedulingAssistant {
    static let shared = SchedulingAssistant()

    private let session: LanguageModelSession?

    private init() {
        guard SystemLanguageModel.default.isAvailable else {
            session = nil
            return
        }
        session = LanguageModelSession(instructions: """
            You are an intelligent, compassionate scheduling assistant inside Tempo, a personal productivity app.
            Your job is to propose realistic rescheduling decisions for tasks that weren't completed on time.

            Rules:
            - Never use: missed, failed, behind, skipped, late, overdue, didn't
            - Always use: adjusted, moved, deferred, rescheduled
            - Identity habits (workouts, meditation, journaling) are high priority — fit them today if at all possible, compressed if needed
            - Flexible tasks are lower priority — defer if the day is genuinely packed
            - Never schedule anything during sleep hours or within the wind-down buffer
            - Leave small breathing gaps between tasks rather than packing them back-to-back
            - Proposed times must be in 24-hour HH:mm format
            """)
    }

    // MARK: - Structured Output Types

    @Generable
    struct AIReshuffleProposal {
        @Guide(description: "One decision per task provided in the input, in the same order")
        var decisions: [AITaskDecision]

        @Guide(description: "Warm, compassionate 1-2 sentence summary of the overall plan. No forbidden words (missed/failed/behind/skipped).")
        var summary: String

        @Guide(description: "A short motivating phrase for the user, max 8 words")
        var encouragement: String
    }

    @Generable
    struct AITaskDecision {
        @Guide(description: "The task title exactly as given in the input — do not paraphrase")
        var title: String

        @Guide(description: """
            Proposed action — one of:
            move_today: reschedule to a new time today (provide newStartTime)
            compress_today: shorten the task to fit today (provide newStartTime and newDurationMinutes)
            defer_tomorrow: move to tomorrow morning (no time needed)
            skip: drop from today — only for truly optional tasks when the day is completely full
            """)
        var action: String

        @Guide(description: "Start time in 24-hour HH:mm format. Required for move_today and compress_today. Omit for defer_tomorrow and skip.")
        var newStartTime: String?

        @Guide(description: "Shortened duration in minutes. Only for compress_today. Omit otherwise.")
        var newDurationMinutes: Int?

        @Guide(description: "Brief compassionate reason for this decision, max 10 words")
        var reason: String
    }

    // MARK: - Public API

    /// Ask Apple Intelligence to propose a rescheduling plan for the given overdue tasks.
    /// Returns nil if unavailable or generation fails — caller uses rule-based result instead.
    func proposeReschedule(
        overdueTasks: [ScheduleItem],
        allItems: [ScheduleItem],
        date: Date,
        sleepManager: SleepManager?
    ) async -> AIReshuffleProposal? {
        guard let session, !overdueTasks.isEmpty else { return nil }

        let prompt = buildPrompt(
            overdueTasks: overdueTasks,
            allItems: allItems,
            date: date,
            sleepManager: sleepManager
        )

        do {
            let response = try await session.respond(
                to: prompt,
                generating: AIReshuffleProposal.self
            )
            return response.content
        } catch {
            return nil
        }
    }

    /// Convert an AI proposal into `Change` objects the existing apply pipeline understands.
    /// Matches by index (same order as input) so title paraphrasing never breaks matching.
    /// Every proposed time is validated against sleep schedule and existing slots —
    /// any violation is automatically downgraded to defer_tomorrow.
    func convertToChanges(
        proposal: AIReshuffleProposal,
        overdueTasks: [ScheduleItem],
        date: Date,
        allItems: [ScheduleItem],
        sleepManager: SleepManager?
    ) -> [Change] {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: date) ?? date

        return zip(overdueTasks, proposal.decisions).map { item, decision in
            switch decision.action {
            case "move_today":
                if let timeStr = decision.newStartTime,
                   let slot = parseTime(timeStr, on: date),
                   isValidSlot(slot, duration: item.durationMinutes, allItems: allItems, sleepManager: sleepManager) {
                    return Change(item: item, action: .moved(newStartTime: slot), reason: decision.reason)
                }
                // Proposed time failed validation — find the next real free slot
                if let safeSlot = firstFreeSlot(on: tomorrow, duration: item.durationMinutes, allItems: allItems, sleepManager: sleepManager) {
                    return Change(item: item, action: .deferred(newDate: safeSlot), reason: "Moved to next available slot — proposed time wasn't free")
                }
                return Change(item: item, action: .requiresUserDecision(options: [
                    Change.UserOption(title: "Defer to tomorrow", description: "Manually pick a time on tomorrow's schedule"),
                    Change.UserOption(title: "Mark as done", description: "Mark \"\(item.title)\" as completed")
                ]), reason: "No free slot found in the next 7 days")

            case "compress_today":
                let duration = decision.newDurationMinutes ?? item.minimumDurationMinutes ?? item.durationMinutes
                if let timeStr = decision.newStartTime,
                   let slot = parseTime(timeStr, on: date),
                   isValidSlot(slot, duration: duration, allItems: allItems, sleepManager: sleepManager) {
                    return Change(item: item, action: .movedAndResized(newStartTime: slot, newDurationMinutes: duration), reason: decision.reason)
                }
                if let safeSlot = firstFreeSlot(on: tomorrow, duration: item.durationMinutes, allItems: allItems, sleepManager: sleepManager) {
                    return Change(item: item, action: .deferred(newDate: safeSlot), reason: "Moved to next available slot — proposed time wasn't free")
                }
                return Change(item: item, action: .requiresUserDecision(options: [
                    Change.UserOption(title: "Defer to tomorrow", description: "Manually pick a time on tomorrow's schedule"),
                    Change.UserOption(title: "Mark as done", description: "Mark \"\(item.title)\" as completed")
                ]), reason: "No free slot found in the next 7 days")

            case "defer_tomorrow":
                if let safeSlot = firstFreeSlot(on: tomorrow, duration: item.durationMinutes, allItems: allItems, sleepManager: sleepManager) {
                    return Change(item: item, action: .deferred(newDate: safeSlot), reason: decision.reason)
                }
                return Change(item: item, action: .requiresUserDecision(options: [
                    Change.UserOption(title: "Defer to tomorrow", description: "Manually pick a time on tomorrow's schedule"),
                    Change.UserOption(title: "Mark as done", description: "Mark \"\(item.title)\" as completed")
                ]), reason: "No free slot found in the next 7 days")

            default: // "skip" or unknown
                return Change(item: item, action: .protected, reason: decision.reason)
            }
        }
    }

    // MARK: - Constraint Validators

    /// Returns true only if the slot is in the future, before the sleep buffer,
    /// and doesn't overlap any existing non-completed item on the same day.
    private func isValidSlot(
        _ start: Date,
        duration: Int,
        allItems: [ScheduleItem],
        sleepManager: SleepManager?
    ) -> Bool {
        let cal = Calendar.current
        let now = Date()
        guard start > now else { return false }

        let end = cal.date(byAdding: .minute, value: duration, to: start) ?? start

        // Reject if start OR end falls in the sleep window
        if let sleep = sleepManager?.getSleepBlockedRange(for: start) {
            if start >= sleep.bufferStart || end > sleep.bufferStart { return false }
        }

        // Reject if it overlaps any existing non-completed item on the same day
        let sameDay = allItems.filter {
            $0.scheduledDate.isSameDay(as: start) && !$0.isCompleted
        }
        for existing in sameDay {
            if start < existing.endTime && end > existing.startTime { return false }
        }

        return true
    }

    /// Find the first genuinely free slot starting from `date`, searching up to 7 days forward.
    /// Returns nil if no conflict-free, sleep-respecting slot is found within that window.
    private func firstFreeSlot(
        on date: Date,
        duration: Int,
        allItems: [ScheduleItem],
        sleepManager: SleepManager?
    ) -> Date? {
        let cal = Calendar.current

        for dayOffset in 0..<7 {
            guard let searchDate = cal.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            var candidate = searchDate.withTime(hour: 9)

            let dayItems = allItems
                .filter { $0.scheduledDate.isSameDay(as: searchDate) && !$0.isCompleted }
                .sorted { $0.startTime < $1.startTime }

            for _ in 0..<30 {
                let end = cal.date(byAdding: .minute, value: duration, to: candidate) ?? candidate

                // No room before sleep on this day — try next day
                if let sleep = sleepManager?.getSleepBlockedRange(for: candidate),
                   candidate >= sleep.bufferStart || end > sleep.bufferStart {
                    break
                }

                if let conflict = dayItems.first(where: { candidate < $0.endTime && end > $0.startTime }) {
                    candidate = conflict.endTime
                } else {
                    return candidate
                }
            }
        }

        return nil // No slot found in the next 7 days
    }

    // MARK: - Prompt Builder

    private func buildPrompt(
        overdueTasks: [ScheduleItem],
        allItems: [ScheduleItem],
        date: Date,
        sleepManager: SleepManager?
    ) -> String {
        let now = Date()
        let hhmm = DateFormatter()
        hhmm.dateFormat = "HH:mm"

        var lines: [String] = ["=== SCHEDULING CONTEXT ==="]

        lines.append("Current time: \(hhmm.string(from: now))")

        if let sleep = sleepManager?.getSleepBlockedRange(for: now) {
            lines.append("Wind-down buffer starts: \(hhmm.string(from: sleep.bufferStart)) (do not schedule into or past this)")
            lines.append("Bedtime: \(hhmm.string(from: sleep.bedtime))")
            lines.append("Wake time tomorrow: \(hhmm.string(from: sleep.wakeTime))")
        } else {
            lines.append("No sleep schedule configured. Assume day ends at 22:00.")
        }

        let futureItems = allItems
            .filter { $0.scheduledDate.isSameDay(as: date) && !$0.isCompleted && $0.startTime > now }
            .sorted { $0.startTime < $1.startTime }

        if futureItems.isEmpty {
            lines.append("\nNo other tasks scheduled for the rest of today.")
        } else {
            lines.append("\nOccupied slots today (do not overlap these):")
            for item in futureItems {
                lines.append("  \(hhmm.string(from: item.startTime))–\(hhmm.string(from: item.endTime)): \"\(item.title)\"")
            }
        }

        lines.append("\n=== TASKS TO RESCHEDULE ===")
        for task in overdueTasks {
            var desc = "• \"\(task.title)\" | \(task.category.displayName) | \(task.durationMinutes) min"
            if task.isCompressible, let minDur = task.minimumDurationMinutes {
                desc += " | compressible to minimum \(minDur) min"
            }
            lines.append(desc)
        }

        lines.append("""

        Propose the best action for each task. Only suggest move_today or compress_today \
        if there is genuinely enough free time before the wind-down buffer. \
        Be realistic — a packed evening means defer_tomorrow.
        """)

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func parseTime(_ timeString: String, on date: Date) -> Date? {
        let cal = Calendar.current
        let parts = timeString.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        var components = cal.dateComponents([.year, .month, .day], from: date)
        components.hour = parts[0]
        components.minute = parts[1]
        return cal.date(from: components)
    }
}
