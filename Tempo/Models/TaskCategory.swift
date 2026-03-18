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
        case .nonNegotiable: return "Event"
        case .identityHabit: return "Habit"
        case .flexibleTask: return "Task"
        case .optionalGoal: return "Goal"
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
        case .nonNegotiable: return Color(red: 0.82, green: 0.30, blue: 0.34) // muted rose
        case .identityHabit: return Color(red: 0.54, green: 0.35, blue: 0.74) // soft violet
        case .flexibleTask:  return Color(red: 0.24, green: 0.52, blue: 0.82) // cornflower blue
        case .optionalGoal:  return Color(red: 0.20, green: 0.65, blue: 0.48) // sage green
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
