import Foundation
import os.log

private let slotFinderLog = OSLog(subsystem: "com.tempo.app", category: "SlotFinder")

// MARK: - Debug Logger
private class SlotFinderDebugLog {
    static let shared = SlotFinderDebugLog()
    private var logFile: URL?
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            logFile = docs.appendingPathComponent("slot_debug.log")
            // Clear log on init
            try? "".write(to: logFile!, atomically: true, encoding: .utf8)
        }
    }

    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        guard let logFile = logFile, let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: logFile)
        }
    }
}

private func debugLog(_ message: String) {
    SlotFinderDebugLog.shared.log(message)
}

/// Main coordinator for schedule reshuffling.
/// Implements the 9-step decision process to compassionately adjust schedules.
@MainActor
final class ReshuffleEngine {
    private let overflowDetector = OverflowDetector()
    private let eveningAnalyzer = EveningProtectionAnalyzer()
    private let summaryGenerator = SummaryGenerator()

    /// Optional sleep manager for blocking sleep times
    var sleepManager: SleepManager?

    // Category processors
    private let nonNegotiableProcessor = NonNegotiableProcessor()
    private let identityHabitProcessor = IdentityHabitProcessor()
    private let flexibleTaskProcessor = FlexibleTaskProcessor()
    private let optionalGoalProcessor = OptionalGoalProcessor()

    /// Analyze the schedule and produce a reshuffle result.
    /// This does NOT apply changes - it only proposes them.
    func analyze(
        items: [ScheduleItem],
        for date: Date,
        currentTime: Date = Date()
    ) -> ReshuffleResult {
        // Step 1: Create context
        let context = ReshuffleContext.create(for: date, items: items, currentTime: currentTime)

        // Step 2: Check if any reshuffle is needed
        if !needsReshuffle(context: context) {
            return .onTrack(protectedItems: items.map { item in
                Change(item: item, action: .protected, reason: "On track")
            })
        }

        // Step 3: Analyze overflow
        let overflowAnalysis = overflowDetector.analyze(context: context)

        // Step 4: Analyze evening protection
        let eveningDecision = eveningAnalyzer.analyze(
            items: items,
            for: date,
            overflowAnalysis: overflowAnalysis
        )

        // Step 5: Process each item by category
        var changes: [Change] = []

        // Process in priority order
        for item in context.itemsByPriority {
            let change = processItem(item, context: context, overflowAnalysis: overflowAnalysis)
            changes.append(change)
        }

        // Step 6: Handle evening items separately if evening protection triggered
        if eveningDecision.requiresConsent {
            // Evening changes need user consent - mark them appropriately
            changes = handleEveningProtection(
                changes: changes,
                eveningDecision: eveningDecision,
                context: context
            )
        }

        // Step 7: Generate summary
        let summary = summaryGenerator.generate(
            changes: changes,
            eveningDecision: eveningDecision
        )

        // Step 8: Build result
        return ReshuffleResult(
            changes: changes,
            summary: summary,
            eveningProtectionTriggered: eveningDecision.requiresConsent,
            eveningDecision: eveningDecision
        )
    }

    // MARK: - Private Methods

    private func needsReshuffle(context: ReshuffleContext) -> Bool {
        // No items = no issues
        if context.incompleteItems.isEmpty {
            return false
        }

        // Check for overflow
        if context.hasOverflow {
            return true
        }

        // Check for conflicts
        for item in context.incompleteItems {
            for other in context.incompleteItems {
                if item.id != other.id && item.overlaps(with: other) {
                    return true
                }
            }
        }

        // Check if current time has passed scheduled items (only for today)
        if context.targetDate.isToday {
            for item in context.incompleteItems {
                if item.startTime < context.currentTime {
                    return true
                }
            }
        }

        return false
    }

    private func processItem(
        _ item: ScheduleItem,
        context: ReshuffleContext,
        overflowAnalysis: OverflowDetector.OverflowAnalysis
    ) -> Change {
        // Select processor based on category
        let processor: CategoryProcessor

        switch item.category {
        case .nonNegotiable:
            processor = nonNegotiableProcessor
        case .identityHabit:
            processor = identityHabitProcessor
        case .flexibleTask:
            processor = flexibleTaskProcessor
        case .optionalGoal:
            processor = optionalGoalProcessor
        }

        return processor.process(item: item, context: context)
    }

