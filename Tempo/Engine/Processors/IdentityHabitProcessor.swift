import Foundation

/// Processor for identity habits.
/// These are habits that define who the user is.
/// Core principle: Compress but NEVER remove.
/// "Showing up in any form counts."
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

            // Check if we need to move it too
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

        // Cannot compress - try to move to a better slot
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

    private func compassionateMessage(savedMinutes: Int) -> String {
        if savedMinutes <= 5 {
            return "Slightly adjusted, but you're still showing up"
        } else if savedMinutes <= 15 {
            return "Adjusted to \(savedMinutes) minutes shorter - showing up in any form counts"
        } else {
            return "Compressed to save \(savedMinutes) min - your commitment is what matters"
        }
    }
}
