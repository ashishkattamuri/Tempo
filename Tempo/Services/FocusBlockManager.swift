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
    private let activeTaskTitleKey   = "activeShieldTaskTitle"
    private let activeShieldEndTimeKey = "activeShieldEndTime"   // TimeInterval since 1970
    private let shieldExtensionInitTimestampKey = "shieldExtension.initTimestamp"
    private let shieldExtensionLastInvocationTimestampKey = "shieldExtension.lastInvocationTimestamp"
    private let shieldExtensionLastInvocationKindKey = "shieldExtension.lastInvocationKind"
    private let shieldExtensionLastInvocationTargetKey = "shieldExtension.lastInvocationTarget"
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
            applyShields(for: group, taskTitle: task.title, endTime: task.endTime)
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
    func applyShields(for group: FocusGroup, taskTitle: String? = nil, endTime: Date? = nil) {
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
        // Store task title + end time so the shield extension can show personalised copy
        defaults.set(taskTitle, forKey: activeTaskTitleKey)
        defaults.set(endTime?.timeIntervalSince1970, forKey: activeShieldEndTimeKey)
        logShieldExtensionDiagnostics(context: "applyShields")
    }

    func clearShields() {
        store.clearAllSettings()
        defaults.removeObject(forKey: activeTaskTitleKey)
        defaults.removeObject(forKey: activeShieldEndTimeKey)
        logShieldExtensionDiagnostics(context: "clearShields")
        print("FocusBlockManager: Cleared all shields")
    }

    /// Sync shields with reality: apply if a focus task is currently active, clear if not.
    /// Call on app foreground to catch both missed intervalDidStart AND missed intervalDidEnd.
    func syncShields(for allTasks: [ScheduleItem]) {
        let now = Date()
        let activeTask = allTasks.first(where: {
            $0.isFocusBlock && !$0.isCompleted && $0.startTime <= now && $0.endTime > now
        })

        if let activeTask,
           let groupIdStr = activeTask.focusGroupIdRaw,
           let groupId = UUID(uuidString: groupIdStr),
           let group = groups.first(where: { $0.id == groupId }) {
            print("FocusBlockManager: Active focus task '\(activeTask.title)' — applying shields")
            applyShields(for: group, taskTitle: activeTask.title, endTime: activeTask.endTime)
        } else {
            // No active focus task — ensure shields are cleared
            print("FocusBlockManager: No active focus task — clearing shields")
            clearShields()
        }

        logShieldExtensionDiagnostics(context: "syncShields")
    }

    // MARK: - Notifications

    func scheduleNotifications(for task: ScheduleItem) {
        NotificationService.shared.scheduleFocusStart(for: task)
        NotificationService.shared.scheduleFocusEnd(for: task)
    }

    func cancelNotifications(for task: ScheduleItem) {
        NotificationService.shared.cancelFocusNotifications(for: task)
    }

    private func logShieldExtensionDiagnostics(context: String) {
        let initTime = defaults.double(forKey: shieldExtensionInitTimestampKey)
        let invokeTime = defaults.double(forKey: shieldExtensionLastInvocationTimestampKey)
        let invokeKind = defaults.string(forKey: shieldExtensionLastInvocationKindKey) ?? "none"
        let invokeTarget = defaults.string(forKey: shieldExtensionLastInvocationTargetKey) ?? "none"

        let initSummary = initTime > 0 ? Date(timeIntervalSince1970: initTime).description : "never"
        let invokeSummary = invokeTime > 0 ? Date(timeIntervalSince1970: invokeTime).description : "never"

        print(
            """
            FocusBlockManager[\(context)]: shield extension diagnostics \
            init=\(initSummary) lastInvocation=\(invokeSummary) \
            kind=\(invokeKind) target=\(invokeTarget)
            """
        )
    }
}
