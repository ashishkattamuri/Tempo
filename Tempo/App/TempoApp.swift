import SwiftUI
import SwiftData
import UserNotifications

/// Main entry point for the Tempo app.
/// Configures SwiftData ModelContainer and sets up the root view.
@main
struct TempoApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Appearance

    @AppStorage("appAppearance") private var appAppearanceRaw: String = AppAppearance.system.rawValue

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRaw) ?? .system
    }

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

    /// Timer that fires every 30 seconds to check for task transitions and update Live Activity
    private let liveActivityTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sleepManager)
                .environmentObject(compensationTracker)
                .preferredColorScheme(selectedAppearance.colorScheme)
                .onAppear {
                    setupNotifications()
                }
                // Every 30s, notify ScheduleViewModel to re-check the active task
                .onReceive(liveActivityTimer) { _ in
                    NotificationCenter.default.post(
                        name: Notification.Name("CheckLiveActivity"),
                        object: nil
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func setupNotifications() {
        NotificationService.shared.setupNotificationCategories()

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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        switch actionIdentifier {

        case "SCHEDULE_COMPENSATION":
            NotificationCenter.default.post(
                name: Notification.Name("OpenCompensationView"),
                object: nil,
                userInfo: userInfo
            )

        case "VIEW_TASK":
            if let taskIdString = userInfo["taskId"] as? String {
                NotificationCenter.default.post(
                    name: Notification.Name("OpenTask"),
                    object: nil,
                    userInfo: ["taskId": taskIdString]
                )
            }

        case "PLAN_WEEKEND":
            NotificationCenter.default.post(
                name: Notification.Name("OpenCompensationView"),
                object: nil
            )

        case "START_TASK":
            if let taskIdString = userInfo["taskId"] as? String {
                NotificationCenter.default.post(
                    name: Notification.Name("OpenTask"),
                    object: nil,
                    userInfo: ["taskId": taskIdString]
                )
            }

        case "SNOOZE_REMINDER":
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
            break
        }

        completionHandler()
    }
}