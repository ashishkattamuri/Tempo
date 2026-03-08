import Foundation
import DeviceActivity
import FamilyControls
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
    func scheduleBlocking(for task: ScheduleItem) {
        guard let groupIdStr = task.focusGroupIdRaw,
              let groupId = UUID(uuidString: groupIdStr),
              groups.first(where: { $0.id == groupId }) != nil else { return }

        guard task.startTime > Date() else { return }

        let activityName = DeviceActivityName("focus-\(task.id.uuidString)")
        saveActivityMapping(activityName: activityName.rawValue, groupId: groupId)

        let cal = Calendar.current
        let startComps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: task.startTime)
        let endComps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: task.endTime)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: endComps,
            repeats: false
        )

        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(activityName, during: schedule)
        } catch {
            print("FocusBlockManager: Failed to schedule blocking: \(error)")
        }
    }

    /// Stop DeviceActivity blocking for a task.
    func cancelBlocking(for task: ScheduleItem) {
        let activityName = DeviceActivityName("focus-\(task.id.uuidString)")
        DeviceActivityCenter().stopMonitoring([activityName])
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
