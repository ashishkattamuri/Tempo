import ManagedSettings
import ManagedSettingsUI
import UIKit

@objc(TempoShieldConfiguration)
class TempoShieldConfiguration: ShieldConfigurationDataSource {
    private let defaults = UserDefaults(suiteName: "group.com.scheduler.tempo")
    private let activeTaskTitleKey = "activeShieldTaskTitle"

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        tempoShield()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        tempoShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        tempoShield()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        tempoShield()
    }

    private func tempoShield() -> ShieldConfiguration {
        let indigo = UIColor(red: 0.35, green: 0.22, blue: 0.80, alpha: 1.0)
        let taskTitle = defaults?.string(forKey: activeTaskTitleKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitleText = if let taskTitle, !taskTitle.isEmpty {
            "Return to \(taskTitle). This app is blocked during your focus block."
        } else {
            "Stay focused. This app is blocked during your focus block."
        }

        return ShieldConfiguration(
            backgroundColor: indigo,
            title: ShieldConfiguration.Label(text: "You're in focus mode", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitleText, color: UIColor.white.withAlphaComponent(0.75)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "I really need this", color: indigo),
            primaryButtonBackgroundColor: .white
        )
    }
}
