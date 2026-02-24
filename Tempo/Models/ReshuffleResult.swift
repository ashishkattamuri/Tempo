import Foundation

/// The output of the reshuffle engine containing all proposed changes and summary.
struct ReshuffleResult: Equatable {
    /// All proposed changes organized by type
    let changes: [Change]

    /// Human-readable summary using approved language
    let summary: String

    /// Whether user consent is required for any changes
    var requiresUserConsent: Bool {
        changes.contains { change in
            if case .requiresUserDecision = change.action {
                return true
            }
            return false
        }
    }

    /// Total time saved in minutes through compression
    var timeSavedMinutes: Int {
        changes.reduce(0) { total, change in
            switch change.action {
            case .resized(let newDuration):
                return total + (change.item.durationMinutes - newDuration)
            case .movedAndResized(_, let newDuration):
                return total + (change.item.durationMinutes - newDuration)
            default:
                return total
            }
        }
    }

    /// Number of items protected
    var protectedCount: Int {
        changes.filter { change in
            if case .protected = change.action { return true }
            return false
        }.count
    }

    /// Number of items resized
    var resizedCount: Int {
        changes.filter { change in
            switch change.action {
            case .resized, .movedAndResized: return true
            default: return false
            }
        }.count
    }

    /// Number of items moved
    var movedCount: Int {
        changes.filter { change in
            switch change.action {
            case .moved, .movedAndResized: return true
            default: return false
            }
        }.count
    }

    /// Number of items deferred
    var deferredCount: Int {
        changes.filter { change in
            if case .deferred = change.action { return true }
            return false
        }.count
    }

    /// Items requiring user decision
    var itemsRequiringDecision: [Change] {
        changes.filter { change in
            if case .requiresUserDecision = change.action { return true }
            return false
        }
    }

    // MARK: - Grouped Changes

    var protectedChanges: [Change] {
        changes.filter { if case .protected = $0.action { return true }; return false }
    }

    var resizedChanges: [Change] {
        changes.filter {
            switch $0.action {
            case .resized, .movedAndResized: return true
            default: return false
            }
        }
    }

    var movedChanges: [Change] {
        changes.filter {
            switch $0.action {
            case .moved, .movedAndResized: return true
            default: return false
            }
        }
    }

    var deferredChanges: [Change] {
        changes.filter { if case .deferred = $0.action { return true }; return false }
    }

    var pooledChanges: [Change] {
        changes.filter { if case .pooled = $0.action { return true }; return false }
    }

    // MARK: - Factory Methods

    static var empty: ReshuffleResult {
        ReshuffleResult(
            changes: [],
            summary: "Your schedule looks good! No adjustments needed."
        )
    }

    static func onTrack(protectedItems: [Change]) -> ReshuffleResult {
        ReshuffleResult(
            changes: protectedItems,
            summary: "You're on track. All items protected."
        )
    }
}

// MARK: - Hashable

extension ReshuffleResult: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(changes)
        hasher.combine(summary)
    }
}
