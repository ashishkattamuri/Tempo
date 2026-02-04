import Foundation

/// Processor for non-negotiable items.
/// These items ALWAYS require user consent to modify.
/// They cannot be automatically moved, compressed, or deferred.
struct NonNegotiableProcessor: CategoryProcessor {
    let category: TaskCategory = .nonNegotiable

    func process(item: ScheduleItem, context: ReshuffleContext) -> Change {
        // Check if this item has a conflict with other non-negotiables
        let conflicts = findConflicts(for: item, in: context)

        if conflicts.isEmpty {
            // No conflicts - item is protected
            return Change(
                item: item,
                action: .protected,
                reason: "Non-negotiable items are always protected"
            )
        }

        // Has conflicts - need user decision
        let options = buildUserOptions(for: item, conflicts: conflicts, context: context)
        return Change(
            item: item,
            action: .requiresUserDecision(options: options),
            reason: "This non-negotiable overlaps with: \(conflicts.map { $0.title }.joined(separator: ", "))"
        )
    }

    // MARK: - Private

    private func findConflicts(for item: ScheduleItem, in context: ReshuffleContext) -> [ScheduleItem] {
        context.allItems.filter { other in
            other.id != item.id &&
            item.overlaps(with: other) &&
            !other.isCompleted
        }
    }

    private func buildUserOptions(
        for item: ScheduleItem,
        conflicts: [ScheduleItem],
        context: ReshuffleContext
    ) -> [Change.UserOption] {
        var options: [Change.UserOption] = []

        // Option 1: Keep this item, adjust the conflicting items
        options.append(Change.UserOption(
            title: "Keep \"\(item.title)\"",
            description: "Adjust or move the conflicting items instead"
        ))

        // Option 2: Move this item if there's an available slot
        if let slot = context.findSlot(forDurationMinutes: item.durationMinutes, after: item.endTime) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            options.append(Change.UserOption(
                title: "Move to \(formatter.string(from: slot.start))",
                description: "Move \"\(item.title)\" to an available time slot"
            ))
        }

        // Option 3: Defer to tomorrow
        options.append(Change.UserOption(
            title: "Defer to tomorrow",
            description: "Move \"\(item.title)\" to tomorrow's schedule"
        ))

        return options
    }
}
