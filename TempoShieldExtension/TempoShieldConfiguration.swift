import ManagedSettings
import ManagedSettingsUI
import UIKit

final class TempoShieldConfiguration: ShieldConfigurationDataSource {
    private let defaults = UserDefaults(suiteName: "group.com.scheduler.tempo")
    private let activeTaskTitleKey = "activeShieldTaskTitle"
    private let initTimestampKey = "shieldExtension.initTimestamp"
    private let lastInvocationTimestampKey = "shieldExtension.lastInvocationTimestamp"
    private let lastInvocationKindKey = "shieldExtension.lastInvocationKind"
    private let lastInvocationTargetKey = "shieldExtension.lastInvocationTarget"

    override init() {
        super.init()
        defaults?.set(Date().timeIntervalSince1970, forKey: initTimestampKey)
        defaults?.set("initialized", forKey: lastInvocationKindKey)
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        recordInvocation(kind: "application", target: application.localizedDisplayName)
        return tempoShield(appName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        recordInvocation(kind: "application-category", target: application.localizedDisplayName)
        return tempoShield(appName: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        recordInvocation(kind: "webDomain", target: webDomain.domain)
        return tempoShield(appName: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        recordInvocation(kind: "webDomain-category", target: webDomain.domain)
        return tempoShield(appName: webDomain.domain)
    }

    private func tempoShield(appName: String?) -> ShieldConfiguration {
        let indigo = UIColor(red: 0.35, green: 0.22, blue: 0.80, alpha: 1.0)
        let taskTitle = defaults?.string(forKey: activeTaskTitleKey)?.trimmingCharacters(in: .whitespacesAndNewlines)

        let title = "You're in the zone 🎯"

        let subtitle: String
        if let app = appName, let task = taskTitle, !task.isEmpty {
            subtitle = "\(app) is blocked until \"\(task)\" is done. You scheduled this time — honour it."
        } else if let task = taskTitle, !task.isEmpty {
            subtitle = "This app is blocked until \"\(task)\" is done. One focused session at a time."
        } else if let app = appName {
            subtitle = "\(app) is blocked during your focus session. Stay the course — you've got this."
        } else {
            subtitle = "This app is blocked during your focus session. Stay the course — you've got this."
        }

        return ShieldConfiguration(
            backgroundColor: indigo,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor.white.withAlphaComponent(0.80)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Back to focus", color: indigo),
            primaryButtonBackgroundColor: .white
        )
    }

    private func recordInvocation(kind: String, target: String?) {
        defaults?.set(Date().timeIntervalSince1970, forKey: lastInvocationTimestampKey)
        defaults?.set(kind, forKey: lastInvocationKindKey)
        defaults?.set(target, forKey: lastInvocationTargetKey)
    }
}
