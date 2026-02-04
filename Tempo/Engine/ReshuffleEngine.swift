import Foundation

/// Main coordinator for schedule reshuffling.
/// Implements the 9-step decision process to compassionately adjust schedules.
@MainActor
final class ReshuffleEngine {
    private let overflowDetector = OverflowDetector()
    private let eveningAnalyzer = EveningProtectionAnalyzer()
    private let summaryGenerator = SummaryGenerator()

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

        for conflicting in conflictingItems {
            let resolution: ConflictResolution

            // Find best slot to move the conflicting item (after new item ends)
            let slotForConflicting = findNextAvailableSlot(
                after: newItem.endTime,
                duration: conflicting.durationMinutes,
                on: conflicting.scheduledDate,
                allItems: allItems,
                excluding: [newItem, conflicting]
            )

            // Find best slot to move the new item (after conflicting ends)
            let slotForNew = findNextAvailableSlot(
                after: conflicting.endTime,
                duration: newItem.durationMinutes,
                on: newItem.scheduledDate,
                allItems: allItems,
                excluding: [newItem, conflicting]
            )

            // If the new item is non-negotiable, always give the user the choice
            if newItem.category == .nonNegotiable {
                resolution = ConflictResolution(
                    conflictingItem: conflicting,
                    newItem: newItem,
                    suggestion: .userDecision(moveConflictingTo: slotForConflicting, moveNewTo: slotForNew),
                    reason: "\"\(newItem.title)\" is non-negotiable and conflicts with \"\(conflicting.title)\""
                )
            } else if newItem.category.priority < conflicting.category.priority {
                // New item has higher priority - suggest moving the conflicting item
                resolution = ConflictResolution(
                    conflictingItem: conflicting,
                    newItem: newItem,
                    suggestion: .moveConflicting(to: slotForConflicting),
                    reason: "\"\(newItem.title)\" (\(newItem.category.displayName)) has higher priority than \"\(conflicting.title)\" (\(conflicting.category.displayName))"
                )
            } else if newItem.category.priority > conflicting.category.priority {
                // Existing item has higher priority - suggest moving the new item
                resolution = ConflictResolution(
                    conflictingItem: conflicting,
                    newItem: newItem,
                    suggestion: .moveNew(to: slotForNew),
                    reason: "\"\(conflicting.title)\" (\(conflicting.category.displayName)) has higher priority"
                )
            } else {
                // Same priority - let user decide
                resolution = ConflictResolution(
                    conflictingItem: conflicting,
                    newItem: newItem,
                    suggestion: .userDecision(moveConflictingTo: slotForConflicting, moveNewTo: slotForNew),
                    reason: "Both tasks have the same priority level"
                )
            }

            resolutions.append(resolution)
        }

        return resolutions
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
        let maxHour = 22
        let now = Date()

        // Start from the given time
        var candidateTime = time

        // Don't schedule in the past (for today)
        if date.isToday && candidateTime < now {
            // Round up to next 15-minute interval
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

        // Don't schedule before 6 AM
        if candidateTime.hour < minHour {
            candidateTime = date.startOfDay.withTime(hour: minHour)
        }

        // Get items for the same day, excluding the ones we're moving
        let excludeIds = Set(excluding.map { $0.id })
        let dayItems = allItems
            .filter { $0.scheduledDate.isSameDay(as: date) && !excludeIds.contains($0.id) && !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }

        // Try to find a slot that doesn't overlap with any existing item
        let candidateEnd = calendar.date(byAdding: .minute, value: duration, to: candidateTime) ?? candidateTime

        for _ in 0..<50 { // Max iterations to prevent infinite loop
            var hasConflict = false

            for item in dayItems {
                // Check if candidate overlaps with this item
                if candidateTime < item.endTime && candidateEnd > item.startTime {
                    // Conflict found - move candidate to after this item
                    candidateTime = item.endTime
                    hasConflict = true
                    break
                }
            }

            if !hasConflict {
                break
            }

            // Check if we've gone past end of day
            if candidateTime.hour >= maxHour {
                // Move to next day
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                    return nextDay.startOfDay.withTime(hour: minHour)
                }
                break
            }
        }

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
