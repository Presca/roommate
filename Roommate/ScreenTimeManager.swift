import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import UserNotifications

/// Thin wrapper around Apple's Screen Time API.
enum ScreenTimeManager {

    static var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    static func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    static func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .timeSensitive])
    }

    /// Registers tonight's (repeating) bedtime window plus the "you kept
    /// using your phone for another 15 minutes" events that bring her back.
    static func startMonitoring(mood: MoodStore) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([RoommateConfig.bedtimeActivity])

        let schedule = DeviceActivitySchedule(
            intervalStart: mood.bedtime,
            intervalEnd: mood.wakeTime,
            repeats: true
        )

        let sel = mood.selection
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        let hasSelection = !(sel.applicationTokens.isEmpty
                             && sel.categoryTokens.isEmpty
                             && sel.webDomainTokens.isEmpty)
        if hasSelection {
            for step in 1...RoommateConfig.escalationSteps {
                events[.disturbed(step)] = DeviceActivityEvent(
                    applications: sel.applicationTokens,
                    categories: sel.categoryTokens,
                    webDomains: sel.webDomainTokens,
                    threshold: DateComponents(minute: RoommateConfig.escalationMinutes * step)
                )
            }
        }

        try center.startMonitoring(RoommateConfig.bedtimeActivity, during: schedule, events: events)

        // `intervalDidStart` does not fire for a window that is already in
        // progress, so if it's bedtime right now, wake her up ourselves.
        if mood.isBedtime() {
            if mood.stage == .none { mood.nightStarted() }
            Shielding.apply(using: mood)
        } else {
            Shielding.clear()
        }
    }

    static func stopMonitoring(mood: MoodStore) {
        DeviceActivityCenter().stopMonitoring([RoommateConfig.bedtimeActivity])
        Shielding.clear()
        RoommateNotifier.clearAll()
        mood.stage = .none
        mood.pendingVisitStage = nil
    }
}