    private func handleEveningProtection(
        changes: [Change],
        eveningDecision: EveningDecision,
        context: ReshuffleContext
    ) -> [Change] {
        var modifiedChanges = changes

        // Find evening items in the changes
        for (index, change) in modifiedChanges.enumerated() {
            if change.item.isEveningTask {
                // Check if the proposed change would affect evening
                switch change.action {
                case .moved(let newTime) where newTime.isEvening:
                    // This would push into evening - mark for user decision
                    modifiedChanges[index] = Change(
                        item: change.item,
                        action: .requiresUserDecision(options: [
                            Change.UserOption(
                                title: "Keep in evening",
                                description: "Allow this task in your evening"
                            ),
                            Change.UserOption(
                                title: "Defer to tomorrow",
                                description: "Move to tomorrow instead"
                            )
                        ]),
                        reason: "This would affect your protected evening time"
                    )
                default:
                    break
                }
            }
        }

        return modifiedChanges
    }
}

// MARK: - Convenience Extensions

extension ReshuffleEngine {
    /// Quick check if there's any issue with the current schedule
    func hasIssues(items: [ScheduleItem], for date: Date) -> Bool {
        let context = ReshuffleContext.create(for: date, items: items)
        return needsReshuffle(context: context)
    }

    /// Get a simple status message
    func statusMessage(items: [ScheduleItem], for date: Date) -> String {
        let context = ReshuffleContext.create(for: date, items: items)

        if !needsReshuffle(context: context) {
            return Constants.CompassionateMessage.onTrack
        }

        let analysis = overflowDetector.analyze(context: context)

        switch analysis.suggestedStrategy {
        case .noAction:
            return Constants.CompassionateMessage.onTrack
        case .compressHabits:
            return "Some adjustments suggested to fit everything in"
        case .deferOptionals:
            return "Consider deferring some optional goals"
        case .deferFlexible:
            return "Schedule is tight - some tasks may need to move"
        case .fullDayDisruption:
            return Constants.CompassionateMessage.fullDayDisruption
        }
    }

    /// Find tasks that conflict with a new/updated task
    func findConflicts(for newItem: ScheduleItem, in existingItems: [ScheduleItem]) -> [ScheduleItem] {
        existingItems.filter { existing in
            existing.id != newItem.id &&
            existing.scheduledDate.isSameDay(as: newItem.scheduledDate) &&
            !existing.isCompleted &&
            newItem.overlaps(with: existing)
        }
    }

    /// Suggest how to resolve conflicts based on priority
    /// - Parameters:
    ///   - newItem: The newly created/edited item
    ///   - conflictingItems: Items that conflict with the new item
    ///   - allItems: All items on the schedule (for finding empty slots)
    func suggestResolution(newItem: ScheduleItem, conflictingItems: [ScheduleItem], allItems: [ScheduleItem] = []) -> [ConflictResolution] {
        var resolutions: [ConflictResolution] = []
        let now = Date()
        let calendar = Calendar.current

        let fmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM d, h:mm a"
            return f
        }()

        debugLog("═══════════════════════════════════════════════════════════")
        debugLog("SUGGEST RESOLUTION CALLED")
        debugLog("  Current time (now): \(fmt.string(from: now))")
        debugLog("  New item: \"\(newItem.title)\" [\(newItem.category.displayName)]")
        debugLog("  New item time: \(fmt.string(from: newItem.startTime)) - \(fmt.string(from: newItem.endTime))")
        debugLog("  Conflicting items (\(conflictingItems.count)):")
        for c in conflictingItems {
            debugLog("    - \"\(c.title)\": \(fmt.string(from: c.startTime)) - \(fmt.string(from: c.endTime))")
        }
        debugLog("  All items count: \(allItems.count)")

