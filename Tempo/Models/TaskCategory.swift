import SwiftUI

/// The four task categories in Tempo, ordered by priority for reshuffle decisions.
/// Higher priority categories are protected more aggressively.
enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case nonNegotiable = "non_negotiable"
    case identityHabit = "identity_habit"
    case flexibleTask = "flexible_task"
    case optionalGoal = "optional_goal"

    var id: String { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .nonNegotiable: return "Non-Negotiable"
        case .identityHabit: return "Identity Habit"
        case .flexibleTask: return "Flexible Task"
        case .optionalGoal: return "Optional Goal"
        }
    }

    /// Short description for the category picker
    var description: String {
        switch self {
        case .nonNegotiable:
            return "Must happen at this exact time (meetings, appointments)"
        case .identityHabit:
            return "Defines who you are - can be compressed but never removed"
        case .flexibleTask:
            return "Important work that can be moved or pooled"
        case .optionalGoal:
            return "Nice-to-have - first to be deferred on hard days"
        }
    }

    /// Primary color for visual identification
    var color: Color {
        switch self {
        case .nonNegotiable: return .red
        case .identityHabit: return .purple
        case .flexibleTask: return .blue
        case .optionalGoal: return .green
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .nonNegotiable: return "lock.fill"
        case .identityHabit: return "heart.fill"
        case .flexibleTask: return "arrow.left.arrow.right"
        case .optionalGoal: return "star"
        }
    }

    /// Priority level (lower number = higher priority)
    var priority: Int {
        switch self {
        case .nonNegotiable: return 0
        case .identityHabit: return 1
        case .flexibleTask: return 2
        case .optionalGoal: return 3
        }
    }

    /// Whether this category can be compressed to a minimum duration
    var canCompress: Bool {
        switch self {
        case .nonNegotiable: return false
        case .identityHabit: return true
        case .flexibleTask: return false
        case .optionalGoal: return false
        }
    }

    /// Whether this category can be moved to a different time
    var canMove: Bool {
        switch self {
        case .nonNegotiable: return false // Requires user consent
        case .identityHabit: return true
        case .flexibleTask: return true
        case .optionalGoal: return true
        }
    }

    /// Whether this category can be deferred to another day
    var canDefer: Bool {
        switch self {
        case .nonNegotiable: return false // Requires user consent
        case .identityHabit: return false // Never removed, only compressed
        case .flexibleTask: return true
        case .optionalGoal: return true
        }
    }
}
