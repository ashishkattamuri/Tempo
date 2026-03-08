import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
import Combine

/// Manages Focus Groups, authorization, and DeviceActivity blocking schedules.
@MainActor
final class FocusBlockManager: ObservableObject {
    static let appGroupId = "group.com.scheduler.tempo"
    static let shared = FocusBlockManager()

    @Published var groups: [FocusGroup] = []
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined

    private let defaults: UserDefaults
    private let groupsKey = "focusGroups"
    private let activityMappingKey = "focusActivityMapping"
    private let store = ManagedSettingsStore()

    init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupId) ?? .standard
        loadGroups()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        } catch {
            print("FocusBlockManager: Authorization failed: \(error)")
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - Group Management

    func saveGroup(_ group: FocusGroup) {
        if let idx = groups.firstIndex(where: { $0.id == group.id }) {
            groups[idx] = group
        } else {
            groups.append(group)
        }
        persistGroups()
    }

    func deleteGroup(_ group: FocusGroup) {
        groups.removeAll { $0.id == group.id }
        persistGroups()
    }

    private func loadGroups() {
        guard let data = defaults.data(forKey: groupsKey),
              let decoded = try? JSONDecoder().decode([FocusGroup].self, from: data) else { return }
        groups = decoded
    }

    private func persistGroups() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        defaults.set(data, forKey: groupsKey)
    }

    // MARK: - Activity Mapping (shared with extension)

    private func saveActivityMapping(activityName: String, groupId: UUID) {
        var mapping = loadActivityMapping()
        mapping[activityName] = groupId.uuidString
        if let data = try? JSONEncoder().encode(mapping) {
            defaults.set(data, forKey: activityMappingKey)
        }
    }

    private func loadActivityMapping() -> [String: String] {
        guard let data = defaults.data(forKey: activityMappingKey),
              let mapping = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return mapping
    }

    // MARK: - Blocking Schedule

    /// Schedule DeviceActivity blocking for a task that has a focus group assigned.
    /// For currently-active tasks, intervalStart is set 3 seconds from now so
    /// DeviceActivity always receives a valid future start (past starts are rejected).
    func scheduleBlocking(for task: ScheduleItem) {
        guard let groupIdStr = task.focusGroupIdRaw,
              let groupId = UUID(uuidString: groupIdStr),
              groups.first(where: { $0.id == groupId }) != nil else { return }

        let now = Date()
        guard task.endTime > now else { return }

        // If task is currently active, apply shields immediately from the main app.
        // The extension will also apply them when DeviceActivity fires, but this is instant.
        if task.startTime <= now, let group = groups.first(where: { $0.id == groupId }) {
            applyShields(for: group)
        }

        let activityName = DeviceActivityName("focus-\(task.id.uuidString)")
        saveActivityMapping(activityName: activityName.rawValue, groupId: groupId)

        let cal = Calendar.current
        // DeviceActivitySchedule requires intervalStart to be in the future.
        // If the task is already active, shift start 3 seconds forward.
        let effectiveStart = task.startTime > now ? task.startTime : now.addingTimeInterval(3)
        let startComps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: effectiveStart)
        let endComps   = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: task.endTime)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: endComps,
            repeats: false
        )

        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(activityName, during: schedule)
            print("FocusBlockManager: Monitoring started for '\(task.title)' start=\(effectiveStart) end=\(task.endTime)")
        } catch {
            print("FocusBlockManager: startMonitoring FAILED — \(error)")
        }
    }

    /// Stop DeviceActivity blocking for a task.
    func cancelBlocking(for task: ScheduleItem) {
        let activityName = DeviceActivityName("focus-\(task.id.uuidString)")
        DeviceActivityCenter().stopMonitoring([activityName])
        clearShields()
    }

    // MARK: - Direct Shielding (main app → ManagedSettingsStore)

    /// Apply shields immediately from the main app.
    /// Used when a focus task is already active at save time so we don't wait for the extension.
    func applyShields(for group: FocusGroup) {
        let selection = group.selection
        let appTokens = selection.applicationTokens
        let catTokens = selection.categoryTokens
        if !appTokens.isEmpty {
            store.shield.applications = appTokens
            print("FocusBlockManager: Applied shields for \(appTokens.count) apps directly")
        }
        if !catTokens.isEmpty {
            store.shield.applicationCategories = .specific(catTokens)
            print("FocusBlockManager: Applied shields for \(catTokens.count) categories directly")
        }
        if appTokens.isEmpty && catTokens.isEmpty {
            print("FocusBlockManager: Warning — no tokens found in selection. Apps may not be blocked.")
        }
    }

    func clearShields() {
        store.clearAllSettings()
        print("FocusBlockManager: Cleared all shields")
    }

    /// Check all tasks and re-apply shields if one is currently active.
    /// Call this on app foreground to cover cases where the extension didn't fire.
    func refreshShieldsIfNeeded(for allTasks: [ScheduleItem]) {
        let now = Date()
        guard let activeTask = allTasks.first(where: {
            $0.isFocusBlock && !$0.isCompleted && $0.startTime <= now && $0.endTime > now
        }) else {
            return
        }
        guard let groupIdStr = activeTask.focusGroupIdRaw,
              let groupId = UUID(uuidString: groupIdStr),
              let group = groups.first(where: { $0.id == groupId }) else { return }

        print("FocusBlockManager: Active focus task '\(activeTask.title)' detected — refreshing shields")
        applyShields(for: group)
    }

    // MARK: - Notifications

    func scheduleNotifications(for task: ScheduleItem) {
        NotificationService.shared.scheduleFocusStart(for: task)
        NotificationService.shared.scheduleFocusEnd(for: task)
    }

    func cancelNotifications(for task: ScheduleItem) {
        NotificationService.shared.cancelFocusNotifications(for: task)
    }
}
