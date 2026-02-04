import Foundation

/// Generates user-friendly reshuffle summaries using ONLY approved language.
/// NEVER uses: "missed", "skipped", "failed", "behind schedule"
/// ALWAYS uses: "adjusted", "protected", "resized", "deferred"
struct SummaryGenerator {

    /// Generate a complete summary of the reshuffle result
    func generate(
        changes: [Change],
        eveningDecision: EveningDecision?
    ) -> String {
        var sections: [String] = []

        // Opening message
        sections.append(openingMessage(for: changes))

        // Protected items
        let protected = changes.filter { if case .protected = $0.action { return true }; return false }
        if !protected.isEmpty {
            sections.append(protectedSection(protected))
        }

        // Adjusted (resized) items
        let adjusted = changes.filter {
            switch $0.action {
            case .resized, .movedAndResized: return true
            default: return false
            }
        }
        if !adjusted.isEmpty {
            sections.append(adjustedSection(adjusted))
        }

        // Moved items
        let moved = changes.filter {
            switch $0.action {
            case .moved, .movedAndResized: return true
            default: return false
            }
        }
        if !moved.isEmpty {
            sections.append(movedSection(moved))
        }

        // Deferred items
        let deferred = changes.filter { if case .deferred = $0.action { return true }; return false }
        if !deferred.isEmpty {
            sections.append(deferredSection(deferred))
        }

        // Items needing decision
        let needsDecision = changes.filter { if case .requiresUserDecision = $0.action { return true }; return false }
        if !needsDecision.isEmpty {
            sections.append(decisionSection(needsDecision))
        }

        // Evening protection note
        if let evening = eveningDecision, evening.requiresConsent {
            sections.append(eveningSection(evening))
        }

        // Closing encouragement
        sections.append(closingMessage(for: changes))

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Section Generators

    private func openingMessage(for changes: [Change]) -> String {
        let hasSignificantChanges = changes.contains { change in
            switch change.action {
            case .protected: return false
            default: return true
            }
        }

        if !hasSignificantChanges {
            return "Your schedule is on track."
        }

        return "Your schedule has been adjusted."
    }

    private func protectedSection(_ items: [Change]) -> String {
        if items.count == 1 {
            return "Protected: \"\(items[0].item.title)\""
        }
        let titles = items.prefix(3).map { "\"\($0.item.title)\"" }.joined(separator: ", ")
        if items.count > 3 {
            return "Protected: \(titles) and \(items.count - 3) more"
        }
        return "Protected: \(titles)"
    }

    private func adjustedSection(_ items: [Change]) -> String {
        var lines: [String] = ["Adjusted:"]

        for change in items.prefix(5) {
            switch change.action {
            case .resized(let newDuration):
                let saved = change.item.durationMinutes - newDuration
                lines.append("• \"\(change.item.title)\" → \(newDuration) min (saved \(saved) min)")
            case .movedAndResized(_, let newDuration):
                let saved = change.item.durationMinutes - newDuration
                lines.append("• \"\(change.item.title)\" → \(newDuration) min (saved \(saved) min)")
            default:
                break
            }
        }

        if items.count > 5 {
            lines.append("• ...and \(items.count - 5) more")
        }

        return lines.joined(separator: "\n")
    }

    private func movedSection(_ items: [Change]) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        var lines: [String] = ["Moved:"]

        for change in items.prefix(5) {
            switch change.action {
            case .moved(let newTime):
                lines.append("• \"\(change.item.title)\" → \(formatter.string(from: newTime))")
            case .movedAndResized(let newTime, _):
                lines.append("• \"\(change.item.title)\" → \(formatter.string(from: newTime))")
            default:
                break
            }
        }

        if items.count > 5 {
            lines.append("• ...and \(items.count - 5) more")
        }

        return lines.joined(separator: "\n")
    }

    private func deferredSection(_ items: [Change]) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        var lines: [String] = ["Deferred to another day:"]

        for change in items.prefix(5) {
            if case .deferred(let newDate) = change.action {
                lines.append("• \"\(change.item.title)\" → \(formatter.string(from: newDate))")
            }
        }

        if items.count > 5 {
            lines.append("• ...and \(items.count - 5) more")
        }

        lines.append("These can wait. Today's priorities come first.")

        return lines.joined(separator: "\n")
    }

    private func decisionSection(_ items: [Change]) -> String {
        var lines: [String] = ["Needs your input:"]

        for change in items {
            lines.append("• \"\(change.item.title)\"")
        }

        return lines.joined(separator: "\n")
    }

    private func eveningSection(_ decision: EveningDecision) -> String {
        return "Evening: \(decision.message)"
    }

    private func closingMessage(for changes: [Change]) -> String {
        // Check overall severity
        let deferredCount = changes.filter { if case .deferred = $0.action { return true }; return false }.count
        let adjustedCount = changes.filter {
            switch $0.action {
            case .resized, .movedAndResized: return true
            default: return false
            }
        }.count

        if deferredCount > 3 || adjustedCount > 3 {
            return Constants.CompassionateMessage.fullDayDisruption
        }

        if adjustedCount > 0 {
            return Constants.CompassionateMessage.dayAdjusted
        }

        return Constants.CompassionateMessage.onTrack
    }

    // MARK: - Quick Summaries

    /// Generate a one-line summary for the UI header
    func quickSummary(changes: [Change]) -> String {
        let protected = changes.filter { if case .protected = $0.action { return true }; return false }.count
        let adjusted = changes.filter {
            switch $0.action {
            case .resized, .movedAndResized, .moved: return true
            default: return false
            }
        }.count
        let deferred = changes.filter { if case .deferred = $0.action { return true }; return false }.count

        var parts: [String] = []

        if protected > 0 {
            parts.append("\(protected) protected")
        }
        if adjusted > 0 {
            parts.append("\(adjusted) adjusted")
        }
        if deferred > 0 {
            parts.append("\(deferred) deferred")
        }

        if parts.isEmpty {
            return "No changes needed"
        }

        return parts.joined(separator: ", ")
    }

    /// Validate that a string doesn't contain forbidden language
    func validateLanguage(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return !Constants.forbiddenWords.contains { lowercased.contains($0) }
    }
}
