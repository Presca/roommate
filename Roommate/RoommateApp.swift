import SwiftUI
import UserNotifications

@main
struct RoommateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = RoommateModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FontLoader.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(model)
                .onOpenURL { model.handle(url: $0) }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { model.refresh() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .roommateVisitRequested)) { note in
                    if let stage = note.object as? Stage {
                        model.visit = VisitRequest(stage: stage, isPreview: false)
                    }
                }
                .fullScreenCover(item: $model.visit) { visit in
                    VisitSceneView(stage: visit.stage, isPreview: visit.isPreview)
                        .environmentObject(model)
                }
        }
    }
}

extension Notification.Name {
    static let roommateVisitRequested = Notification.Name("roommate.visitRequested")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Tapping "roommate is awake 😴" opens straight into her visit.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let raw = info[RoommateNotifier.stageKey] as? Int, let stage = Stage(rawValue: raw) {
            MoodStore.shared.pendingVisitStage = stage
            NotificationCenter.default.post(name: .roommateVisitRequested, object: stage)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