        // Helper to ensure a date is not in the past
        func ensureNotPast(_ date: Date, label: String) -> Date {
            guard date < now else { return date }
            debugLog("  ⚠️ \(label) is in the past: \(fmt.string(from: date))")
            let minutes = calendar.component(.minute, from: now)
            let roundedMinutes = ((minutes / 15) + 1) * 15
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            if roundedMinutes >= 60 {
                components.hour = (components.hour ?? 0) + 1
                components.minute = 0
            } else {
                components.minute = roundedMinutes
            }
            let result = calendar.date(from: components) ?? now
            debugLog("    → Adjusted to: \(fmt.string(from: result))")
            return result
        }

        // Find the best slot to move the NEW item
        let latestConflictEnd = conflictingItems.map { $0.endTime }.max() ?? newItem.endTime
        debugLog("  Finding slot for NEW item after: \(fmt.string(from: latestConflictEnd))")
        var slotForNewItem = findNextAvailableSlot(
            after: latestConflictEnd,
            duration: newItem.durationMinutes,
            on: newItem.scheduledDate,
            allItems: allItems,
            excluding: [newItem] + conflictingItems
        )
        slotForNewItem = ensureNotPast(slotForNewItem, label: "slotForNewItem")
        debugLog("  → Final slot for new item: \(fmt.string(from: slotForNewItem))")

        // Track slots we've already assigned to avoid double-booking
        var assignedSlots: [(start: Date, end: Date)] = []

        for conflicting in conflictingItems {
            let resolution: ConflictResolution

            debugLog("───────────────────────────────────────────────────────────")
            debugLog("  Finding slot for CONFLICTING: \"\(conflicting.title)\"")
            debugLog("    Duration: \(conflicting.durationMinutes) min")
            debugLog("    isRecurring: \(conflicting.isRecurring), isDaily: \(conflicting.isDaily), isWeekly: \(conflicting.isWeekly)")
            debugLog("    Already assigned slots: \(assignedSlots.count)")

            // Check if conflicting item is a recurring habit that cannot be moved
            if conflicting.isRecurring && conflicting.category == .identityHabit {
                if conflicting.isDaily {
                    // Daily habits CANNOT be moved - only compress or keep both
                    debugLog("    Daily habit - cannot move, suggesting keepBoth")
                    resolution = ConflictResolution(
                        conflictingItem: conflicting,
                        newItem: newItem,
                        suggestion: .userDecision(moveConflictingTo: conflicting.startTime, moveNewTo: slotForNewItem),
                        reason: "\"\(conflicting.title)\" is a daily habit - consider compressing or skipping today"
                    )
                    resolutions.append(resolution)
                    continue
                } else if conflicting.isWeekly {
                    // Weekly habits - find a slot on a day without the same habit
                    if let validSlot = findSlotForWeeklyHabit(
                        conflicting,
                        after: newItem.endTime,
                        allItems: allItems,
                        excluding: [newItem] + conflictingItems,
                        avoidSlots: assignedSlots
                    ) {
                        debugLog("    Weekly habit - found valid slot on different day: \(fmt.string(from: validSlot))")
                        let slotEnd = calendar.date(byAdding: .minute, value: conflicting.durationMinutes, to: validSlot) ?? validSlot
                        assignedSlots.append((start: validSlot, end: slotEnd))

                        resolution = ConflictResolution(
                            conflictingItem: conflicting,
                            newItem: newItem,
                            suggestion: .moveConflicting(to: validSlot),
                            reason: "Moving to a day when this habit isn't already scheduled"
                        )
                        resolutions.append(resolution)
                        continue
                    } else {
                        // No valid day found - cannot move
                        debugLog("    Weekly habit - no valid day found, suggesting keepBoth")
                        resolution = ConflictResolution(
                            conflictingItem: conflicting,
                            newItem: newItem,
                            suggestion: .userDecision(moveConflictingTo: conflicting.startTime, moveNewTo: slotForNewItem),
                            reason: "\"\(conflicting.title)\" is scheduled on all nearby days - consider compressing or skipping"
                        )
                        resolutions.append(resolution)
                        continue
                    }
                }
            }

            // Find best slot - exclude ALL conflicting items and avoid assigned slots
            var slotForConflicting = findNextAvailableSlotForConflicting(
                after: newItem.endTime,
                duration: conflicting.durationMinutes,
                on: conflicting.scheduledDate,
                allItems: allItems,
                excluding: [newItem] + conflictingItems,
                avoidSlots: assignedSlots
            )
            debugLog("    Raw slot returned: \(fmt.string(from: slotForConflicting))")
            slotForConflicting = ensureNotPast(slotForConflicting, label: "slotForConflicting")
            debugLog("    FINAL slot: \(fmt.string(from: slotForConflicting))")

            // Track this slot
            let slotEnd = calendar.date(byAdding: .minute, value: conflicting.durationMinutes, to: slotForConflicting) ?? slotForConflicting
            assignedSlots.append((start: slotForConflicting, end: slotEnd))

            // Determine resolution based on priority
            if newItem.category == .nonNegotiable {
                resolution = ConflictResolution(
                    conflictingItem: conflicting,
                    newItem: newItem,
                    suggestion: .moveConflicting(to: slotForConflicting),
                    reason: "\"\(newItem.title)\" is non-negotiable - moving \"\(conflicting.title)\" to next available slot"
                )
            } else if newItem.category.priority < conflicting.category.priority {
                resolution = ConflictResolution(
                    conflictingItem: conflicting,
                    newItem: newItem,
                    suggestion: .moveConflicting(to: slotForConflicting),
                    reason: "\"\(newItem.title)\" (\(newItem.category.displayName)) has higher priority"
                )
            } else if newItem.category.priority > conflicting.category.priority {
                resolution = ConflictResolution(
                    conflictingItem: conflicting,
                    newItem: newItem,
                    suggestion: .moveNew(to: slotForNewItem),
                    reason: "\"\(conflicting.title)\" (\(conflicting.category.displayName)) has higher priority"
                )
            } else {
                resolution = ConflictResolution(
                    conflictingItem: conflicting,
                    newItem: newItem,
                    suggestion: .userDecision(moveConflictingTo: slotForConflicting, moveNewTo: slotForNewItem),
                    reason: "Both tasks have the same priority level"
                )
            }

            resolutions.append(resolution)
        }

