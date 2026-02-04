import Foundation

/// Detects and analyzes time overflow situations.
/// Overflow occurs when remaining tasks need more time than available.
struct OverflowDetector {
    /// Result of overflow analysis
    struct OverflowAnalysis {
        /// Total minutes of overflow (0 if no overflow)
        let overflowMinutes: Int

        /// Whether overflow would spill into evening
        let spillsIntoEvening: Bool

        /// Minutes that would spill into evening
        let eveningSpillMinutes: Int

        /// Suggested strategy to handle overflow
        let suggestedStrategy: Strategy

        /// Whether there's any overflow
        var hasOverflow: Bool {
            overflowMinutes > 0
        }

        /// Strategy for handling overflow
        enum Strategy {
            /// No overflow - schedule is fine
            case noAction

            /// Can be handled by compressing identity habits
            case compressHabits(minutesNeeded: Int)

            /// Need to defer optional goals
            case deferOptionals(count: Int)

            /// Need to defer flexible tasks too
            case deferFlexible(count: Int)

            /// Full day disruption - protect one identity habit only
            case fullDayDisruption

            var description: String {
                switch self {
                case .noAction:
                    return "Schedule looks good"
                case .compressHabits(let minutes):
                    return "Compress habits by \(minutes) min"
                case .deferOptionals(let count):
                    return "Defer \(count) optional goal(s)"
                case .deferFlexible(let count):
                    return "Defer \(count) flexible task(s)"
                case .fullDayDisruption:
                    return "Major disruption - protect one habit"
                }
            }
        }
    }

    /// Analyze overflow for a given context
    func analyze(context: ReshuffleContext) -> OverflowAnalysis {
        // No overflow case
        if !context.hasOverflow {
            return OverflowAnalysis(
                overflowMinutes: 0,
                spillsIntoEvening: false,
                eveningSpillMinutes: 0,
                suggestedStrategy: .noAction
            )
        }

        let overflow = context.overflowMinutes

        // Check if optional goals can absorb the overflow
        if context.optionalGoalMinutes >= overflow {
            let optionalsToDefer = calculateOptionalsToDeferCount(
                overflowMinutes: overflow,
                optionals: context.optionalGoals
            )
            return OverflowAnalysis(
                overflowMinutes: overflow,
                spillsIntoEvening: false,
                eveningSpillMinutes: 0,
                suggestedStrategy: .deferOptionals(count: optionalsToDefer)
            )
        }

        // After deferring optional goals, check compression
        let remainingAfterOptionals = overflow - context.optionalGoalMinutes

        if context.maxCompressionMinutes >= remainingAfterOptionals {
            return OverflowAnalysis(
                overflowMinutes: overflow,
                spillsIntoEvening: false,
                eveningSpillMinutes: 0,
                suggestedStrategy: .compressHabits(minutesNeeded: remainingAfterOptionals)
            )
        }

        // Need to defer flexible tasks too
        let remainingAfterCompression = remainingAfterOptionals - context.maxCompressionMinutes

        let flexibleMinutes = context.flexibleTasks.reduce(0) { $0 + $1.durationMinutes }

        if flexibleMinutes >= remainingAfterCompression {
            let flexibleToDefer = calculateFlexibleToDeferCount(
                overflowMinutes: remainingAfterCompression,
                flexible: context.flexibleTasks
            )
            return OverflowAnalysis(
                overflowMinutes: overflow,
                spillsIntoEvening: false,
                eveningSpillMinutes: 0,
                suggestedStrategy: .deferFlexible(count: flexibleToDefer)
            )
        }

        // Full day disruption - can't fit everything
        let spillover = remainingAfterCompression - flexibleMinutes
        return OverflowAnalysis(
            overflowMinutes: overflow,
            spillsIntoEvening: spillover > 0,
            eveningSpillMinutes: spillover,
            suggestedStrategy: .fullDayDisruption
        )
    }

    // MARK: - Private

    private func calculateOptionalsToDeferCount(
        overflowMinutes: Int,
        optionals: [ScheduleItem]
    ) -> Int {
        // Sort by start time (defer later ones first)
        let sorted = optionals.sorted { $0.startTime > $1.startTime }

        var minutesCovered = 0
        var count = 0

        for item in sorted {
            if minutesCovered >= overflowMinutes {
                break
            }
            minutesCovered += item.durationMinutes
            count += 1
        }

        return count
    }

    private func calculateFlexibleToDeferCount(
        overflowMinutes: Int,
        flexible: [ScheduleItem]
    ) -> Int {
        // Sort by start time (defer later ones first)
        let sorted = flexible.sorted { $0.startTime > $1.startTime }

        var minutesCovered = 0
        var count = 0

        for item in sorted {
            if minutesCovered >= overflowMinutes {
                break
            }
            minutesCovered += item.durationMinutes
            count += 1
        }

        return count
    }
}
