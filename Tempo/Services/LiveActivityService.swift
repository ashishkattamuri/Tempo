import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private init() {}

    private var currentActivity: Activity<TaskLiveActivityAttributes>?

    func startActivity(for task: ScheduleItem) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endCurrentActivity()

        let attributes = TaskLiveActivityAttributes(taskId: task.id.uuidString)
        let contentState = TaskLiveActivityAttributes.ContentState(
            taskTitle: task.title,
            categoryRawValue: task.categoryRawValue,
            endTime: task.endTime,
            totalDurationMinutes: task.durationMinutes
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: task.endTime),
                pushType: nil
            )
        } catch {
            print("LiveActivity start error: \(error)")
        }
    }

    func updateActivity(for task: ScheduleItem) {
        guard let activity = currentActivity,
              activity.attributes.taskId == task.id.uuidString else { return }

        let newState = TaskLiveActivityAttributes.ContentState(
            taskTitle: task.title,
            categoryRawValue: task.categoryRawValue,
            endTime: task.endTime,
            totalDurationMinutes: task.durationMinutes
        )
        Task {
            await activity.update(.init(state: newState, staleDate: task.endTime))
        }
    }

    func endActivity(for task: ScheduleItem) {
        guard let activity = currentActivity,
              activity.attributes.taskId == task.id.uuidString else { return }
        endCurrentActivity()
    }

    func endCurrentActivity() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }

    func checkAndUpdateLiveActivity(for items: [ScheduleItem]) {
        let now = Date()
        let activeTask = items
            .filter { !$0.isCompleted && $0.startTime <= now && $0.endTime > now }
            .max(by: { $0.startTime < $1.startTime }) // most recently started wins

        if let activeTask {
            startActivity(for: activeTask)
        } else {
            endCurrentActivity()
        }
    }
}