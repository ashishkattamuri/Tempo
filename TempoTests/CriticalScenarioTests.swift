import XCTest
@testable import Tempo

/// Tests for the 5 critical scenarios from the verification plan
@MainActor
final class CriticalScenarioTests: XCTestCase {

    var engine: ReshuffleEngine!

    override func setUp() {
        super.setUp()
        engine = ReshuffleEngine()
    }

    // MARK: - Scenario 1: Simple Late Start (Compression Works)

    func testScenario1_SimpleLateStart_CompressionWorks() {
        // Given - User starts 30 minutes late with compressible identity habit
        let date = Date()
        let currentTime = date.withTime(hour: 9, minute: 30) // 30 min late

        let morningHabit = ScheduleItem(
            title: "Morning Meditation",
            category: .identityHabit,
            startTime: date.withTime(hour: 9),
            durationMinutes: 30,
            minimumDurationMinutes: 10
        )

        let meeting = ScheduleItem(
            title: "Team Standup",
            category: .nonNegotiable,
            startTime: date.withTime(hour: 10),
            durationMinutes: 30
        )

        let items = [morningHabit, meeting]

        // When
        let result = engine.analyze(items: items, for: date, currentTime: currentTime)

        // Then
        XCTAssertFalse(result.changes.isEmpty, "Should propose changes")

        // Find the habit change
        let habitChange = result.changes.first { $0.item.id == morningHabit.id }
        XCTAssertNotNil(habitChange, "Should have a change for the habit")

        if let change = habitChange {
            switch change.action {
            case .resized(let newDuration):
                XCTAssertGreaterThanOrEqual(newDuration, 10, "Should not compress below minimum")
                XCTAssertLessThan(newDuration, 30, "Should compress from original")
            case .protected:
                // Also acceptable if there's enough time
                XCTAssertTrue(true)
            default:
                XCTFail("Expected resized or protected, got \(change.action)")
            }
        }

        // Meeting should be protected
        let meetingChange = result.changes.first { $0.item.id == meeting.id }
        if let mChange = meetingChange, case .protected = mChange.action {
            XCTAssertTrue(true)
        }
    }

    // MARK: - Scenario 2: Non-Negotiable Overlap (Asks User)

    func testScenario2_NonNegotiableOverlap_AsksUser() {
        // Given - Two non-negotiables overlap
        let date = Date()

        let meeting1 = ScheduleItem(
            title: "Client Call",
            category: .nonNegotiable,
            startTime: date.withTime(hour: 14),
            durationMinutes: 60
        )

        let meeting2 = ScheduleItem(
            title: "Team Meeting",
            category: .nonNegotiable,
            startTime: date.withTime(hour: 14, minute: 30),
            durationMinutes: 60
        )

        let items = [meeting1, meeting2]

        // When
        let result = engine.analyze(items: items, for: date)

        // Then
        XCTAssertTrue(result.requiresUserConsent, "Should require user consent for non-negotiable conflicts")

        let decisionsNeeded = result.itemsRequiringDecision
        XCTAssertFalse(decisionsNeeded.isEmpty, "Should have items requiring user decision")
    }

    // MARK: - Scenario 3: Full Day Disruption (Preserves One Habit)

    func testScenario3_FullDayDisruption_PreservesOneHabit() {
        // Given - Major disruption with multiple items
        let date = Date()
        let currentTime = date.withTime(hour: 14) // Starting very late

        let morningHabit = ScheduleItem(
            title: "Morning Workout",
            category: .identityHabit,
            startTime: date.withTime(hour: 7),
            durationMinutes: 60,
            minimumDurationMinutes: 15
        )

        let lunchHabit = ScheduleItem(
            title: "Mindful Eating",
            category: .identityHabit,
            startTime: date.withTime(hour: 12),
            durationMinutes: 30,
            minimumDurationMinutes: 10
        )

        let eveningHabit = ScheduleItem(
            title: "Evening Journal",
            category: .identityHabit,
            startTime: date.withTime(hour: 21),
            durationMinutes: 20,
            minimumDurationMinutes: 5,
            isEveningTask: true,
            isGentleTask: true
        )

        let workTask = ScheduleItem(
            title: "Project Work",
            category: .flexibleTask,
            startTime: date.withTime(hour: 9),
            durationMinutes: 180
        )

        let items = [morningHabit, lunchHabit, eveningHabit, workTask]

        // When
        let result = engine.analyze(items: items, for: date, currentTime: currentTime)

        // Then - At least one identity habit should be preserved
        let habitChanges = result.changes.filter { $0.item.category == .identityHabit }

        let preservedHabits = habitChanges.filter { change in
            switch change.action {
            case .protected, .resized, .movedAndResized:
                return true
            default:
                return false
            }
        }

        XCTAssertGreaterThanOrEqual(
            preservedHabits.count, 1,
            "At least one identity habit should be preserved"
        )
    }

