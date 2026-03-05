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
              let group = loadGroup(id: groupId) else { return }

        let selection = group.selection
        // Use token-based API (iOS 16–17); applicationTokens/categoryTokens deprecated in iOS 18
        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.clearAllSettings()
    }
}
