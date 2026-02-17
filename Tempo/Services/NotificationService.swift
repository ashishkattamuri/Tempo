import Foundation
import UserNotifications

/// Service for scheduling and managing local notifications.
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    // MARK: - Authorization

    /// Request notification permission from the user
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Compensation Notifications

    /// Schedule a reminder for a pending compensation
    func scheduleCompensationReminder(for record: CompensationRecord, suggestedDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Time to make up: \(record.taskTitle)"
        content.body = "You have \(record.remainingMinutes) minutes to catch up on. Would you like to schedule it?"
        content.sound = .default
        content.categoryIdentifier = "COMPENSATION_REMINDER"
        content.userInfo = [
            "recordId": record.id.uuidString,
            "taskTitle": record.taskTitle,
            "minutes": record.remainingMinutes
        ]

        // Schedule for the suggested date, or tomorrow morning if no date given
        let calendar = Calendar.current
        let triggerDate: Date
        if suggestedDate > Date() {
            triggerDate = suggestedDate
        } else {
            // Default to 9 AM tomorrow
            triggerDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date().addingDays(1)) ?? Date().addingDays(1)
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "compensation-\(record.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Notify user when a task is deferred
    func notifyTaskDeferred(task: ScheduleItem, newDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Task rescheduled"
        content.body = "\"\(task.title)\" has been moved to \(formattedDate(newDate))"
        content.sound = .default
        content.categoryIdentifier = "TASK_DEFERRED"
        content.userInfo = [
            "taskId": task.id.uuidString,
            "taskTitle": task.title,
            "newDate": newDate.timeIntervalSince1970
        ]

        // Deliver immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "deferred-\(task.id.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Notify when weekend approaches and there are pending compensations
    func notifyWeekendCompensationAvailable(records: [CompensationRecord]) {
        guard !records.isEmpty else { return }

        let totalMinutes = records.reduce(0) { $0 + $1.remainingMinutes }
        let taskCount = records.count

        let content = UNMutableNotificationContent()
        content.title = "Weekend planning reminder"
        content.body = "You have \(taskCount) task\(taskCount == 1 ? "" : "s") (\(formatMinutes(totalMinutes))) to make up. The weekend is a great time to catch up!"
        content.sound = .default
        content.categoryIdentifier = "WEEKEND_COMPENSATION"
        content.userInfo = [
            "totalMinutes": totalMinutes,
            "taskCount": taskCount
        ]

        // Schedule for Friday at 5 PM
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = 6 // Friday
        components.hour = 17
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "weekend-compensation-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Task Reminders

    /// Schedule a reminder before a task starts
    func scheduleTaskReminder(for task: ScheduleItem, minutesBefore: Int = 15) {
        let content = UNMutableNotificationContent()
        content.title = "Coming up: \(task.title)"
        content.body = "Starts in \(minutesBefore) minutes"
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = [
            "taskId": task.id.uuidString,
            "taskTitle": task.title
        ]

        let triggerDate = task.startTime.addingTimeInterval(-Double(minutesBefore * 60))

        // Don't schedule if the reminder time has already passed
        guard triggerDate > Date() else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "reminder-\(task.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Cancel a task reminder
    func cancelTaskReminder(for taskId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["reminder-\(taskId.uuidString)"]
        )
    }

    // MARK: - Cleanup

    /// Remove all pending notifications
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Remove notifications for a specific category
    func removePendingNotifications(forCategory category: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .filter { $0.content.categoryIdentifier == category }
                .map { $0.identifier }

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins > 0 {
                return "\(hours)h \(mins)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Notification Categories

extension NotificationService {
    /// Setup notification categories with actions
    func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()

        // Compensation reminder category
        let scheduleAction = UNNotificationAction(
            identifier: "SCHEDULE_COMPENSATION",
            title: "Schedule Now",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_COMPENSATION",
            title: "Later",
            options: []
        )
        let compensationCategory = UNNotificationCategory(
            identifier: "COMPENSATION_REMINDER",
            actions: [scheduleAction, dismissAction],
            intentIdentifiers: []
        )

        // Task deferred category
        let viewAction = UNNotificationAction(
            identifier: "VIEW_TASK",
            title: "View",
            options: [.foreground]
        )
        let deferredCategory = UNNotificationCategory(
            identifier: "TASK_DEFERRED",
            actions: [viewAction],
            intentIdentifiers: []
        )

        // Weekend compensation category
        let planAction = UNNotificationAction(
            identifier: "PLAN_WEEKEND",
            title: "Plan Now",
            options: [.foreground]
        )
        let weekendCategory = UNNotificationCategory(
            identifier: "WEEKEND_COMPENSATION",
            actions: [planAction, dismissAction],
            intentIdentifiers: []
        )

        // Task reminder category
        let startAction = UNNotificationAction(
            identifier: "START_TASK",
            title: "Start Now",
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_REMINDER",
            title: "Snooze 5 min",
            options: []
        )
        let reminderCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [startAction, snoozeAction],
            intentIdentifiers: []
        )

        center.setNotificationCategories([
            compensationCategory,
            deferredCategory,
            weekendCategory,
            reminderCategory
        ])
    }
}
