import Foundation

/// Protocol for category-specific reshuffle logic.
/// Each category has different rules for how it can be adjusted.
protocol CategoryProcessor {
    /// The category this processor handles
    var category: TaskCategory { get }

    /// Process an item and return the proposed change
    /// - Parameters:
    ///   - item: The schedule item to process
    ///   - context: Current reshuffle context with available time, etc.
    /// - Returns: The proposed change for this item
    func process(item: ScheduleItem, context: ReshuffleContext) -> Change
}

/// Context provided to processors during reshuffle
struct ReshuffleContext {
    /// Current time (when reshuffle was triggered)
    let currentTime: Date

    /// The date being reshuffled
    let targetDate: Date

    /// All items for the day (including completed)
    let allItems: [ScheduleItem]

    /// Incomplete items that need to be scheduled
    let incompleteItems: [ScheduleItem]

    /// Available time slots for the rest of the day
    let availableSlots: [TimeCalculations.TimeSlot]

    /// Total available minutes before evening
    let availableMinutesBeforeEvening: Int

    /// Total minutes needed for remaining incomplete items
    let neededMinutes: Int

    /// Whether there's overflow (needed > available)
    var hasOverflow: Bool {
        neededMinutes > availableMinutesBeforeEvening
    }

    /// Minutes of overflow (0 if no overflow)
    var overflowMinutes: Int {
        max(0, neededMinutes - availableMinutesBeforeEvening)
    }

    /// Items sorted by priority (non-negotiables first)
    var itemsByPriority: [ScheduleItem] {
        incompleteItems.sorted { $0.category.priority < $1.category.priority }
    }

    /// Identity habits that can be compressed
    var compressibleHabits: [ScheduleItem] {
        incompleteItems.filter { $0.category == .identityHabit && $0.isCompressible }
    }

    /// Total compression available from identity habits
    var maxCompressionMinutes: Int {
        compressibleHabits.reduce(0) { $0 + $1.compressibleMinutes }
    }

    /// Optional goals that can be dropped
    var optionalGoals: [ScheduleItem] {
        incompleteItems.filter { $0.category == .optionalGoal }
    }

    /// Minutes that could be freed by dropping optional goals
    var optionalGoalMinutes: Int {
        optionalGoals.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Flexible tasks that can be moved
    var flexibleTasks: [ScheduleItem] {
        incompleteItems.filter { $0.category == .flexibleTask }
    }

    /// Evening items
    var eveningItems: [ScheduleItem] {
        allItems.filter { $0.isEveningTask }
    }

    /// Find the first available slot that can fit the given duration
    func findSlot(forDurationMinutes minutes: Int, after: Date? = nil) -> TimeCalculations.TimeSlot? {
        let startAfter = after ?? currentTime
        return availableSlots.first { slot in
            slot.start >= startAfter && slot.durationMinutes >= minutes
        }
    }

    /// Find a slot on a specific date (for moving tasks to different days)
    func findSlot(forDurationMinutes minutes: Int, on targetDate: Date) -> TimeCalculations.TimeSlot? {
        // If it's the same day as context, use existing slots
        if targetDate.isSameDay(as: self.targetDate) {
            return findSlot(forDurationMinutes: minutes)
        }

        // For a different day, calculate available slots for that day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: targetDate)

        // Find items scheduled for that date
        let itemsOnDate = allItems.filter { $0.scheduledDate.isSameDay(as: targetDate) && !$0.isCompleted }

        // Calculate available slots
        let slots = TimeCalculations.findAvailableSlots(
            on: targetDate,
            excluding: itemsOnDate,
            startHour: 6, // Start from 6 AM for future days
            endHour: Constants.eveningStartHour
        )

        return slots.first { slot in
            slot.durationMinutes >= minutes
        }
    }

    /// Check if a specific time slot is available
    func isSlotAvailable(start: Date, durationMinutes: Int) -> Bool {
        let endTime = start.addingMinutes(durationMinutes)
        let testSlot = TimeCalculations.TimeSlot(start: start, end: endTime)

        // Check no overlap with any existing items
        return !allItems.contains { item in
            testSlot.overlaps(with: item)
        }
    }
}

// MARK: - Context Factory

extension ReshuffleContext {
    /// Create a context for reshuffling a specific day.
    /// `items` may include items from multiple days — only today's items are used for
    /// overflow/conflict calculations, but ALL items are kept in `allItems` so that
    /// slot searches on future days (e.g. tomorrow) see the real schedule.
    static func create(
        for date: Date,
        items: [ScheduleItem],
        currentTime: Date = Date()
    ) -> ReshuffleContext {
        let todayItems = items.filter { $0.scheduledDate.isSameDay(as: date) }
        let incompleteItems = todayItems.filter { !$0.isCompleted }

        let availableSlots = TimeCalculations.findAvailableSlots(
            on: date,
            excluding: todayItems.filter { $0.isCompleted },
            startHour: currentTime.hour,
            endHour: Constants.eveningStartHour
        )

        let availableMinutes = availableSlots.reduce(0) { $0 + $1.durationMinutes }
        let neededMinutes = incompleteItems.reduce(0) { $0 + $1.durationMinutes }

        return ReshuffleContext(
            currentTime: currentTime,
            targetDate: date,
            allItems: items,        // all days — for cross-day slot search
            incompleteItems: incompleteItems,
            availableSlots: availableSlots,
            availableMinutesBeforeEvening: availableMinutes,
            neededMinutes: neededMinutes
        )
    }
}
