import Foundation
import SwiftData

/// Core data entity representing a scheduled task or event.
/// Uses SwiftData @Model for automatic persistence.
@Model
final class ScheduleItem {
    /// Unique identifier
    var id: UUID

    /// Task title - what the user is doing
    var title: String

    /// The category determines how this item is handled during reshuffles
    var categoryRawValue: String

    /// Scheduled start time
    var startTime: Date

    /// Planned duration in minutes
    var durationMinutes: Int

    /// Minimum duration in minutes (for identity habits that can be compressed)
    /// If nil, task cannot be compressed
    var minimumDurationMinutes: Int?

    /// Optional notes or context
    var notes: String?

    /// Whether this task has been completed
    var isCompleted: Bool

    /// The date this task is scheduled for (without time component)
    var scheduledDate: Date

    /// Whether this is an evening task (affects evening protection logic)
    var isEveningTask: Bool

    /// Whether this is a gentle/low-energy task (for evening protection)
    var isGentleTask: Bool

    // MARK: - Recurrence Properties

    /// Whether this task recurs on specific days
    var isRecurring: Bool

    /// Frequency type: "daily" or "weekly"
    var frequencyRawValue: String

    /// Number of times per week (only used when frequency is weekly)
    var timesPerWeek: Int?

    /// Days of week this task recurs (0=Sunday, 1=Monday, ..., 6=Saturday)
    /// Stored as comma-separated string for SwiftData compatibility
    var recurrenceDaysRaw: String?

    /// Optional end date for the recurrence
    var recurrenceEndDate: Date?

    /// ID of the parent recurring task (for instances)
    var parentTaskId: UUID?

    /// Whether this is an instance generated from a recurring task
    var isRecurrenceInstance: Bool

    // MARK: - Compensation Properties

    /// Minutes of compensation debt (for optional goals that were deferred)
    var compensationDebtMinutes: Int

    /// Whether this is a makeup session for a deferred task
    var isCompensationTask: Bool

    /// Links to the original deferred task
    var originalTaskId: UUID?

    /// Creation timestamp
    var createdAt: Date

    /// Last modification timestamp
    var updatedAt: Date

    // MARK: - Computed Properties

    var category: TaskCategory {
        get {
            TaskCategory(rawValue: categoryRawValue) ?? .flexibleTask
        }
        set {
            categoryRawValue = newValue.rawValue
        }
    }

    /// Frequency of recurrence (daily or weekly)
    var frequency: RecurrenceFrequency {
        get {
            RecurrenceFrequency(rawValue: frequencyRawValue) ?? .daily
        }
        set {
            frequencyRawValue = newValue.rawValue
        }
    }

    /// Whether this is a daily habit/goal (recurs every day)
    var isDaily: Bool {
        isRecurring && frequency == .daily
    }

    /// Whether this is a weekly habit/goal (X times per week)
    var isWeekly: Bool {
        isRecurring && frequency == .weekly
    }

