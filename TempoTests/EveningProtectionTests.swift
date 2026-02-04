import XCTest
@testable import Tempo

/// Unit tests for the 10 evening protection cases
final class EveningProtectionTests: XCTestCase {

    var analyzer: EveningProtectionAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = EveningProtectionAnalyzer()
    }

    // MARK: - Case 1: Evening is empty

    func testCase1_EveningEmpty_NoOverflow_KeepsFree() {
        // Given
        let items: [ScheduleItem] = []
        let date = Date()
        let overflow = OverflowDetector.OverflowAnalysis(
            overflowMinutes: 0,
            spillsIntoEvening: false,
            eveningSpillMinutes: 0,
            suggestedStrategy: .noAction
        )

        // When
        let decision = analyzer.analyze(items: items, for: date, overflowAnalysis: overflow)

        // Then
        XCTAssertEqual(decision.caseNumber, 1)
        if case .keepFree = decision.recommendation {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected keepFree recommendation")
        }
        XCTAssertFalse(decision.requiresConsent)
    }

    // MARK: - Case 2: Evening has gentle tasks only

    func testCase2_GentleTasksOnly_AllowsGentleOnly() {
        // Given
        let gentleTask = ScheduleItem(
            title: "Light Reading",
            category: .optionalGoal,
            startTime: Date().withTime(hour: 20),
            durationMinutes: 30,
            isEveningTask: true,
            isGentleTask: true
        )
        let date = Date()
        let overflow = OverflowDetector.OverflowAnalysis(
            overflowMinutes: 0,
            spillsIntoEvening: false,
            eveningSpillMinutes: 0,
            suggestedStrategy: .noAction
        )

        // When
        let decision = analyzer.analyze(items: [gentleTask], for: date, overflowAnalysis: overflow)

        // Then
        XCTAssertEqual(decision.caseNumber, 2)
        if case .allowGentleOnly = decision.recommendation {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected allowGentleOnly recommendation")
        }
    }

    // MARK: - Case 3: Evening has high-energy tasks

    func testCase3_HighEnergyTasks_SuggestsMakeLighter() {
        // Given
        let highEnergyTask = ScheduleItem(
            title: "Intense Workout",
            category: .flexibleTask,
            startTime: Date().withTime(hour: 20),
            durationMinutes: 60,
            isEveningTask: true,
            isGentleTask: false
        )
        let date = Date()
        let overflow = OverflowDetector.OverflowAnalysis(
            overflowMinutes: 0,
            spillsIntoEvening: false,
            eveningSpillMinutes: 0,
            suggestedStrategy: .noAction
        )

        // When
        let decision = analyzer.analyze(items: [highEnergyTask], for: date, overflowAnalysis: overflow)

        // Then
        XCTAssertEqual(decision.caseNumber, 3)
        XCTAssertTrue(decision.requiresConsent)
    }

    // MARK: - Case 4: Overflow would push into evening

    func testCase4_OverflowDetected_RequiresConsent() {
        // Given
        let items: [ScheduleItem] = []
        let date = Date()
        let overflow = OverflowDetector.OverflowAnalysis(
            overflowMinutes: 60,
            spillsIntoEvening: true,
            eveningSpillMinutes: 30,
            suggestedStrategy: .deferFlexible(count: 1)
        )

        // When
        let decision = analyzer.analyze(items: items, for: date, overflowAnalysis: overflow)

        // Then
        XCTAssertEqual(decision.caseNumber, 4)
        XCTAssertTrue(decision.requiresConsent)
    }

    // MARK: - Case 5: Evening has non-negotiable

    func testCase5_EveningNonNegotiable_UserAllowed() {
        // Given
        let nonNegotiable = ScheduleItem(
            title: "Evening Class",
            category: .nonNegotiable,
            startTime: Date().withTime(hour: 19),
            durationMinutes: 90,
            isEveningTask: true
        )
        let date = Date()
        let overflow = OverflowDetector.OverflowAnalysis(
            overflowMinutes: 0,
            spillsIntoEvening: false,
            eveningSpillMinutes: 0,
            suggestedStrategy: .noAction
        )

        // When
        let decision = analyzer.analyze(items: [nonNegotiable], for: date, overflowAnalysis: overflow)

        // Then
        XCTAssertEqual(decision.caseNumber, 5)
        if case .userAllowed = decision.recommendation {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected userAllowed recommendation")
        }
        XCTAssertFalse(decision.requiresConsent)
    }

    // MARK: - Case 6: Gentle identity habit

    func testCase6_GentleIdentityHabit_AllowsGentleOnly() {
        // Given
        let gentleHabit = ScheduleItem(
            title: "Evening Journal",
            category: .identityHabit,
            startTime: Date().withTime(hour: 21),
            durationMinutes: 20,
            minimumDurationMinutes: 5,
            isEveningTask: true,
            isGentleTask: true
        )
        let date = Date()
        let overflow = OverflowDetector.OverflowAnalysis(
            overflowMinutes: 0,
            spillsIntoEvening: false,
            eveningSpillMinutes: 0,
            suggestedStrategy: .noAction
        )

        // When
        let decision = analyzer.analyze(items: [gentleHabit], for: date, overflowAnalysis: overflow)

        // Then
        XCTAssertEqual(decision.caseNumber, 6)
        XCTAssertFalse(decision.requiresConsent)
    }

    // MARK: - Case 7: High-energy identity habit

    func testCase7_HighEnergyIdentityHabit_RequiresConsent() {
        // Given
        let highEnergyHabit = ScheduleItem(
            title: "Evening Run",
            category: .identityHabit,
            startTime: Date().withTime(hour: 20),
            durationMinutes: 45,
            minimumDurationMinutes: 20,
            isEveningTask: true,
            isGentleTask: false
        )
        let date = Date()
        let overflow = OverflowDetector.OverflowAnalysis(
            overflowMinutes: 0,
            spillsIntoEvening: false,
            eveningSpillMinutes: 0,
            suggestedStrategy: .noAction
        )

        // When
        let decision = analyzer.analyze(items: [highEnergyHabit], for: date, overflowAnalysis: overflow)

        // Then
        XCTAssertEqual(decision.caseNumber, 7)
        XCTAssertTrue(decision.requiresConsent)
    }

    // MARK: - Case 8: Evening slack being consumed

    func testCase8_SlackConsumed_PreservesSlack() {
        // Given - Fill evening with many tasks
        var tasks: [ScheduleItem] = []
        for i in 0..<10 {
            tasks.append(ScheduleItem(
                title: "Task \(i)",
                category: .flexibleTask,
                startTime: Date().withTime(hour: 18 + (i / 2)),
                durationMinutes: 25,
                isEveningTask: true,
                isGentleTask: true
            ))
        }
        let date = Date()
        let overflow = OverflowDetector.OverflowAnalysis(
            overflowMinutes: 0,
            spillsIntoEvening: false,
            eveningSpillMinutes: 0,
            suggestedStrategy: .noAction
        )

        // When
        let decision = analyzer.analyze(items: tasks, for: date, overflowAnalysis: overflow)

        // Then - Should detect slack being consumed
        XCTAssertTrue(decision.caseNumber == 2 || decision.caseNumber == 8,
                      "Expected case 2 (gentle only) or case 8 (slack consumed)")
    }

    // MARK: - Case 9: User explicitly chose evening tasks

    func testCase9_UserChoseEvening_Respected() {
        // Given
        let userTask = ScheduleItem(
            title: "Evening Project",
            category: .flexibleTask,
            startTime: Date().withTime(hour: 19),
            durationMinutes: 60,
            isEveningTask: true,
            isGentleTask: true
        )
        let date = Date()
        let overflow = OverflowDetector.OverflowAnalysis(
            overflowMinutes: 0,
            spillsIntoEvening: false,
            eveningSpillMinutes: 0,
            suggestedStrategy: .noAction
        )

        // When
        let decision = analyzer.analyze(items: [userTask], for: date, overflowAnalysis: overflow)

        // Then
        XCTAssertFalse(decision.requiresConsent, "User's explicit evening tasks should be respected")
    }

    // MARK: - Case 10: Full day disruption

    func testCase10_FullDayDisruption_ProtectsOneHabit() {
        // Given
        let gentleHabit = ScheduleItem(
            title: "Evening Meditation",
            category: .identityHabit,
            startTime: Date().withTime(hour: 21),
            durationMinutes: 15,
            minimumDurationMinutes: 5,
            isEveningTask: true,
            isGentleTask: true
        )
        let date = Date()
        let overflow = OverflowDetector.OverflowAnalysis(
            overflowMinutes: 500,
            spillsIntoEvening: true,
            eveningSpillMinutes: 120,
            suggestedStrategy: .fullDayDisruption
        )

        // When
        let decision = analyzer.analyze(items: [gentleHabit], for: date, overflowAnalysis: overflow)

        // Then
        XCTAssertFalse(decision.affectedItems.isEmpty, "Should protect at least one evening item")
    }

    // MARK: - Helper Tests

    func testCanFlowIntoEvening_GentleTask_ReturnsTrue() {
        // Given
        let gentleTask = ScheduleItem(
            title: "Light Reading",
            category: .optionalGoal,
            startTime: Date().withTime(hour: 20),
            durationMinutes: 30,
            isGentleTask: true
        )

        // When
        let canFlow = analyzer.canFlowIntoEvening(gentleTask)

        // Then
        XCTAssertTrue(canFlow)
    }

    func testCanFlowIntoEvening_HighEnergyTask_ReturnsFalse() {
        // Given
        let highEnergyTask = ScheduleItem(
            title: "Intense Work",
            category: .flexibleTask,
            startTime: Date().withTime(hour: 20),
            durationMinutes: 60,
            isGentleTask: false
        )

        // When
        let canFlow = analyzer.canFlowIntoEvening(highEnergyTask)

        // Then
        XCTAssertFalse(canFlow)
    }
}
