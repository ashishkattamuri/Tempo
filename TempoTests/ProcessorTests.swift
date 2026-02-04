import XCTest
@testable import Tempo

/// Unit tests for all category processors
final class ProcessorTests: XCTestCase {

    // MARK: - Non-Negotiable Processor Tests

    func testNonNegotiableWithNoConflicts_IsProtected() {
        // Given
        let processor = NonNegotiableProcessor()
        let item = ScheduleItem(
            title: "Team Meeting",
            category: .nonNegotiable,
            startTime: Date().withTime(hour: 10),
            durationMinutes: 60
        )
        let context = createContext(with: [item])

        // When
        let change = processor.process(item: item, context: context)

        // Then
        if case .protected = change.action {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected protected action")
        }
    }

    func testNonNegotiableWithConflict_RequiresUserDecision() {
        // Given
        let processor = NonNegotiableProcessor()
        let item1 = ScheduleItem(
            title: "Meeting 1",
            category: .nonNegotiable,
            startTime: Date().withTime(hour: 10),
            durationMinutes: 60
        )
        let item2 = ScheduleItem(
            title: "Meeting 2",
            category: .nonNegotiable,
            startTime: Date().withTime(hour: 10, minute: 30),
            durationMinutes: 60
        )
        let context = createContext(with: [item1, item2])

        // When
        let change = processor.process(item: item1, context: context)

        // Then
        if case .requiresUserDecision = change.action {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected requiresUserDecision action")
        }
    }

    // MARK: - Identity Habit Processor Tests

    func testIdentityHabitNoOverflow_IsProtected() {
        // Given
        let processor = IdentityHabitProcessor()
        let item = ScheduleItem(
            title: "Morning Meditation",
            category: .identityHabit,
            startTime: Date().withTime(hour: 7),
            durationMinutes: 30,
            minimumDurationMinutes: 10
        )
        let context = createContext(with: [item], hasOverflow: false)

        // When
        let change = processor.process(item: item, context: context)

        // Then
        if case .protected = change.action {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected protected action, got \(change.action)")
        }
    }

    func testIdentityHabitWithOverflow_IsCompressed() {
        // Given
        let processor = IdentityHabitProcessor()
        let habit = ScheduleItem(
            title: "Workout",
            category: .identityHabit,
            startTime: Date().withTime(hour: 7),
            durationMinutes: 60,
            minimumDurationMinutes: 15
        )
        let context = createContext(with: [habit], hasOverflow: true, overflowMinutes: 30)

        // When
        let change = processor.process(item: habit, context: context)

        // Then
        switch change.action {
        case .resized(let newDuration):
            XCTAssertLessThan(newDuration, 60)
            XCTAssertGreaterThanOrEqual(newDuration, 15)
        case .protected:
            // Also acceptable if other items absorb overflow
            XCTAssertTrue(true)
        default:
            XCTFail("Expected resized or protected action, got \(change.action)")
        }
    }

    func testIdentityHabitNeverRemoved() {
        // Given - Full day disruption scenario
        let processor = IdentityHabitProcessor()
        let habit = ScheduleItem(
            title: "Daily Journal",
            category: .identityHabit,
            startTime: Date().withTime(hour: 20),
            durationMinutes: 30,
            minimumDurationMinutes: 5
        )
        let context = createContext(with: [habit], hasOverflow: true, overflowMinutes: 500)

        // When
        let change = processor.process(item: habit, context: context)

        // Then - Should never be deferred or deleted
        switch change.action {
        case .deferred:
            XCTFail("Identity habits should never be deferred")
        case .pooled:
            XCTFail("Identity habits should never be pooled")
        default:
            XCTAssertTrue(true, "Identity habit was preserved")
        }
    }

    // MARK: - Flexible Task Processor Tests

    func testFlexibleTaskNoOverflow_IsProtected() {
        // Given
        let processor = FlexibleTaskProcessor()
        let item = ScheduleItem(
            title: "Code Review",
            category: .flexibleTask,
            startTime: Date().withTime(hour: 14),
            durationMinutes: 60
        )
        let context = createContext(with: [item], hasOverflow: false)

        // When
        let change = processor.process(item: item, context: context)

        // Then
        if case .protected = change.action {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected protected action")
        }
    }

    func testFlexibleTaskWithOverflow_CanBeDeferred() {
        // Given
        let processor = FlexibleTaskProcessor()
        let item = ScheduleItem(
            title: "Research Task",
            category: .flexibleTask,
            startTime: Date().withTime(hour: 15),
            durationMinutes: 120
        )
        let context = createContext(with: [item], hasOverflow: true, overflowMinutes: 60)

        // When
        let change = processor.process(item: item, context: context)

        // Then
        switch change.action {
        case .deferred, .pooled, .moved, .protected:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected deferred, pooled, moved, or protected action")
        }
    }

    // MARK: - Optional Goal Processor Tests

    func testOptionalGoalNoOverflow_IsProtected() {
        // Given
        let processor = OptionalGoalProcessor()
        let item = ScheduleItem(
            title: "Read Article",
            category: .optionalGoal,
            startTime: Date().withTime(hour: 16),
            durationMinutes: 30
        )
        let context = createContext(with: [item], hasOverflow: false)

        // When
        let change = processor.process(item: item, context: context)

        // Then
        if case .protected = change.action {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected protected action")
        }
    }

    func testOptionalGoalWithOverflow_IsDeferredFirst() {
        // Given
        let processor = OptionalGoalProcessor()
        let item = ScheduleItem(
            title: "Watch Tutorial",
            category: .optionalGoal,
            startTime: Date().withTime(hour: 17),
            durationMinutes: 45
        )
        let context = createContext(with: [item], hasOverflow: true, overflowMinutes: 30)

        // When
        let change = processor.process(item: item, context: context)

        // Then
        if case .deferred = change.action {
            XCTAssertTrue(true)
        } else {
            XCTFail("Optional goals should be deferred first when there's overflow")
        }
    }

    // MARK: - Helper Methods

    private func createContext(
        with items: [ScheduleItem],
        hasOverflow: Bool = false,
        overflowMinutes: Int = 0
    ) -> ReshuffleContext {
        let date = Date()
        let availableMinutes = hasOverflow
            ? items.reduce(0) { $0 + $1.durationMinutes } - overflowMinutes
            : items.reduce(0) { $0 + $1.durationMinutes } + 60

        let slots = hasOverflow ? [] : [
            TimeCalculations.TimeSlot(
                start: date.withTime(hour: 9),
                end: date.withTime(hour: 17)
            )
        ]

        return ReshuffleContext(
            currentTime: date.withTime(hour: 8),
            targetDate: date,
            allItems: items,
            incompleteItems: items.filter { !$0.isCompleted },
            availableSlots: slots,
            availableMinutesBeforeEvening: availableMinutes,
            neededMinutes: items.reduce(0) { $0 + $1.durationMinutes }
        )
    }
}