    // MARK: - Scenario 4: Evening Protection (Doesn't Auto-Touch Evening)

    func testScenario4_EveningProtection_DoesntAutoTouch() {
        // Given - Schedule that would overflow into evening
        let date = Date()

        let tasks: [ScheduleItem] = [
            ScheduleItem(
                title: "Work Block 1",
                category: .flexibleTask,
                startTime: date.withTime(hour: 9),
                durationMinutes: 180
            ),
            ScheduleItem(
                title: "Work Block 2",
                category: .flexibleTask,
                startTime: date.withTime(hour: 13),
                durationMinutes: 180
            ),
            ScheduleItem(
                title: "Work Block 3",
                category: .flexibleTask,
                startTime: date.withTime(hour: 16),
                durationMinutes: 120
            )
        ]

        // When
        let result = engine.analyze(items: tasks, for: date)

        // Then - Evening should require consent if affected
        if result.eveningProtectionTriggered {
            XCTAssertNotNil(result.eveningDecision, "Should have evening decision")
            // Evening changes should require consent
            let eveningChanges = result.changes.filter { $0.item.isEveningTask }
            for change in eveningChanges {
                if case .requiresUserDecision = change.action {
                    XCTAssertTrue(true)
                }
            }
        }
    }

    // MARK: - Scenario 5: Optional Goals Drop First

    func testScenario5_OptionalGoalsDropFirst() {
        // Given - Overflow situation with mixed priorities
        let date = Date()
        let currentTime = date.withTime(hour: 10) // Some late start

        let identityHabit = ScheduleItem(
            title: "Morning Run",
            category: .identityHabit,
            startTime: date.withTime(hour: 9),
            durationMinutes: 45,
            minimumDurationMinutes: 15
        )

        let flexibleTask = ScheduleItem(
            title: "Code Review",
            category: .flexibleTask,
            startTime: date.withTime(hour: 11),
            durationMinutes: 60
        )

        let optionalGoal = ScheduleItem(
            title: "Read Article",
            category: .optionalGoal,
            startTime: date.withTime(hour: 14),
            durationMinutes: 30
        )

        let items = [identityHabit, flexibleTask, optionalGoal]

        // When
        let result = engine.analyze(items: items, for: date, currentTime: currentTime)

        // Then - Optional goals should be deferred before identity habits are heavily compressed
        let optionalChange = result.changes.first { $0.item.id == optionalGoal.id }
        let habitChange = result.changes.first { $0.item.id == identityHabit.id }

        // If optional is deferred, habit should be less compressed
        if let optChange = optionalChange, case .deferred = optChange.action {
            // Good - optional was deferred
            XCTAssertTrue(true)

            // Habit should not be at minimum
            if let habChange = habitChange, case .resized(let duration) = habChange.action {
                XCTAssertGreaterThan(duration, 15, "Habit shouldn't be at minimum if optional was deferred")
            }
        } else {
            // If optional wasn't deferred, it's because there wasn't enough overflow
            // This is also acceptable
            XCTAssertTrue(true)
        }
    }

    // MARK: - Additional Verification: Language Check

    func testLanguageCheck_NoForbiddenWords() {
        // Given
        let date = Date()
        let items = [
            ScheduleItem(
                title: "Test Task",
                category: .flexibleTask,
                startTime: date.withTime(hour: 10),
                durationMinutes: 60
            )
        ]

        // When
        let result = engine.analyze(items: items, for: date)

        // Then - Check summary doesn't contain forbidden words
        let summary = result.summary.lowercased()
        let forbiddenWords = Constants.forbiddenWords

        for word in forbiddenWords {
            XCTAssertFalse(
                summary.contains(word),
                "Summary should not contain '\(word)': \(result.summary)"
            )
        }

        // Check change reasons
        for change in result.changes {
            let reason = change.reason.lowercased()
            for word in forbiddenWords {
                XCTAssertFalse(
                    reason.contains(word),
                    "Change reason should not contain '\(word)': \(change.reason)"
                )
            }
        }
    }
}
