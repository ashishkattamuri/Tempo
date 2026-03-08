import ManagedSettings
import ManagedSettingsUI
import UIKit

class TempoShieldConfiguration: ShieldConfigurationDataSource {

    private let defaults = UserDefaults(suiteName: "group.com.scheduler.tempo")

    // MARK: - App Shield

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(for: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(for: application.localizedDisplayName)
    }

    // MARK: - Web Domain Shield

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(for: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(for: webDomain.domain)
    }

    // MARK: - Configuration Builder

    private func makeConfiguration(for appName: String?) -> ShieldConfiguration {
        let taskTitle = defaults?.string(forKey: "activeShieldTaskTitle")

        let indigo = UIColor(red: 0.35, green: 0.22, blue: 0.80, alpha: 1.0)
        let softWhite = UIColor.white.withAlphaComponent(0.95)
        let dimWhite = UIColor.white.withAlphaComponent(0.65)

        let title: String
        let subtitle: String

        if let taskTitle {
            title = "You're in focus mode"
            subtitle = "You set aside this time for \"\(taskTitle)\". Finishing strong feels better than a quick distraction."
        } else {
            title = "Stay in your flow"
            subtitle = "You blocked this app to protect your focus. You've got this."
        }

        let icon = UIImage(systemName: "timer",
                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .medium))

        return ShieldConfiguration(
            backgroundColor: indigo,
            icon: icon?.withTintColor(.white, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: title, color: softWhite),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: dimWhite),
            primaryButtonLabel: ShieldConfiguration.Label(text: "I really need this", color: indigo),
            primaryButtonBackgroundColor: .white
        )
    }
}
