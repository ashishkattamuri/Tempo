import Foundation

/// App-wide constants for Tempo
enum Constants {
    // MARK: - Time Boundaries

    /// Evening starts at this hour (24-hour format)
    static let eveningStartHour = 18 // 6 PM

    /// Day ends at this hour for scheduling purposes
    static let dayEndHour = 23 // 11 PM

    /// Morning starts at this hour
    static let morningStartHour = 6 // 6 AM

    /// Work day typically starts
    static let workDayStartHour = 9 // 9 AM

    /// Work day typically ends
    static let workDayEndHour = 17 // 5 PM

    // MARK: - Task Defaults

    /// Default task duration in minutes
    static let defaultTaskDurationMinutes = 30

    /// Minimum task duration in minutes
    static let minimumTaskDurationMinutes = 5

    /// Maximum task duration in minutes
    static let maximumTaskDurationMinutes = 480 // 8 hours

    /// Default minimum duration for identity habits (in minutes)
    static let defaultIdentityHabitMinimumMinutes = 10

    // MARK: - UI Constants

    /// Minimum tap target size (accessibility)
    static let minimumTapTargetSize: CGFloat = 44

    /// Standard corner radius
    static let cornerRadius: CGFloat = 12

    /// Standard padding
    static let standardPadding: CGFloat = 16

    /// Small padding
    static let smallPadding: CGFloat = 8

    // MARK: - Time Slot Settings

    /// Time slot granularity in minutes
    static let timeSlotGranularityMinutes = 15

    /// Buffer between tasks in minutes
    static let taskBufferMinutes = 5

    // MARK: - Approved Language

    /// Words that should NEVER appear in the UI
    static let forbiddenWords = [
        "missed",
        "skipped",
        "failed",
        "behind schedule",
        "late",
        "overdue",
        "incomplete"
    ]

    /// Approved alternatives for common negative situations
    static let approvedLanguage: [String: String] = [
        "missed": "adjusted",
        "skipped": "deferred",
        "failed": "rescheduled",
        "behind schedule": "adjusted timeline",
        "late": "shifted",
        "overdue": "carried forward",
        "incomplete": "in progress"
    ]

    // MARK: - Compassionate Messages

    /// Encouraging messages for different situations
    enum CompassionateMessage {
        static let dayAdjusted = "Your day has been adjusted. Showing up in any form counts."
        static let habitCompressed = "Your habit is protected, just in a smaller form today."
        static let taskDeferred = "This can wait. Today's priorities come first."
        static let fullDayDisruption = "Some days are harder. You're still showing up."
        static let onTrack = "You're on track. Keep going!"
    }
}
