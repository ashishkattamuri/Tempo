import Foundation

/// Utility functions for time slot calculations and schedule analysis.
enum TimeCalculations {
    // MARK: - Time Slot Operations

    /// Represents a time slot with start and end times
    struct TimeSlot: Equatable {
        let start: Date
        let end: Date

        var durationMinutes: Int {
            Int(end.timeIntervalSince(start) / 60)
        }

        func contains(_ date: Date) -> Bool {
            date >= start && date < end
        }

        func overlaps(with other: TimeSlot) -> Bool {
            start < other.end && end > other.start
        }

        func overlaps(with item: ScheduleItem) -> Bool {
            start < item.endTime && end > item.startTime
        }
    }

    /// Find available time slots in a day, excluding scheduled items
    static func findAvailableSlots(
        on date: Date,
        excluding items: [ScheduleItem],
        startHour: Int = Constants.morningStartHour,
        endHour: Int = Constants.dayEndHour
    ) -> [TimeSlot] {
        let dayStart = date.startOfDay.withTime(hour: startHour)
        let dayEnd = date.startOfDay.withTime(hour: endHour)

        // Sort items by start time
        let sortedItems = items
            .filter { $0.scheduledDate.isSameDay(as: date) }
            .sorted { $0.startTime < $1.startTime }

        var availableSlots: [TimeSlot] = []
        var currentTime = dayStart

        for item in sortedItems {
            // If there's a gap before this item, add it as available
            if currentTime < item.startTime {
                availableSlots.append(TimeSlot(start: currentTime, end: item.startTime))
            }
            // Move past this item
            currentTime = max(currentTime, item.endTime)
        }

        // Add remaining time after last item
        if currentTime < dayEnd {
            availableSlots.append(TimeSlot(start: currentTime, end: dayEnd))
        }

        return availableSlots
    }

    /// Find available evening slots
    static func findEveningSlots(on date: Date, excluding items: [ScheduleItem]) -> [TimeSlot] {
        findAvailableSlots(
            on: date,
            excluding: items,
            startHour: Constants.eveningStartHour,
            endHour: Constants.dayEndHour
        )
    }

    /// Find the first available slot that can fit a given duration
    static func findFirstAvailableSlot(
        durationMinutes: Int,
        on date: Date,
        excluding items: [ScheduleItem],
        after: Date? = nil
    ) -> TimeSlot? {
        let slots = findAvailableSlots(on: date, excluding: items)
        let startTime = after ?? date.startOfDay

        return slots.first { slot in
            slot.start >= startTime && slot.durationMinutes >= durationMinutes
        }
    }

    /// Calculate total free time in evening
    static func eveningFreeMinutes(on date: Date, items: [ScheduleItem]) -> Int {
        let eveningSlots = findEveningSlots(on: date, excluding: items)
        return eveningSlots.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Calculate total scheduled time in evening
    static func eveningScheduledMinutes(on date: Date, items: [ScheduleItem]) -> Int {
        items
            .filter { $0.scheduledDate.isSameDay(as: date) && $0.isEveningTask }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Overflow Detection

    /// Calculate how many minutes of overflow exist from the current time
    static func calculateOverflow(
        from currentTime: Date,
        items: [ScheduleItem],
        untilHour: Int = Constants.eveningStartHour
    ) -> Int {
        let endTime = currentTime.startOfDay.withTime(hour: untilHour)
        let availableMinutes = max(0, Int(endTime.timeIntervalSince(currentTime) / 60))

        let remainingItems = items.filter { item in
            !item.isCompleted &&
            item.startTime >= currentTime &&
            item.startTime < endTime
        }

        let neededMinutes = remainingItems.reduce(0) { $0 + $1.durationMinutes }
        return max(0, neededMinutes - availableMinutes)
    }

    /// Check if there would be overflow into evening
    static func wouldOverflowIntoEvening(
        from currentTime: Date,
        items: [ScheduleItem]
    ) -> Bool {
        calculateOverflow(from: currentTime, items: items) > 0
    }

    // MARK: - Task Fitting

    /// Check if a task can fit in a specific time slot
    static func canFit(
        durationMinutes: Int,
        in slot: TimeSlot
    ) -> Bool {
        slot.durationMinutes >= durationMinutes
    }

    /// Check if a task can fit between two times
    static func canFit(
        durationMinutes: Int,
        between start: Date,
        and end: Date
    ) -> Bool {
        let slot = TimeSlot(start: start, end: end)
        return canFit(durationMinutes: durationMinutes, in: slot)
    }

    /// Calculate how much compression is needed to fit remaining tasks
    static func compressionNeeded(
        for items: [ScheduleItem],
        availableMinutes: Int
    ) -> Int {
        let totalNeeded = items.reduce(0) { $0 + $1.durationMinutes }
        return max(0, totalNeeded - availableMinutes)
    }

    /// Calculate maximum compression available from identity habits
    static func maxCompressionAvailable(from items: [ScheduleItem]) -> Int {
        items
            .filter { $0.category == .identityHabit && $0.isCompressible }
            .reduce(0) { $0 + $1.compressibleMinutes }
    }

    // MARK: - Conflict Detection

    /// Find items that conflict with a given time range
    static func findConflicts(
        for timeRange: TimeSlot,
        in items: [ScheduleItem]
    ) -> [ScheduleItem] {
        items.filter { item in
            timeRange.overlaps(with: item)
        }
    }

    /// Check if moving an item to a new time would cause conflicts
    static func wouldCauseConflict(
        moving item: ScheduleItem,
        to newStartTime: Date,
        in items: [ScheduleItem]
    ) -> Bool {
        let newEndTime = newStartTime.addingMinutes(item.durationMinutes)
        let newSlot = TimeSlot(start: newStartTime, end: newEndTime)

        return items.contains { other in
            other.id != item.id && newSlot.overlaps(with: other)
        }
    }
}
