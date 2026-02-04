import Foundation

/// Processor for optional goals.
/// These are nice-to-have tasks that are the first to be deferred on hard days.
/// No guilt, no penalty - they simply wait for a better day.
struct OptionalGoalProcessor: CategoryProcessor {
    let category: TaskCategory = .optionalGoal

    func process(item: ScheduleItem, context: ReshuffleContext) -> Change {
        // If no overflow, keep the optional goal
        if !context.hasOverflow {
            if hasConflicts(item, in: context) {
                // Try to move it
                if let newSlot = context.findSlot(forDurationMinutes: item.durationMinutes) {
                    return Change(
                        item: item,
                        action: .moved(newStartTime: newSlot.start),
                        reason: "Moved to avoid schedule conflict"
                    )
                }
            }

            return Change(
                item: item,
                action: .protected,
                reason: "Optional goal fits in today's schedule"
            )
        }

        // There's overflow - optional goals are first to be deferred
        // Calculate if we need to defer this specific item

        let overflowBeforeThisItem = calculateOverflowBeforeThisItem(item, in: context)

        if overflowBeforeThisItem > 0 {
            // This item needs to be deferred
            let tomorrow = context.targetDate.addingDays(1)
            let newStartTime = tomorrow.withTime(hour: item.startTime.hour, minute: item.startTime.minute)

            return Change(
                item: item,
                action: .deferred(newDate: newStartTime),
                reason: "Deferred to tomorrow - today's priorities come first. This can wait."
            )
        }

        // Overflow can be handled by other optional goals or compression
        return Change(
            item: item,
            action: .protected,
            reason: "Optional goal kept - higher priority items were adjusted"
        )
    }

    // MARK: - Private

    private func hasConflicts(_ item: ScheduleItem, in context: ReshuffleContext) -> Bool {
        context.allItems.contains { other in
            other.id != item.id &&
            item.overlaps(with: other) &&
            !other.isCompleted
        }
    }

    private func calculateOverflowBeforeThisItem(_ item: ScheduleItem, in context: ReshuffleContext) -> Int {
        // Get all optional goals sorted by start time
        let sortedOptionals = context.optionalGoals.sorted { $0.startTime < $1.startTime }

        // Calculate cumulative minutes of optional goals before this one
        var minutesBefore = 0
        for optional in sortedOptionals {
            if optional.id == item.id {
                break
            }
            minutesBefore += optional.durationMinutes
        }

        // Check if previous optional goals have absorbed enough overflow
        let remainingOverflow = context.overflowMinutes - minutesBefore

        return max(0, remainingOverflow)
    }
}
