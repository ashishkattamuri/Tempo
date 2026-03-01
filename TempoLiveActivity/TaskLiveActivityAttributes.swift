import ActivityKit
import Foundation

struct TaskLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var taskTitle: String
        var categoryRawValue: String
        var endTime: Date
        var totalDurationMinutes: Int
    }

    var taskId: String
}