    /// End time based on start time and duration
    var endTime: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startTime) ?? startTime
    }

    /// Duration as TimeInterval
    var duration: TimeInterval {
        TimeInterval(durationMinutes * 60)
    }

    /// Minimum duration as TimeInterval (if compressible)
    var minimumDuration: TimeInterval? {
        guard let min = minimumDurationMinutes else { return nil }
        return TimeInterval(min * 60)
    }

    /// Whether this task can be compressed (has a minimum duration less than current)
    var isCompressible: Bool {
        guard let min = minimumDurationMinutes else { return false }
        return min < durationMinutes
    }

    /// The amount of time that can be saved by compressing to minimum
    var compressibleMinutes: Int {
        guard let min = minimumDurationMinutes else { return 0 }
        return max(0, durationMinutes - min)
    }

    /// Days of week this task recurs as an array
    var recurrenceDays: [Int] {
        get {
            guard let raw = recurrenceDaysRaw, !raw.isEmpty else { return [] }
            return raw.split(separator: ",").compactMap { Int($0) }
        }
        set {
            if newValue.isEmpty {
                recurrenceDaysRaw = nil
            } else {
                recurrenceDaysRaw = newValue.map(String.init).joined(separator: ",")
            }
        }
    }

    /// Human-readable recurrence description
    var recurrenceDescription: String? {
        guard isRecurring, !recurrenceDays.isEmpty else { return nil }

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sortedDays = recurrenceDays.sorted()

        // Check for common patterns
        if sortedDays == [1, 2, 3, 4, 5] {
            return "Weekdays"
        } else if sortedDays == [0, 6] {
            return "Weekends"
        } else if sortedDays == [0, 1, 2, 3, 4, 5, 6] {
            return "Every day"
        } else {
            return sortedDays.map { dayNames[$0] }.joined(separator: ", ")
        }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String,
        category: TaskCategory,
        startTime: Date,
        durationMinutes: Int,
        minimumDurationMinutes: Int? = nil,
        notes: String? = nil,
        isCompleted: Bool = false,
        scheduledDate: Date? = nil,
        isEveningTask: Bool = false,
        isGentleTask: Bool = false,
        isRecurring: Bool = false,
        frequency: RecurrenceFrequency = .daily,
        timesPerWeek: Int? = nil,
        recurrenceDays: [Int] = [],
        recurrenceEndDate: Date? = nil,
        parentTaskId: UUID? = nil,
        isRecurrenceInstance: Bool = false,
        compensationDebtMinutes: Int = 0,
        isCompensationTask: Bool = false,
        originalTaskId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.categoryRawValue = category.rawValue
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.minimumDurationMinutes = minimumDurationMinutes
        self.notes = notes
        self.isCompleted = isCompleted
        self.scheduledDate = scheduledDate ?? Calendar.current.startOfDay(for: startTime)
        self.isEveningTask = isEveningTask
        self.isGentleTask = isGentleTask
        self.isRecurring = isRecurring
        self.frequencyRawValue = frequency.rawValue
        self.timesPerWeek = timesPerWeek
        self.recurrenceDaysRaw = recurrenceDays.isEmpty ? nil : recurrenceDays.map(String.init).joined(separator: ",")
        self.recurrenceEndDate = recurrenceEndDate
        self.parentTaskId = parentTaskId
        self.isRecurrenceInstance = isRecurrenceInstance
        self.compensationDebtMinutes = compensationDebtMinutes
        self.isCompensationTask = isCompensationTask
        self.originalTaskId = originalTaskId
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Methods

    /// Creates a copy of this item with optional modifications
    func copy(
        title: String? = nil,
        category: TaskCategory? = nil,
        startTime: Date? = nil,
        durationMinutes: Int? = nil,
        minimumDurationMinutes: Int?? = nil,
        notes: String?? = nil,
        scheduledDate: Date? = nil
    ) -> ScheduleItem {
        ScheduleItem(
            id: UUID(), // New ID for the copy
            title: title ?? self.title,
            category: category ?? self.category,
            startTime: startTime ?? self.startTime,
            durationMinutes: durationMinutes ?? self.durationMinutes,
            minimumDurationMinutes: minimumDurationMinutes ?? self.minimumDurationMinutes,
            notes: notes ?? self.notes,
            isCompleted: false,
            scheduledDate: scheduledDate ?? self.scheduledDate,
            isEveningTask: self.isEveningTask,
            isGentleTask: self.isGentleTask
        )
    }

    /// Creates a recurrence instance for a specific date
    func createRecurrenceInstance(for date: Date) -> ScheduleItem {
        let calendar = Calendar.current
        // Combine the target date with the original time
        let timeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        var newStartComponents = calendar.dateComponents([.year, .month, .day], from: date)
        newStartComponents.hour = timeComponents.hour
        newStartComponents.minute = timeComponents.minute
        let newStartTime = calendar.date(from: newStartComponents) ?? date

        return ScheduleItem(
            title: title,
            category: category,
            startTime: newStartTime,
            durationMinutes: durationMinutes,
            minimumDurationMinutes: minimumDurationMinutes,
            notes: notes,
            isCompleted: false,
            scheduledDate: calendar.startOfDay(for: date),
            isEveningTask: isEveningTask,
            isGentleTask: isGentleTask,
            isRecurring: false,
            frequency: frequency,
            timesPerWeek: timesPerWeek,
            parentTaskId: id,
            isRecurrenceInstance: true
        )
    }

    /// Check if this item overlaps with another time range
    func overlaps(with start: Date, end: Date) -> Bool {
        return startTime < end && endTime > start
    }

    /// Check if this item overlaps with another schedule item
    func overlaps(with other: ScheduleItem) -> Bool {
        return overlaps(with: other.startTime, end: other.endTime)
    }

    /// Update the modified timestamp
    func touch() {
        updatedAt = Date()
    }
}

// MARK: - Hashable & Equatable

extension ScheduleItem: Equatable {
    static func == (lhs: ScheduleItem, rhs: ScheduleItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension ScheduleItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
