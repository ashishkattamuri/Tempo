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
        isGentleTask: Bool = false
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
        notes: String?? = nil
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
            scheduledDate: self.scheduledDate,
            isEveningTask: self.isEveningTask,
            isGentleTask: self.isGentleTask
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
