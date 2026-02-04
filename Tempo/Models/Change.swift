import Foundation

/// Represents a single change action proposed by the reshuffle engine.
/// Uses approved language only - never "missed", "skipped", "failed", or "behind schedule".
struct Change: Identifiable, Equatable {
    let id: UUID
    let item: ScheduleItem
    let action: ChangeAction
    let reason: String

    init(id: UUID = UUID(), item: ScheduleItem, action: ChangeAction, reason: String) {
        self.id = id
        self.item = item
        self.action = action
        self.reason = reason
    }

    /// The type of change being proposed
    enum ChangeAction: Equatable {
        /// Task is protected and kept as-is
        case protected

        /// Task duration is compressed to minimum
        case resized(newDurationMinutes: Int)

        /// Task is moved to a new time slot
        case moved(newStartTime: Date)

        /// Task is moved to a new time and resized
        case movedAndResized(newStartTime: Date, newDurationMinutes: Int)

        /// Task is deferred to another day
        case deferred(newDate: Date)

        /// Task is added to the flexible pool for later scheduling
        case pooled

        /// Task requires user decision (for non-negotiables)
        case requiresUserDecision(options: [UserOption])

        var displayName: String {
            switch self {
            case .protected:
                return "Protected"
            case .resized:
                return "Adjusted"
            case .moved:
                return "Moved"
            case .movedAndResized:
                return "Adjusted & Moved"
            case .deferred:
                return "Deferred"
            case .pooled:
                return "Pooled"
            case .requiresUserDecision:
                return "Needs Your Input"
            }
        }
    }

    /// Options presented to user for non-negotiable conflicts
    struct UserOption: Identifiable, Equatable {
        let id: UUID
        let title: String
        let description: String
        let action: () -> Void

        init(id: UUID = UUID(), title: String, description: String, action: @escaping () -> Void = {}) {
            self.id = id
            self.title = title
            self.description = description
            self.action = action
        }

        static func == (lhs: UserOption, rhs: UserOption) -> Bool {
            lhs.id == rhs.id
        }
    }
}

// MARK: - Display Helpers

extension Change {
    /// User-friendly summary of this change using approved language
    var summary: String {
        switch action {
        case .protected:
            return "\"\(item.title)\" is protected"
        case .resized(let newDuration):
            let saved = item.durationMinutes - newDuration
            return "\"\(item.title)\" adjusted to \(newDuration) min (saved \(saved) min)"
        case .moved(let newTime):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "\"\(item.title)\" moved to \(formatter.string(from: newTime))"
        case .movedAndResized(let newTime, let newDuration):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let saved = item.durationMinutes - newDuration
            return "\"\(item.title)\" adjusted to \(newDuration) min and moved to \(formatter.string(from: newTime)) (saved \(saved) min)"
        case .deferred(let newDate):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\"\(item.title)\" deferred to \(formatter.string(from: newDate))"
        case .pooled:
            return "\"\(item.title)\" added to flexible pool"
        case .requiresUserDecision:
            return "\"\(item.title)\" needs your decision"
        }
    }

    /// Icon name for this change type
    var iconName: String {
        switch action {
        case .protected:
            return "shield.fill"
        case .resized:
            return "arrow.down.right.and.arrow.up.left"
        case .moved:
            return "arrow.right"
        case .movedAndResized:
            return "arrow.up.right"
        case .deferred:
            return "calendar.badge.clock"
        case .pooled:
            return "tray.fill"
        case .requiresUserDecision:
            return "questionmark.circle.fill"
        }
    }
}

// MARK: - Hashable

extension Change: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
