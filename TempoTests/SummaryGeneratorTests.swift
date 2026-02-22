import XCTest
@testable import Tempo

/// Unit tests for summary generation and language validation
@MainActor
final class SummaryGeneratorTests: XCTestCase {

    var generator: SummaryGenerator!

    override func setUp() {
        super.setUp()
        generator = SummaryGenerator()
    }

    // MARK: - Language Validation Tests

    func testValidateLanguage_ApprovedWords_ReturnsTrue() {
        let approvedTexts = [
            "Your schedule has been adjusted",
            "Task protected",
            "Item resized to fit",
            "Deferred to tomorrow",
            "Your evening is protected"
        ]

        for text in approvedTexts {
            XCTAssertTrue(
                generator.validateLanguage(text),
                "Should accept approved language: \(text)"
            )
        }
    }

    func testValidateLanguage_ForbiddenWords_ReturnsFalse() {
        let forbiddenTexts = [
            "You missed your task",
            "Task was skipped",
            "You failed to complete",
            "You're behind schedule",
            "Task is late",
            "Item is overdue",
            "Task incomplete"
        ]

        for text in forbiddenTexts {
            XCTAssertFalse(
                generator.validateLanguage(text),
                "Should reject forbidden language: \(text)"
            )
        }
    }

    // MARK: - Summary Generation Tests

    func testGenerate_EmptyChanges_OnTrackMessage() {
        // Given
        let changes: [Change] = []

        // When
        let summary = generator.generate(changes: changes, eveningDecision: nil)

        // Then
        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(generator.validateLanguage(summary))
    }

    func testGenerate_ProtectedOnly_NoSignificantChanges() {
        // Given
        let item = ScheduleItem(
            title: "Test Task",
            category: .flexibleTask,
            startTime: Date(),
            durationMinutes: 30
        )
        let changes = [
            Change(item: item, action: .protected, reason: "On track")
        ]

        // When
        let summary = generator.generate(changes: changes, eveningDecision: nil)

        // Then
        XCTAssertTrue(summary.contains("on track") || summary.contains("schedule"), summary)
        XCTAssertTrue(generator.validateLanguage(summary))
    }

    func testGenerate_WithAdjustments_ShowsAdjusted() {
        // Given
        let item = ScheduleItem(
            title: "Morning Run",
            category: .identityHabit,
            startTime: Date(),
            durationMinutes: 60,
            minimumDurationMinutes: 15
        )
        let changes = [
            Change(
                item: item,
                action: .resized(newDurationMinutes: 30),
                reason: "Adjusted to fit"
            )
        ]

        // When
        let summary = generator.generate(changes: changes, eveningDecision: nil)

        // Then
        XCTAssertTrue(summary.lowercased().contains("adjusted"), summary)
        XCTAssertTrue(generator.validateLanguage(summary))
    }

    func testGenerate_WithDeferred_ShowsDeferred() {
        // Given
        let item = ScheduleItem(
            title: "Optional Reading",
            category: .optionalGoal,
            startTime: Date(),
            durationMinutes: 30
        )
        let changes = [
            Change(
                item: item,
                action: .deferred(newDate: Date().addingDays(1)),
                reason: "Deferred to tomorrow"
            )
        ]

        // When
        let summary = generator.generate(changes: changes, eveningDecision: nil)

        // Then
        XCTAssertTrue(summary.lowercased().contains("defer"), summary)
        XCTAssertTrue(generator.validateLanguage(summary))
    }

    func testGenerate_WithEveningProtection_ShowsEvening() {
        // Given
        let changes: [Change] = []
        let eveningDecision = EveningDecision.case1_eveningEmpty()

        // When
        let summary = generator.generate(changes: changes, eveningDecision: eveningDecision)

        // Then
        XCTAssertTrue(generator.validateLanguage(summary))
    }

    // MARK: - Quick Summary Tests

    func testQuickSummary_NoChanges() {
        // Given
        let changes: [Change] = []

        // When
        let summary = generator.quickSummary(changes: changes)

        // Then
        XCTAssertTrue(summary.contains("No changes"))
    }

    func testQuickSummary_MixedChanges() {
        // Given
        let date = Date()
        let items = [
            ScheduleItem(title: "Task 1", category: .identityHabit, startTime: date, durationMinutes: 30),
            ScheduleItem(title: "Task 2", category: .flexibleTask, startTime: date, durationMinutes: 60),
            ScheduleItem(title: "Task 3", category: .optionalGoal, startTime: date, durationMinutes: 20)
        ]

        let changes = [
            Change(item: items[0], action: .protected, reason: "Protected"),
            Change(item: items[1], action: .resized(newDurationMinutes: 45), reason: "Adjusted"),
            Change(item: items[2], action: .deferred(newDate: date.addingDays(1)), reason: "Deferred")
        ]

        // When
        let summary = generator.quickSummary(changes: changes)

        // Then
        XCTAssertTrue(summary.contains("protected"), summary)
        XCTAssertTrue(summary.contains("adjusted"), summary)
        XCTAssertTrue(summary.contains("deferred"), summary)
    }

    // MARK: - Compassionate Message Tests

    func testCompassionateMessages_DontContainForbiddenWords() {
        let messages = [
            Constants.CompassionateMessage.dayAdjusted,
            Constants.CompassionateMessage.habitCompressed,
            Constants.CompassionateMessage.eveningProtected,
            Constants.CompassionateMessage.taskDeferred,
            Constants.CompassionateMessage.fullDayDisruption,
            Constants.CompassionateMessage.onTrack
        ]

        for message in messages {
            XCTAssertTrue(
                generator.validateLanguage(message),
                "Compassionate message contains forbidden word: \(message)"
            )
        }
    }
}
