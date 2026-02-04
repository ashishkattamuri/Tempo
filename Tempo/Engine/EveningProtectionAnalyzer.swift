import Foundation

/// Analyzes and protects evening time using the 10-case decision table.
/// Evening is sacred - this analyzer ensures user consent before any changes.
struct EveningProtectionAnalyzer {

    /// Analyze evening protection needs and return the appropriate decision.
    func analyze(
        items: [ScheduleItem],
        for date: Date,
        overflowAnalysis: OverflowDetector.OverflowAnalysis
    ) -> EveningDecision {
        let eveningItems = items.filter { $0.isEveningTask && !$0.isCompleted }
        let eveningStart = date.eveningStart
        let eveningEnd = date.eveningEnd

        // Calculate evening metrics
        let scheduledEveningMinutes = eveningItems.reduce(0) { $0 + $1.durationMinutes }
        let totalEveningMinutes = Constants.eveningDurationMinutes
        let freeEveningMinutes = totalEveningMinutes - scheduledEveningMinutes

        // Categorize evening items
        let nonNegotiables = eveningItems.filter { $0.category == .nonNegotiable }
        let identityHabits = eveningItems.filter { $0.category == .identityHabit }
        let gentleHabits = identityHabits.filter { $0.isGentleTask }
        let highEnergyHabits = identityHabits.filter { !$0.isGentleTask }
        let otherTasks = eveningItems.filter {
            $0.category != .nonNegotiable && $0.category != .identityHabit
        }

        // Apply the 10-case decision table
        return determineCase(
            eveningItems: eveningItems,
            nonNegotiables: nonNegotiables,
            gentleHabits: gentleHabits,
            highEnergyHabits: highEnergyHabits,
            otherTasks: otherTasks,
            freeMinutes: freeEveningMinutes,
            overflowAnalysis: overflowAnalysis
        )
    }

    // MARK: - The 10 Cases

    private func determineCase(
        eveningItems: [ScheduleItem],
        nonNegotiables: [ScheduleItem],
        gentleHabits: [ScheduleItem],
        highEnergyHabits: [ScheduleItem],
        otherTasks: [ScheduleItem],
        freeMinutes: Int,
        overflowAnalysis: OverflowDetector.OverflowAnalysis
    ) -> EveningDecision {
        let identityHabits = gentleHabits + highEnergyHabits

        // Case 1: Evening is empty
        if eveningItems.isEmpty {
            // Check if overflow would spill into evening
            if overflowAnalysis.spillsIntoEvening {
                return EveningDecision.case4_overflowDetected(
                    overflowMinutes: overflowAnalysis.eveningSpillMinutes
                )
            }
            return EveningDecision.case1_eveningEmpty()
        }

        // Case 5: Evening has non-negotiable
        if let nonNeg = nonNegotiables.first {
            return EveningDecision.case5_eveningNonNegotiable(task: nonNeg)
        }

        // Case 6: Evening has gentle identity habit only
        if !gentleHabits.isEmpty && highEnergyHabits.isEmpty && otherTasks.isEmpty {
            return EveningDecision.case6_gentleIdentityHabit(task: gentleHabits[0])
        }

        // Case 7: Evening has high-energy identity habit
        if let highEnergy = highEnergyHabits.first {
            return EveningDecision.case7_highEnergyIdentityHabit(task: highEnergy)
        }

        // Case 2: Evening has only gentle tasks
        let allGentleOrLowPriority = eveningItems.allSatisfy { item in
            item.isGentleTask || item.category == .optionalGoal
        }
        if allGentleOrLowPriority {
            return EveningDecision.case2_gentleTasksOnly(tasks: eveningItems)
        }

        // Case 3: Evening has high-energy tasks that could be moved
        let highEnergyTasks = eveningItems.filter { !$0.isGentleTask && $0.category != .optionalGoal }
        if !highEnergyTasks.isEmpty {
            return EveningDecision.case3_highEnergyTasks(tasks: highEnergyTasks)
        }

        // Case 4: Overflow would push into evening
        if overflowAnalysis.spillsIntoEvening {
            return EveningDecision.case4_overflowDetected(
                overflowMinutes: overflowAnalysis.eveningSpillMinutes
            )
        }

        // Case 8: Evening slack is being consumed (less than 50% free)
        let minimumFree = Constants.minimumEveningFreeMinutes
        if freeMinutes < minimumFree {
            return EveningDecision.case8_slackConsumed(
                currentFreeMinutes: freeMinutes,
                minimumRequired: minimumFree
            )
        }

        // Case 9: User explicitly scheduled evening tasks
        if !eveningItems.isEmpty {
            return EveningDecision.case9_userChoseEvening(tasks: eveningItems)
        }

        // Case 10: Full day disruption - fall back
        if case .fullDayDisruption = overflowAnalysis.suggestedStrategy {
            let protectedHabit = gentleHabits.first ?? identityHabits.first
            return EveningDecision.case10_fullDayDisruption(protectedHabit: protectedHabit)
        }

        // Default: evening is protected
        return EveningDecision.case1_eveningEmpty()
    }

    // MARK: - Helper Methods

    /// Check if an item can safely flow into evening
    func canFlowIntoEvening(_ item: ScheduleItem) -> Bool {
        // Only gentle/low-energy tasks can flow into evening
        if item.isGentleTask {
            return true
        }

        // Optional goals are low priority and can flow
        if item.category == .optionalGoal {
            return true
        }

        return false
    }

    /// Calculate how much evening slack would remain after adding items
    func remainingSlack(
        currentFreeMinutes: Int,
        addingMinutes: Int
    ) -> Int {
        return currentFreeMinutes - addingMinutes
    }

    /// Check if adding minutes to evening would violate the 50% slack rule
    func wouldViolateSlackRule(
        currentFreeMinutes: Int,
        addingMinutes: Int
    ) -> Bool {
        let remaining = remainingSlack(currentFreeMinutes: currentFreeMinutes, addingMinutes: addingMinutes)
        return remaining < Constants.minimumEveningFreeMinutes
    }
}