        debugLog("═══════════════════════════════════════════════════════════")
        return resolutions
    }

    /// Find slot for a conflicting item, also avoiding already-assigned slots
    private func findNextAvailableSlotForConflicting(
        after time: Date,
        duration: Int,
        on date: Date,
        allItems: [ScheduleItem],
        excluding: [ScheduleItem],
        avoidSlots: [(start: Date, end: Date)]
    ) -> Date {
        let now = Date()
        let calendar = Calendar.current

        // Never start looking before current time
        var searchStartTime = time
        if searchStartTime < now {
            let minutes = calendar.component(.minute, from: now)
            let roundedMinutes = ((minutes / 15) + 1) * 15
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            if roundedMinutes >= 60 {
                components.hour = (components.hour ?? 0) + 1
                components.minute = 0
            } else {
                components.minute = roundedMinutes
            }
            searchStartTime = calendar.date(from: components) ?? now
        }

        var candidateTime = findNextAvailableSlot(
            after: searchStartTime,
            duration: duration,
            on: date,
            allItems: allItems,
            excluding: excluding
        )

        // Check if this slot overlaps with any already-assigned slot
        var iterations = 0
        while iterations < 20 {
            iterations += 1
            let candidateEnd = calendar.date(byAdding: .minute, value: duration, to: candidateTime) ?? candidateTime

            var hasOverlap = false
            for assigned in avoidSlots {
                if candidateTime < assigned.end && candidateEnd > assigned.start {
                    candidateTime = assigned.end
                    hasOverlap = true
                    break
                }
            }

            if !hasOverlap { break }

            candidateTime = findNextAvailableSlot(
                after: candidateTime,
                duration: duration,
                on: date,
                allItems: allItems,
                excluding: excluding
            )
        }

        // Final check: never return a past time
        if candidateTime < now {
            let minutes = calendar.component(.minute, from: now)
            let roundedMinutes = ((minutes / 15) + 1) * 15
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            if roundedMinutes >= 60 {
                components.hour = (components.hour ?? 0) + 1
                components.minute = 0
            } else {
                components.minute = roundedMinutes
            }
            candidateTime = calendar.date(from: components) ?? now
        }

        return candidateTime
    }

    /// Find a valid slot for a weekly recurring habit on a day that doesn't have the same habit scheduled
    private func findSlotForWeeklyHabit(
        _ habit: ScheduleItem,
        after time: Date,
        allItems: [ScheduleItem],
        excluding: [ScheduleItem],
        avoidSlots: [(start: Date, end: Date)]
    ) -> Date? {
        let calendar = Calendar.current

        // Check the next few days (within the same week)
        for dayOffset in 0...6 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: habit.scheduledDate) else {
                continue
            }

            // For day 0 (same day), only look for slots after the conflict
            let searchAfter: Date
            if dayOffset == 0 {
                searchAfter = time
            } else {
                searchAfter = targetDate.startOfDay.withTime(hour: 6)
            }

            // Check if this day of week is in the recurrence schedule
            let targetWeekday = calendar.component(.weekday, from: targetDate) - 1 // 0-indexed
            if habit.recurrenceDays.contains(targetWeekday) && dayOffset > 0 {
                // This day already has this habit scheduled, skip it
                continue
            }

            // Check if we're still in the same week (don't defer to next week)
            let habitWeek = calendar.component(.weekOfYear, from: habit.scheduledDate)
            let targetWeek = calendar.component(.weekOfYear, from: targetDate)
            if targetWeek != habitWeek && dayOffset > 0 {
                break // Don't move to next week
            }

            // Try to find a slot on this day
            let candidateSlot = findNextAvailableSlotForConflicting(
                after: searchAfter,
                duration: habit.durationMinutes,
                on: targetDate,
                allItems: allItems,
                excluding: excluding,
                avoidSlots: avoidSlots
            )

            // Verify the slot is on the target date (not pushed to next day)
            if candidateSlot.isSameDay(as: targetDate) {
                return candidateSlot
            }
        }

        return nil
    }

    /// Find the next available time slot that doesn't conflict with existing items
    private func findNextAvailableSlot(
        after time: Date,
        duration: Int,
        on date: Date,
        allItems: [ScheduleItem],
        excluding: [ScheduleItem]
    ) -> Date {
        let calendar = Calendar.current
        let minHour = 6
        let now = Date()

        let fmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM d, h:mm a"
            return f
        }()

        var candidateTime = time

        debugLog("  ┌─ findNextAvailableSlot ─────────────────────────────────")
        debugLog("  │ Input 'after': \(fmt.string(from: time))")
        debugLog("  │ Input 'on date': \(fmt.string(from: date))")
        debugLog("  │ Duration: \(duration) min")
        debugLog("  │ Current time (now): \(fmt.string(from: now))")

        // Helper to ensure candidateTime is not in the past
        func ensureNotInPast() {
            if candidateTime < now {
                debugLog("  │ ⚠️ candidateTime \(fmt.string(from: candidateTime)) is in PAST")
                let minutes = calendar.component(.minute, from: now)
                let roundedMinutes = ((minutes / 15) + 1) * 15
                var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
                if roundedMinutes >= 60 {
                    components.hour = (components.hour ?? 0) + 1
                    components.minute = 0
                } else {
                    components.minute = roundedMinutes
                }
                candidateTime = calendar.date(from: components) ?? now
                debugLog("  │ ✓ Adjusted to: \(fmt.string(from: candidateTime))")
            }
        }

        // ALWAYS check if candidate is in the past first
        ensureNotInPast()

        // Don't schedule before 6 AM
        if candidateTime.hour < minHour {
            debugLog("  │ Hour \(candidateTime.hour) < minHour \(minHour), setting to 6 AM")
            candidateTime = date.startOfDay.withTime(hour: minHour)
            debugLog("  │ Set to: \(fmt.string(from: candidateTime))")
            // Re-check for past time!
            ensureNotInPast()
        }

        // Check sleep blocking
        if let sleepRange = sleepManager?.getSleepBlockedRange(for: candidateTime) {
            if candidateTime >= sleepRange.bufferStart && candidateTime < sleepRange.wakeTime {
                debugLog("  │ In sleep time, jumping to wake: \(fmt.string(from: sleepRange.wakeTime))")
                candidateTime = sleepRange.wakeTime
                ensureNotInPast()
            }
        }

        // Get items for the same day, excluding the ones we're moving
        // Also exclude items that have already ended (they're in the past)
        let excludeIds = Set(excluding.map { $0.id })
        let dayItems = allItems
            .filter { item in
                item.scheduledDate.isSameDay(as: date) &&
                !excludeIds.contains(item.id) &&
                !item.isCompleted &&
                item.endTime > now  // Only consider items that haven't ended
            }
            .sorted { $0.startTime < $1.startTime }

        debugLog("  │ Day items to check (\(dayItems.count)):")
        for item in dayItems {
            debugLog("  │   - \(item.title): \(fmt.string(from: item.startTime)) - \(fmt.string(from: item.endTime))")
        }

        // Try to find a slot
        var iteration = 0
        var foundValidSlot = false

        while iteration < 100 && !foundValidSlot {
            iteration += 1
            let candidateEnd = calendar.date(byAdding: .minute, value: duration, to: candidateTime) ?? candidateTime

            debugLog("  │ Iteration \(iteration): Trying \(fmt.string(from: candidateTime)) - \(fmt.string(from: candidateEnd))")

            // Find ALL conflicts and get the latest end time
            var latestConflictEnd: Date? = nil
            for item in dayItems {
                let overlaps = candidateTime < item.endTime && candidateEnd > item.startTime
                if overlaps {
                    debugLog("  │   CONFLICT with \(item.title)")
                    if latestConflictEnd == nil || item.endTime > latestConflictEnd! {
                        latestConflictEnd = item.endTime
                    }
                }
            }

            if let latestEnd = latestConflictEnd {
                debugLog("  │   Moving past all conflicts to: \(fmt.string(from: latestEnd))")
                candidateTime = latestEnd
                ensureNotInPast()
            } else {
                // No conflicts - verify the slot is truly free
                let finalEnd = calendar.date(byAdding: .minute, value: duration, to: candidateTime) ?? candidateTime
                let stillHasConflict = dayItems.contains { item in
                    candidateTime < item.endTime && finalEnd > item.startTime
                }
                if !stillHasConflict {
                    debugLog("  │ ✓ FOUND free slot: \(fmt.string(from: candidateTime))")
                    foundValidSlot = true
                }
            }

            // If we've moved to next day, search that day properly
            if !foundValidSlot && !candidateTime.isSameDay(as: date) {
                debugLog("  │ Moved to next day, searching next day...")
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                    // Recursively search the next day (up to 7 days out to prevent infinite recursion)
                    let daysDiff = calendar.dateComponents([.day], from: date, to: nextDay).day ?? 1
                    if daysDiff <= 7 {
                        return findNextAvailableSlot(
                            after: nextDay.startOfDay.withTime(hour: minHour),
                            duration: duration,
                            on: nextDay,
                            allItems: allItems,
                            excluding: excluding
                        )
                    }
                }
                break
            }
        }

        // FINAL SAFETY: Never return a past time
        if candidateTime < now {
            debugLog("  │ 🚨 FINAL SAFETY: Still in past!")
            let minutes = calendar.component(.minute, from: now)
            let roundedMinutes = ((minutes / 15) + 1) * 15
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            if roundedMinutes >= 60 {
                components.hour = (components.hour ?? 0) + 1
                components.minute = 0
            } else {
                components.minute = roundedMinutes
            }
            candidateTime = calendar.date(from: components) ?? now
            debugLog("  │ ✓ FINAL adjusted to: \(fmt.string(from: candidateTime))")
        }

        debugLog("  └─ RETURNING: \(fmt.string(from: candidateTime))")
        return candidateTime
    }
}

// MARK: - Conflict Resolution Model

struct ConflictResolution: Identifiable {
    let id = UUID()
    let conflictingItem: ScheduleItem
    let newItem: ScheduleItem
    let suggestion: Suggestion
    let reason: String

    enum Suggestion {
        case moveConflicting(to: Date)
        case moveNew(to: Date)
        case userDecision(moveConflictingTo: Date, moveNewTo: Date)
    }
}
