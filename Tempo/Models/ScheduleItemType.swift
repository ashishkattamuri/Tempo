import SwiftUI

/// The four user-facing block types shown in the task creation type picker.
/// Maps to the underlying TaskCategory engine values.
enum ScheduleItemType: String, CaseIterable, Identifiable {
    case event
    case task
    case habit
    case goal

    var id: String { rawValue }

    /// User-facing display name
    var displayName: String {
        switch self {
        case .event:  return "Event"
        case .task:   return "Task"
        case .habit:  return "Habit"
        case .goal:   return "Goal"
        }
    }

    /// Maps to the underlying reshuffle engine category
    var taskCategory: TaskCategory {
        switch self {
        case .event:  return .nonNegotiable
        case .task:   return .flexibleTask
        case .habit:  return .identityHabit
        case .goal:   return .optionalGoal
        }
    }

    /// SF Symbol icon
    var iconName: String {
        switch self {
        case .event:  return "lock.fill"
        case .task:   return "arrow.left.arrow.right"
        case .habit:  return "heart.fill"
        case .goal:   return "star.fill"
        }
    }

    /// Primary color
    var color: Color {
        switch self {
        case .event:  return Color(red: 0.82, green: 0.30, blue: 0.34) // muted rose
        case .task:   return Color(red: 0.24, green: 0.52, blue: 0.82) // cornflower blue
        case .habit:  return Color(red: 0.54, green: 0.35, blue: 0.74) // soft violet
        case .goal:   return Color(red: 0.20, green: 0.65, blue: 0.48) // sage green
        }
    }

    /// Initialise from a TaskCategory (for editing existing items)
    init(from category: TaskCategory) {
        switch category {
        case .nonNegotiable: self = .event
        case .flexibleTask:  self = .task
        case .identityHabit: self = .habit
        case .optionalGoal:  self = .goal
        }
    }
}
