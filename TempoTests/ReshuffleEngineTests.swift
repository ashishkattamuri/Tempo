
import XCTest
@testable import Tempo

@MainActor
final class ReshuffleEngineTests: XCTestCase {
    
    var engine: ReshuffleEngine!
    var calendar: Calendar!
    
    override func setUp() {
        super.setUp()
        engine = ReshuffleEngine()
        calendar = Calendar.current
    }
    
    // MARK: - Helpers
    
    private func makeDate(dayOffset: Int = 0, hour: Int, minute: Int = 0) -> Date {
        let now = Date()
        guard let dayProxy = calendar.date(byAdding: .day, value: dayOffset, to: now) else { return now }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayProxy) ?? now
    }
    
    // MARK: - Requirement 1: Non-negotiable task is never moved
    
    func testNonNegotiableTaskIsNeverMoved() {
        let date = Date()
        // Create a non-negotiable task
        let nonNegotiable = ScheduleItem(
            title: "Import Meeting",
            category: .nonNegotiable,
            startTime: date.withTime(hour: 10),
            durationMinutes: 60
        )
        
        // Create a flexible task that overlaps with it
        // The flexible task is lower priority, so non-negotiable should stay
        let flexibleTask = ScheduleItem(
            title: "Flexible Work",
            category: .flexibleTask,
            startTime: date.withTime(hour: 10),
            durationMinutes: 60
        )
        
        let items = [nonNegotiable, flexibleTask]
        
        // Analyze
        let result = engine.analyze(items: items, for: date)
        
        // Assert non-negotiable is protected
        if let change = result.changes.first(where: { $0.item.id == nonNegotiable.id }) {
            XCTAssertEqual(change.action, .protected, "Non-negotiable task should be protected")
        } else {
            XCTFail("Result should contain change entry for non-negotiable task")
        }
        
        // Assert flexible task is moved
        if let flexibleChange = result.changes.first(where: { $0.item.id == flexibleTask.id }) {
            if case .moved(_) = flexibleChange.action {
                XCTAssertTrue(true)
            } else if case .movedAndResized(_, _) = flexibleChange.action {
                XCTAssertTrue(true)
            } else {
                XCTFail("Flexible task should be moved, got \(flexibleChange.action)")
            }
        }
    }
    
    // MARK: - Requirement 2: Identity habit compresses correctly when day is full
    
    func testIdentityHabitCompressesCorrectlyWhenDayIsFull() {
        let date = Date()
        // Simulate a late start (e.g. 11 AM)
        let currentTime = date.withTime(hour: 11)
        
        // Create a schedule that is full from 11 AM onwards
        // Habit was scheduled for 9 AM (in past relative to current time)
        // It has min duration 15 mins (original 60 mins)
        let habit = ScheduleItem(
            title: "Morning Routine",
            category: .identityHabit,
            startTime: date.withTime(hour: 9),
            durationMinutes: 60,
            minimumDurationMinutes: 15
        )
        
        // Fill the rest of the day with non-negotiables to force compression
        // 12 PM - 6 PM (6 hours)
        let work = ScheduleItem(
            title: "Work Block",
            category: .nonNegotiable,
            startTime: date.withTime(hour: 12),
            durationMinutes: 360 // 6 hours
        )
        
        // So we have gap from 11 AM (current) to 12 PM (work start) = 60 mins.
        // Wait, if gap is 60 mins, habit fits fully.
        // Let's make gap smaller.
        // Work starts at 11:30 AM. Gap is 30 mins.
        // Habit needs 60 mins normally, but can compress to 15.
        // So it should compress to 30 mins to fit in the gap.
        
        let tightWork = ScheduleItem(
            title: "Tight Work Block",
            category: .nonNegotiable,
            startTime: date.withTime(hour: 11, minute: 30),
            durationMinutes: 360
        )
        
        let items = [habit, tightWork]
        
        // Analyze
        let result = engine.analyze(items: items, for: date, currentTime: currentTime)
        
        // Check habit change
        guard let habitChange = result.changes.first(where: { $0.item.id == habit.id }) else {
            XCTFail("Habit should be in changes")
            return
        }
        
        switch habitChange.action {
        case .movedAndResized(let newTime, let newDuration):
            XCTAssertGreaterThanOrEqual(newTime, currentTime, "Should move to current time or later")
            XCTAssertEqual(newDuration, 30, "Should compress to fit available 30 min slot")
        case .resized(let newDuration):
            // If it just resized, implies time didn't change, but time was 9 AM (past).
            // Logic usually moves past items to current time.
            XCTFail("Should have moved from past time 9 AM")
        case .moved(let newTime):
             XCTFail("Should have resized to fit, merely moving isn't enough (gap is only 30 mins)")
        default:
            XCTFail("Unexpected action: \(habitChange.action)")
        }
    }
    
    // MARK: - Requirement 3: Flexible task finds the next free slot
    
    func testFlexibleTaskFindsNextFreeSlot() {
        let date = Date()
        let currentTime = date.withTime(hour: 9)
        
        // Flexible task at 10 AM (1 hour)
        let flexible = ScheduleItem(
            title: "Flexible Task",
            category: .flexibleTask,
            startTime: date.withTime(hour: 10),
            durationMinutes: 60
        )
        
        // Non-negotiable at 10 AM (1 hour) - Conflict!
        let meeting = ScheduleItem(
            title: "Meeting",
            category: .nonNegotiable,
            startTime: date.withTime(hour: 10),
            durationMinutes: 60
        )
        
        let items = [flexible, meeting]
        
        let result = engine.analyze(items: items, for: date, currentTime: currentTime)
        
        // Meeting should stay at 10 AM
        // Flexible should move to 11 AM (next slot)
        
        guard let flexChange = result.changes.first(where: { $0.item.id == flexible.id }) else {
            XCTFail("Flexible task change missing")
            return
        }
        
        guard let meetingChange = result.changes.first(where: { $0.item.id == meeting.id }) else {
            XCTFail("Meeting change missing")
            return
        }
        
        // Verify meeting protected
        XCTAssertEqual(meetingChange.action, .protected)
        
        // Verify flexible moved
        if case .moved(let newTime) = flexChange.action {
            let expectedTime = date.withTime(hour: 11)
            XCTAssertEqual(newTime, expectedTime, "Flexible task should move to 11 AM")
        } else {
            XCTFail("Flexible task should be moved, got \(flexChange.action)")
        }
    }
    
    // MARK: - Requirement 4: Weekly habit moves to a day that doesn't already have it
    
    func testWeeklyHabitMovesToDayWithoutIt() {
        let today = Date()
        // Ensure today is Monday for deterministic test
        // Or just use relative days.
        
        // Create a weekly habit that recurs on Mon, Wed, Fri
        // Item is scheduled for Today
        let weeklyHabit = ScheduleItem(
            title: "Weekly Review",
            category: .identityHabit,
            startTime: today.withTime(hour: 10),
            durationMinutes: 60,
            isRecurring: true,
            frequency: .weekly,
            recurrenceDays: [1, 3, 5] // Mon, Wed, Fri
        )
        
        // Create a conflict for Today (Monday) that fills the rest of the day
        let conflict = ScheduleItem(
            title: "Urgent Meeting",
            category: .nonNegotiable,
            startTime: today.withTime(hour: 10),
            durationMinutes: 14 * 60 // 14 hours from 10 AM blocks the rest of the day
        )
        
        // We use suggestResolution directly as it is responsible for this logic
        let resolutions = engine.suggestResolution(newItem: conflict, conflictingItems: [weeklyHabit])
        
        XCTAssertEqual(resolutions.count, 1)
        
        guard let resolution = resolutions.first else { return }
        
        // It should suggest moving the weekly habit
        if case .moveConflicting(let newDate) = resolution.suggestion {
            // New date should NOT be today
            XCTAssertFalse(calendar.isDate(newDate, inSameDayAs: today), "Should move to a different day")
            XCTAssertTrue(newDate > today, "Should be in future")
            // We assume the engine finds the next valid slot
        } else {
           // If it's .userDecision, it failed to find a slot or decided otherwise
           XCTFail("Should suggest moving conflicting item, got \(resolution.suggestion)")
        }
    }
    
    // MARK: - Requirement 5: Slot finder never returns a time in the past
    
    func testSlotFinderNeverReturnsTimeInPast() throws {
        try XCTSkip("Pending implementation of fix my day feature, tracked in issue 15")
        let date = Date()
        let currentTime = date.withTime(hour: 14) // 2 PM
        
        // Try to schedule a task for 10 AM (Past)
        // With a conflict that forces a move
        let pastTask = ScheduleItem(
            title: "Past Task",
            category: .flexibleTask,
            startTime: date.withTime(hour: 10),
            durationMinutes: 60
        )
        
        // Create conflict at 10 AM just to be sure logic engages
        // But actually ReshuffleEngine handles past items by moving them to currentTime first
        
        let result = engine.analyze(items: [pastTask], for: date, currentTime: currentTime)
        
        guard let change = result.changes.first else {
            XCTFail("Should have a change")
            return
        }
        
        switch change.action {
        case .moved(let newTime):
            XCTAssertGreaterThanOrEqual(newTime, currentTime, "New time should be >= current time")
        case .movedAndResized(let newTime, _):
            XCTAssertGreaterThanOrEqual(newTime, currentTime, "New time should be >= current time")
        case .deferred(let newDate):
            XCTAssertGreaterThanOrEqual(newDate, currentTime, "New date should be in future")
        case .protected:
             // If protected, it implies time didn't change?
             // But if it's in past, analyze() step 2 checks "item.startTime < context.currentTime"
             // So it SHOULD reshuffle.
             XCTFail("Should not be protected if in past")
        default:
            break
        }
    }
    
    // MARK: - Requirement 6: Multi-day slot search works correctly
    
    func testMultiDaySlotSearchWorksCorrectly() {
        let date = Date()
        let currentTime = date.withTime(hour: 9)
        
        // Setup: Today is completely full
        // Block from 6 AM to 6 AM next day (24 hours)
        let fullDayBlock = ScheduleItem(
            title: "All Day Event",
            category: .nonNegotiable,
            startTime: date.withTime(hour: 6),
            durationMinutes: 1440 // 24 hours
        )
        
        // Try to add a flexible task
        let task = ScheduleItem(
            title: "Task to Move",
            category: .flexibleTask,
            startTime: date.withTime(hour: 10),
            durationMinutes: 60
        )
        
        let items = [fullDayBlock, task]
        
        let result = engine.analyze(items: items, for: date, currentTime: currentTime)
        
        guard let change = result.changes.first(where: { $0.item.id == task.id }) else {
            XCTFail("Task change missing")
            return
        }
        
        // Should be deferred to tomorrow or moved to tomorrow (which is effectively deferred/moved)
        if case .moved(let newTime) = change.action {
            XCTAssertFalse(calendar.isDate(newTime, inSameDayAs: date), "Should not be today")
            XCTAssertTrue(newTime > date, "Should be in future")
            XCTAssertGreaterThanOrEqual(newTime.hour, 6, "Should start at min hour (6 AM)")
        } else if case .deferred(let newDate) = change.action {
             XCTAssertFalse(calendar.isDate(newDate, inSameDayAs: date), "Should not be today")
        } else {
             XCTFail("Should move to another day, got \(change.action)")
        }
    }
}


