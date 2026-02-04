import Foundation

/// Processor for flexible tasks.
/// These are important tasks that can be moved to different time slots
/// or pooled for later scheduling.
struct FlexibleTaskProcessor: CategoryProcessor {
    let category: TaskCategory = .flexibleTask

    func process(item: ScheduleItem, context: ReshuffleContext) -> Change {
        // If no overflow and no conflicts, keep as is
        if !context.hasOverflow && !hasConflicts(item, in: context) {
            return Change(
                item: item,
                action: .protected,
                reason: "Flexible task stays in place - schedule allows it"
            )
        }

        // Check if we should defer to another day
        if shouldDefer(item, in: context) {
            let tomorrow = context.targetDate.addingDays(1)
            let newStartTime = tomorrow.withTime(hour: item.startTime.hour, minute: item.startTime.minute)
            return Change(
                item: item,
                action: .deferred(newDate: newStartTime),
                reason: "Deferred to tomorrow - today's priorities come first"
            )
        }

        // Try to find a new slot today
        if let newSlot = findBestSlot(for: item, in: context) {
            return Change(
                item: item,
                action: .moved(newStartTime: newSlot.start),
                reason: "Moved to fit your adjusted schedule"
            )
        }

        // Add to flexible pool for later
        if context.hasOverflow {
            return Change(
                item: item,
                action: .pooled,
                reason: "Added to flexible pool - will be scheduled when time opens up"
            )
        }

        // Default: protect it
        return Change(
            item: item,
            action: .protected,
            reason: "Flexible task protected"
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

    private func shouldDefer(_ item: ScheduleItem, in context: ReshuffleContext) -> Bool {
        // Defer if:
        // 1. There's significant overflow even after compression
        // 2. And optional goals have already been dropped
        // 3. And identity habits are at minimum

        let remainingOverflow = context.overflowMinutes
            - context.optionalGoalMinutes
            - context.maxCompressionMinutes

        // If still overflow after all other adjustments, flexible tasks get deferred
        if remainingOverflow > 0 {
            // Defer tasks by lowest priority within flexible category
            // For now, defer if there's still overflow
            return true
        }

        return false
    }

    private func findBestSlot(
        for item: ScheduleItem,
        in context: ReshuffleContext
    ) -> TimeCalculations.TimeSlot? {
        // Priority order for finding slots:
        // 1. Same general time of day (morning -> morning, afternoon -> afternoon)
        // 2. Any available slot before evening
        // 3. Evening only if user has approved

        let preferredHour = item.startTime.hour

        // Try to find a slot near the original time
        for slot in context.availableSlots {
            if slot.durationMinutes >= item.durationMinutes {
                let slotHour = slot.start.hour
                // Within 2 hours of original time
                if abs(slotHour - preferredHour) <= 2 {
                    return slot
                }
            }
        }

        // Fall back to any available slot
        return context.findSlot(forDurationMinutes: item.durationMinutes)
    }
}
