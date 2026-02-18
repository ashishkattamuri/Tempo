import Foundation

/// Processor for identity habits.
/// These are habits that define who the user is.
/// Core principle: Compress but NEVER remove.
/// "Showing up in any form counts."
///
/// Handling based on frequency:
/// - Daily habits: Can only compress or skip, NEVER move (next day has it too)
/// - Weekly (X times/week) habits: Can move to next day IF that day doesn't have the same habit
struct IdentityHabitProcessor: CategoryProcessor {
    let category: TaskCategory = .identityHabit

    func process(item: ScheduleItem, context: ReshuffleContext) -> Change {
        // If no overflow, protect the habit at full duration
        if !context.hasOverflow {
            return Change(
                item: item,
                action: .protected,
                reason: "Your identity habit is protected at full duration"
            )
        }

        // Calculate how much compression is needed
        let compressionNeeded = calculateCompressionNeeded(for: item, in: context)

        if compressionNeeded == 0 {
            // Other items can absorb the overflow
            return Change(
                item: item,
                action: .protected,
                reason: "Protected - other items were adjusted instead"
            )
        }

        // Check if this habit can be compressed
        if item.isCompressible {
            let newDuration = calculateCompressedDuration(
                for: item,
                compressionNeeded: compressionNeeded
            )

            // For DAILY habits: never move, only compress in place
            if item.isDaily {
                return Change(
                    item: item,
                    action: .resized(newDurationMinutes: newDuration),
                    reason: dailyHabitMessage(savedMinutes: item.durationMinutes - newDuration)
                )
            }

            // For WEEKLY habits: try to find a better slot on a day without this habit
            if item.isWeekly {
                if let newSlot = findWeeklyHabitSlot(for: item, newDuration: newDuration, in: context) {
                    return Change(
                        item: item,
                        action: .movedAndResized(newStartTime: newSlot, newDurationMinutes: newDuration),
                        reason: weeklyHabitMoveMessage(savedMinutes: item.durationMinutes - newDuration)
                    )
                }
                // Cannot move - compress in place
                return Change(
                    item: item,
                    action: .resized(newDurationMinutes: newDuration),
                    reason: weeklyHabitCompressMessage(savedMinutes: item.durationMinutes - newDuration)
                )
            }

            // Check if we need to move it (non-recurring habits)
            if let newStartTime = findBetterSlot(for: item, newDuration: newDuration, in: context) {
                return Change(
                    item: item,
                    action: .movedAndResized(newStartTime: newStartTime, newDurationMinutes: newDuration),
                    reason: compassionateMessage(savedMinutes: item.durationMinutes - newDuration)
                )
            }

            return Change(
                item: item,
                action: .resized(newDurationMinutes: newDuration),
                reason: compassionateMessage(savedMinutes: item.durationMinutes - newDuration)
            )
        }

        // Cannot compress - handle based on frequency
        if item.isDaily {
            // Daily habits that can't compress: protect them (user must decide to skip)
            return Change(
                item: item,
                action: .protected,
                reason: "Daily habit protected - consider skipping today if needed"
            )
        }

        if item.isWeekly {
            // Weekly habits: try to move to a day without this habit
            if let newSlot = findWeeklyHabitSlot(for: item, newDuration: item.durationMinutes, in: context) {
                return Change(
                    item: item,
                    action: .moved(newStartTime: newSlot),
                    reason: "Moved to a day when you don't have this habit scheduled"
                )
            }
            // Cannot move - protect it
            return Change(
                item: item,
                action: .protected,
                reason: "Weekly habit protected - same habit scheduled on nearby days"
            )
        }

        // Non-recurring habit - try to move
        if let newSlot = context.findSlot(forDurationMinutes: item.durationMinutes) {
            return Change(
                item: item,
                action: .moved(newStartTime: newSlot.start),
                reason: "Moved to fit your adjusted schedule"
            )
        }

        // As a last resort, protect it anyway - identity habits are never removed
        return Change(
            item: item,
            action: .protected,
            reason: "Your identity habit is protected - it defines who you are"
        )
    }

