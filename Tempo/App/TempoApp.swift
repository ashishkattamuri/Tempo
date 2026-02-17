import SwiftUI
import SwiftData
import UserNotifications

/// Main entry point for the Tempo app.
/// Configures SwiftData ModelContainer and sets up the root view.
@main
struct TempoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    /// Shared model container for SwiftData persistence
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ScheduleItem.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// Shared sleep manager for sleep schedule integration
    @StateObject private var sleepManager = SleepManager()

    /// Shared compensation tracker for makeup sessions
    @StateObject private var compensationTracker = CompensationTracker()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sleepManager)
                .environmentObject(compensationTracker)
                .onAppear {
                    setupNotifications()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func setupNotifications() {
        // Setup notification categories
        NotificationService.shared.setupNotificationCategories()

        // Request notification permission
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }
    }
}

// MARK: - App Delegate for Notification Handling

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Handle notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        switch actionIdentifier {
        case "SCHEDULE_COMPENSATION":
            // User wants to schedule compensation - app will handle this via deep link
            NotificationCenter.default.post(
                name: Notification.Name("OpenCompensationView"),
                object: nil,
                userInfo: userInfo
            )

        case "VIEW_TASK":
            // User wants to view a deferred task
            if let taskIdString = userInfo["taskId"] as? String {
                NotificationCenter.default.post(
                    name: Notification.Name("OpenTask"),
                    object: nil,
                    userInfo: ["taskId": taskIdString]
                )
            }

        case "PLAN_WEEKEND":
            // User wants to plan weekend compensation
            NotificationCenter.default.post(
                name: Notification.Name("OpenCompensationView"),
                object: nil
            )

        case "START_TASK":
            // User wants to start a task immediately
            if let taskIdString = userInfo["taskId"] as? String {
                NotificationCenter.default.post(
                    name: Notification.Name("OpenTask"),
                    object: nil,
                    userInfo: ["taskId": taskIdString]
                )
            }

        case "SNOOZE_REMINDER":
            // Reschedule the reminder for 5 minutes later
            if let taskIdString = userInfo["taskId"] as? String,
               let taskTitle = userInfo["taskTitle"] as? String {
                let content = UNMutableNotificationContent()
                content.title = "Coming up: \(taskTitle)"
                content.body = "Starting now!"
                content.sound = .default
                content.categoryIdentifier = "TASK_REMINDER"
                content.userInfo = userInfo

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "reminder-snooze-\(taskIdString)",
                    content: content,
                    trigger: trigger
                )

                UNUserNotificationCenter.current().add(request)
            }

        default:
            // Default action - user tapped the notification
            break
        }

        completionHandler()
    }
}
