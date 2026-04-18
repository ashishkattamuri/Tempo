import ManagedSettings
import ManagedSettingsUI
import UIKit

final class TempoShieldConfiguration: ShieldConfigurationDataSource {

    private let defaults = UserDefaults(suiteName: "group.com.scheduler.tempo")
    private let activeTaskTitleKey   = "activeShieldTaskTitle"
    private let activeShieldEndTimeKey = "activeShieldEndTime"
    private let initTimestampKey         = "shieldExtension.initTimestamp"
    private let lastInvocationTimestampKey = "shieldExtension.lastInvocationTimestamp"
    private let lastInvocationKindKey    = "shieldExtension.lastInvocationKind"
    private let lastInvocationTargetKey  = "shieldExtension.lastInvocationTarget"

    // MARK: - Colors (match design)

    /// Dark navy background — #0D1B2A
    private let backgroundColour = UIColor(red: 0.05, green: 0.11, blue: 0.16, alpha: 1)
    /// Bright blue accent — matches iOS blue, used for "not now." and remaining time
    private let accentBlue = UIColor(red: 0.16, green: 0.52, blue: 0.95, alpha: 1)
    /// Off-white for primary text
    private let primaryWhite = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
    /// Muted secondary text
    private let secondaryGrey = UIColor(red: 0.55, green: 0.60, blue: 0.65, alpha: 1)

    // MARK: - Init

    override init() {
        super.init()
        defaults?.set(Date().timeIntervalSince1970, forKey: initTimestampKey)
        defaults?.set("initialized", forKey: lastInvocationKindKey)
    }

    // MARK: - ShieldConfigurationDataSource

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        recordInvocation(kind: "application", target: application.localizedDisplayName)
        return makeShield()
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        recordInvocation(kind: "application-category", target: application.localizedDisplayName)
        return makeShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        recordInvocation(kind: "webDomain", target: webDomain.domain)
        return makeShield()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        recordInvocation(kind: "webDomain-category", target: webDomain.domain)
        return makeShield()
    }

    // MARK: - Shield Builder

    private func makeShield() -> ShieldConfiguration {
        let taskTitle = defaults?.string(forKey: activeTaskTitleKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let endTimestamp = defaults?.double(forKey: activeShieldEndTimeKey) ?? 0
        let endDate = endTimestamp > 0 ? Date(timeIntervalSince1970: endTimestamp) : nil

        // ── Title ───────────────────────────────────────────────────────────
        // "You told yourself not now."
        // Note: ShieldConfiguration.Label only accepts a single colour, so the
        // accent on "not now." is not possible here — both lines are white.
        let titleText = "You told yourself not now."

        // ── Subtitle ─────────────────────────────────────────────────────────
        // FOCUS BLOCK ACTIVE
        // {task name}
        // Ends {HH:mm}  ·  {N}m remaining
        let subtitle = buildSubtitle(taskTitle: taskTitle, endDate: endDate)

        return ShieldConfiguration(
            backgroundColor: backgroundColour,
            title: ShieldConfiguration.Label(text: titleText, color: primaryWhite),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: secondaryGrey),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Back to focus", color: primaryWhite),
            primaryButtonBackgroundColor: UIColor(red: 0.12, green: 0.18, blue: 0.24, alpha: 1)
        )
    }

    // MARK: - Helpers

    private func buildSubtitle(taskTitle: String?, endDate: Date?) -> String {
        var lines: [String] = []

        lines.append("● FOCUS BLOCK ACTIVE")

        if let task = taskTitle, !task.isEmpty {
            lines.append("")
            lines.append(task)
        }

        if let end = endDate {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            let endStr = tf.string(from: end)

            let remaining = max(0, Int(end.timeIntervalSinceNow / 60))
            let remainingStr = remaining > 0 ? "\(remaining)m remaining" : "ending now"

            lines.append("")
            lines.append("Ends \(endStr)  ·  \(remainingStr)")
        }

        return lines.joined(separator: "\n")
    }

    private func recordInvocation(kind: String, target: String?) {
        defaults?.set(Date().timeIntervalSince1970, forKey: lastInvocationTimestampKey)
        defaults?.set(kind, forKey: lastInvocationKindKey)
        defaults?.set(target, forKey: lastInvocationTargetKey)
    }
}