    // MARK: - Private

    private func calculateCompressionNeeded(for item: ScheduleItem, in context: ReshuffleContext) -> Int {
        // First, calculate if optional goals can absorb the overflow
        let afterOptionalGoals = context.overflowMinutes - context.optionalGoalMinutes

        if afterOptionalGoals <= 0 {
            // Optional goals can absorb all overflow
            return 0
        }

        // Calculate fair share of compression among identity habits
        let totalCompressible = context.maxCompressionMinutes
        if totalCompressible == 0 { return 0 }

        let itemShare = Double(item.compressibleMinutes) / Double(totalCompressible)
        return Int(Double(afterOptionalGoals) * itemShare)
    }

    private func calculateCompressedDuration(for item: ScheduleItem, compressionNeeded: Int) -> Int {
        guard let minDuration = item.minimumDurationMinutes else {
            return item.durationMinutes
        }

        // Never compress below minimum
        let compressed = item.durationMinutes - compressionNeeded
        return max(minDuration, compressed)
    }

    private func findBetterSlot(
        for item: ScheduleItem,
        newDuration: Int,
        in context: ReshuffleContext
    ) -> Date? {
        // Check if current slot would have conflicts
        let currentSlotWorks = context.isSlotAvailable(
            start: item.startTime,
            durationMinutes: newDuration
        )

        if currentSlotWorks {
            return nil // Keep current time
        }

        // Find a new slot
        return context.findSlot(forDurationMinutes: newDuration)?.start
    }

    /// For weekly habits, find a slot on a day that doesn't already have this habit scheduled
    private func findWeeklyHabitSlot(
        for item: ScheduleItem,
        newDuration: Int,
        in context: ReshuffleContext
    ) -> Date? {
        let calendar = Calendar.current

        // Check the next few days (within the same week)
        for dayOffset in 1...6 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: item.scheduledDate) else {
                continue
            }

            // Check if this day of week is in the recurrence schedule
            let targetWeekday = calendar.component(.weekday, from: targetDate) - 1 // 0-indexed
            if item.recurrenceDays.contains(targetWeekday) {
                // This day already has this habit scheduled, skip it
                continue
            }

            // Check if we're still in the same week (don't defer to next week)
            let itemWeek = calendar.component(.weekOfYear, from: item.scheduledDate)
            let targetWeek = calendar.component(.weekOfYear, from: targetDate)
            if targetWeek != itemWeek {
                break // Don't move to next week
            }

            // Try to find a slot on this day
            if let slot = context.findSlot(forDurationMinutes: newDuration, on: targetDate) {
                return slot.start
            }
        }

        return nil
    }

    // MARK: - Messages

    private func compassionateMessage(savedMinutes: Int) -> String {
        if savedMinutes <= 5 {
            return "Slightly adjusted, but you're still showing up"
        } else if savedMinutes <= 15 {
            return "Adjusted to \(savedMinutes) minutes shorter - showing up in any form counts"
        } else {
            return "Compressed to save \(savedMinutes) min - your commitment is what matters"
        }
    }

    private func dailyHabitMessage(savedMinutes: Int) -> String {
        if savedMinutes <= 5 {
            return "Daily habit adjusted slightly - you're still showing up"
        } else if savedMinutes <= 15 {
            return "Daily habit compressed \(savedMinutes) min - showing up every day counts"
        } else {
            return "Daily habit compressed \(savedMinutes) min - consistency over perfection"
        }
    }

    private func weeklyHabitMoveMessage(savedMinutes: Int) -> String {
        if savedMinutes <= 5 {
            return "Moved to another day this week - still counts toward your weekly goal"
        } else {
            return "Moved and adjusted \(savedMinutes) min - still on track for the week"
        }
    }

    private func weeklyHabitCompressMessage(savedMinutes: Int) -> String {
        if savedMinutes <= 5 {
            return "Weekly habit adjusted - keeping you on track"
        } else {
            return "Weekly habit compressed \(savedMinutes) min - every bit counts"
        }
    }
}
