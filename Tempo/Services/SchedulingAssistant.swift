import Foundation
import FoundationModels

/// On-device AI assistant that enhances reshuffle summaries using Apple Intelligence.
/// Requires iOS 26+ with Apple Intelligence enabled. Gracefully returns nil on any
/// failure so the caller always falls back to the rule-based SummaryGenerator.
@available(iOS 26, *)
@MainActor
final class SchedulingAssistant {
    static let shared = SchedulingAssistant()

    private let session: LanguageModelSession?

    private init() {
        guard SystemLanguageModel.default.isAvailable else {
            session = nil
            return
        }
        session = LanguageModelSession(instructions: """
            You are a compassionate scheduling assistant inside a productivity app called Tempo.
            When describing schedule adjustments always use warm, supportive language.
            Forbidden words — never use: missed, failed, behind, skipped, late, overdue, didn't.
            Preferred words — always use: adjusted, moved, deferred, protected, rescheduled.
            Keep responses concise. The user is having a busy day and needs encouragement, not judgment.
            """)
    }

    // MARK: - Structured Output Schema

    @Generable
    struct RescheduleSummary {
        @Guide(description: """
            A warm, compassionate 1-2 sentence explanation of what is being adjusted and why.
            Do NOT use: missed, failed, behind, skipped, late, overdue.
            DO use: adjusted, moved, deferred, rescheduled, protected.
            """)
        var summary: String

        @Guide(description: "A short motivating phrase for the user — max 8 words, no punctuation.")
        var encouragement: String
    }

    // MARK: - Public API

    /// Generate an AI-enhanced summary for the proposed changes.
    /// Returns nil if Apple Intelligence is unavailable or generation fails.
    func enhance(changes: [Change]) async -> RescheduleSummary? {
        guard let session else { return nil }

        let descriptions = changeDescriptions(from: changes)
        guard !descriptions.isEmpty else { return nil }

        let prompt = """
            Here are the schedule adjustments being proposed for today:

            \(descriptions.joined(separator: "\n"))

            Write a compassionate summary and a short encouragement for the user.
            """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: RescheduleSummary.self
            )
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private func changeDescriptions(from changes: [Change]) -> [String] {
        let timeFmt: DateFormatter = {
            let f = DateFormatter()
            f.timeStyle = .short
            return f
        }()
        let dateFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            return f
        }()

        return changes.compactMap { change in
            switch change.action {
            case .protected:
                return nil
            case .moved(let time):
                return "• \"\(change.item.title)\" — rescheduled to \(timeFmt.string(from: time))"
            case .movedAndResized(let time, let mins):
                return "• \"\(change.item.title)\" — shortened to \(mins) min and moved to \(timeFmt.string(from: time))"
            case .resized(let mins):
                return "• \"\(change.item.title)\" — shortened to \(mins) min"
            case .deferred(let date):
                return "• \"\(change.item.title)\" — deferred to \(dateFmt.string(from: date))"
            case .requiresUserDecision:
                return "• \"\(change.item.title)\" — needs a decision from you"
            case .pooled:
                return "• \"\(change.item.title)\" — moved to flexible pool"
            }
        }
    }
}
