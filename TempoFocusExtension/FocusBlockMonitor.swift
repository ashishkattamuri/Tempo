import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

// MARK: - FocusGroup (mirrored from main app for JSON compatibility)

private struct FocusGroup: Codable {
    let id: UUID
    var name: String
    var symbol: String
    var selection: FamilyActivitySelection
}

// MARK: - DeviceActivityMonitor

/// Background extension that applies and removes ManagedSettings shields
/// when a DeviceActivity interval starts and ends.
class FocusBlockMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()
    private let defaults = UserDefaults(suiteName: "group.com.scheduler.tempo")!

    private var activityMapping: [String: String] {
        guard let data = defaults.data(forKey: "focusActivityMapping"),
              let mapping = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return mapping
    }

    private func loadGroup(id: UUID) -> FocusGroup? {
        guard let data = defaults.data(forKey: "focusGroups"),
              let groups = try? JSONDecoder().decode([FocusGroup].self, from: data) else { return nil }
        return groups.first { $0.id == id }
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard let groupIdStr = activityMapping[activity.rawValue],
              let groupId = UUID(uuidString: groupIdStr),
              let group = loadGroup(id: groupId) else {
            print("FocusBlockMonitor: No group found for activity \(activity.rawValue)")
            return
        }

        let selection = group.selection

        // applicationTokens is the correct type for ManagedSettings.shield.applications.
        // On iOS 18+, FamilyActivitySelection also exposes .applications (Set<Application>)
        // but shield.applications still expects Set<ApplicationToken>, so we use .applicationTokens.
        let appTokens = selection.applicationTokens
        let catTokens = selection.categoryTokens

        if !appTokens.isEmpty {
            store.shield.applications = appTokens
            print("FocusBlockMonitor: Shielding \(appTokens.count) apps")
        }
        if !catTokens.isEmpty {
            store.shield.applicationCategories = .specific(catTokens)
            print("FocusBlockMonitor: Shielding \(catTokens.count) categories")
        }
        if appTokens.isEmpty && catTokens.isEmpty {
            print("FocusBlockMonitor: Warning — selection has no tokens. Check FamilyControls authorization.")
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.clearAllSettings()
    }
}
