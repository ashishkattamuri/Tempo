import Foundation

/// Represents time that needs to be made up due to deferred or cancelled tasks.
/// Only Optional Goals track compensation debt - Identity Habits that get compressed don't create debt.
struct CompensationRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let taskId: UUID
    let taskTitle: String
    let categoryRawValue: String
    let lostMinutes: Int
    let originalDate: Date
    let reason: CompensationReason

    var compensatedMinutes: Int = 0
    var compensationDate: Date? = nil
    var isFullyCompensated: Bool = false

    /// The category of the original task
    var category: TaskCategory {
        TaskCategory(rawValue: categoryRawValue) ?? .optionalGoal
    }

    /// Remaining minutes to compensate
    var remainingMinutes: Int {
        max(0, lostMinutes - compensatedMinutes)
    }

    /// Human-readable reason
    var reasonDescription: String {
        switch reason {
        case .compressed:
            return "Compressed from full duration"
        case .deferred:
            return "Moved to a later date"
        case .cancelled:
            return "Couldn't fit in schedule"
        }
    }

    /// Reason why compensation is needed
    enum CompensationReason: String, Codable {
        case compressed  // Task was shortened
        case deferred    // Task was moved to another day
        case cancelled   // Task was removed entirely
    }

    init(
        id: UUID = UUID(),
        taskId: UUID,
        taskTitle: String,
        category: TaskCategory,
        lostMinutes: Int,
        originalDate: Date,
        reason: CompensationReason
    ) {
        self.id = id
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.categoryRawValue = category.rawValue
        self.lostMinutes = lostMinutes
        self.originalDate = originalDate
        self.reason = reason
    }

    /// Records partial or full compensation
    mutating func recordCompensation(minutes: Int, date: Date) {
        compensatedMinutes = min(compensatedMinutes + minutes, lostMinutes)
        compensationDate = date
        isFullyCompensated = compensatedMinutes >= lostMinutes
    }
}
