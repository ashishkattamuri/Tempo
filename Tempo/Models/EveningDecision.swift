import Foundation

/// Result of evening protection analysis based on the 10-case decision table.
/// Evening is sacred - these decisions protect the user's wind-down time.
struct EveningDecision: Equatable, Hashable {
    /// The case number from the decision table (1-10)
    let caseNumber: Int

    /// Description of what was detected
    let situation: String

    /// The recommended action
    let recommendation: Recommendation

    /// Whether user consent is required
    let requiresConsent: Bool

    /// Items affected by this decision
    let affectedItems: [ScheduleItem]

    /// The type of recommendation for evening protection
    enum Recommendation: Equatable, Hashable {
        /// Evening remains untouched
        case keepFree

        /// Only gentle/low-energy tasks can flow into evening
        case allowGentleOnly

        /// User chose to make evening lighter
        case makeLighter(removedItems: [UUID])

        /// User explicitly allowed evening tasks
        case userAllowed

        /// Preserve at least 50% evening slack
        case preserveSlack(minimumFreeMinutes: Int)

        var displayName: String {
            switch self {
            case .keepFree:
                return "Evening Protected"
            case .allowGentleOnly:
                return "Gentle Tasks Only"
            case .makeLighter:
                return "Evening Made Lighter"
            case .userAllowed:
                return "User Approved"
            case .preserveSlack:
                return "Slack Preserved"
            }
        }
    }

    // MARK: - The 10 Evening Protection Cases

    /// Case 1: Evening is empty and user wants it free
    static func case1_eveningEmpty() -> EveningDecision {
        EveningDecision(
            caseNumber: 1,
            situation: "Evening is currently free",
            recommendation: .keepFree,
            requiresConsent: false,
            affectedItems: []
        )
    }

    /// Case 2: Evening has gentle tasks only
    static func case2_gentleTasksOnly(tasks: [ScheduleItem]) -> EveningDecision {
        EveningDecision(
            caseNumber: 2,
            situation: "Evening has \(tasks.count) gentle task(s)",
            recommendation: .allowGentleOnly,
            requiresConsent: false,
            affectedItems: tasks
        )
    }

    /// Case 3: Evening has high-energy tasks that could be moved
    static func case3_highEnergyTasks(tasks: [ScheduleItem]) -> EveningDecision {
        EveningDecision(
            caseNumber: 3,
            situation: "Evening has \(tasks.count) high-energy task(s) that could be moved earlier",
            recommendation: .makeLighter(removedItems: tasks.map { $0.id }),
            requiresConsent: true,
            affectedItems: tasks
        )
    }

    /// Case 4: Overflow would push tasks into evening
    static func case4_overflowDetected(overflowMinutes: Int) -> EveningDecision {
        EveningDecision(
            caseNumber: 4,
            situation: "Schedule overflow of \(overflowMinutes) min would affect evening",
            recommendation: .keepFree,
            requiresConsent: true,
            affectedItems: []
        )
    }

    /// Case 5: User has evening non-negotiable
    static func case5_eveningNonNegotiable(task: ScheduleItem) -> EveningDecision {
        EveningDecision(
            caseNumber: 5,
            situation: "Evening has non-negotiable: \(task.title)",
            recommendation: .userAllowed,
            requiresConsent: false,
            affectedItems: [task]
        )
    }

    /// Case 6: Evening identity habit (gentle)
    static func case6_gentleIdentityHabit(task: ScheduleItem) -> EveningDecision {
        EveningDecision(
            caseNumber: 6,
            situation: "Evening identity habit: \(task.title)",
            recommendation: .allowGentleOnly,
            requiresConsent: false,
            affectedItems: [task]
        )
    }

    /// Case 7: Evening identity habit (high-energy) - needs consent to move
    static func case7_highEnergyIdentityHabit(task: ScheduleItem) -> EveningDecision {
        EveningDecision(
            caseNumber: 7,
            situation: "High-energy evening habit: \(task.title)",
            recommendation: .allowGentleOnly,
            requiresConsent: true,
            affectedItems: [task]
        )
    }

    /// Case 8: Evening slack is being consumed
    static func case8_slackConsumed(currentFreeMinutes: Int, minimumRequired: Int) -> EveningDecision {
        EveningDecision(
            caseNumber: 8,
            situation: "Evening slack reduced to \(currentFreeMinutes) min (need \(minimumRequired) min)",
            recommendation: .preserveSlack(minimumFreeMinutes: minimumRequired),
            requiresConsent: true,
            affectedItems: []
        )
    }

    /// Case 9: User explicitly chose to work in evening
    static func case9_userChoseEvening(tasks: [ScheduleItem]) -> EveningDecision {
        EveningDecision(
            caseNumber: 9,
            situation: "User scheduled \(tasks.count) evening task(s)",
            recommendation: .userAllowed,
            requiresConsent: false,
            affectedItems: tasks
        )
    }

    /// Case 10: Full day disruption - protect at least one evening habit
    static func case10_fullDayDisruption(protectedHabit: ScheduleItem?) -> EveningDecision {
        let situation: String
        if let habit = protectedHabit {
            situation = "Full day disruption - protecting evening habit: \(habit.title)"
        } else {
            situation = "Full day disruption - evening kept free"
        }
        return EveningDecision(
            caseNumber: 10,
            situation: situation,
            recommendation: protectedHabit != nil ? .allowGentleOnly : .keepFree,
            requiresConsent: false,
            affectedItems: protectedHabit.map { [$0] } ?? []
        )
    }
}

// MARK: - Display Helpers

extension EveningDecision {
    /// User-friendly message about this decision
    var message: String {
        switch recommendation {
        case .keepFree:
            return "Your evening is protected and will remain free."
        case .allowGentleOnly:
            return "Only gentle, low-energy activities in your evening."
        case .makeLighter:
            return "Would you like to move high-energy tasks out of your evening?"
        case .userAllowed:
            return "Evening tasks are scheduled as you requested."
        case .preserveSlack(let minutes):
            return "Keeping at least \(minutes) minutes of evening free time."
        }
    }

    /// Icon for this decision
    var iconName: String {
        switch recommendation {
        case .keepFree:
            return "moon.fill"
        case .allowGentleOnly:
            return "leaf.fill"
        case .makeLighter:
            return "sun.and.horizon"
        case .userAllowed:
            return "checkmark.circle.fill"
        case .preserveSlack:
            return "clock.fill"
        }
    }
}
