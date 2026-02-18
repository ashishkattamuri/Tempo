import SwiftUI

/// Frequency options for recurring tasks
enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case daily = "daily"
    case weekly = "weekly"

    var id: String { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }

    /// Description for the frequency picker
    var description: String {
        switch self {
        case .daily:
            return "Every day - compress or skip if day is full"
        case .weekly:
            return "X times per week - can move to next available day"
        }
    }
}
