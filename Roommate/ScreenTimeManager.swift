import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import UserNotifications

/// Thin wrapper around Apple's Screen Time API.
///
/// In the DEMO build (free developer account: no Family Controls, no
/// extensions) the same calls fall through to `DemoScheduler`, which fakes
/// her visits with plain local notifications instead of blocking apps.
enum ScreenTimeManager {

    static var isAuthorized: Bool {
        #if DEMO
        return true
        #else
        return AuthorizationCenter.shared.authorizationStatus == .approved
        #endif
    }

    static func requestAuthorization() async throws {
        #if DEMO
        return
        #else
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        #endif
    }

    static func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .timeSensitive])
    }

    /// Registers tonight's (repeating) bedtime window plus the "you kept
    /// using your phone for another 15 minutes" events that bring her back.
    static func startMonitoring(mood: MoodStore) throws {
        #if DEMO
        DemoScheduler.schedule(mood: mood)
        DemoScheduler.handleForeground(mood: mood)
        return
        #else
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
        #endif
    }

    static func stopMonitoring(mood: MoodStore) {
        #if DEMO
        DemoScheduler.cancelAll()
        #else
        DeviceActivityCenter().stopMonitoring([RoommateConfig.bedtimeActivity])
        Shielding.clear()
        RoommateNotifier.clearAll()
        #endif
        mood.stage = .none
        mood.pendingVisitStage = nil
    }

    // MARK: hooks the app calls; only the demo needs them

    /// App came to the foreground.
    static func handleForeground(mood: MoodStore) {
        #if DEMO
        DemoScheduler.handleForeground(mood: mood)
        #endif
    }

    /// You tapped one of her notifications.
    static func noteNotificationTapped(stage: Stage, mood: MoodStore) {
        #if DEMO
        DemoScheduler.noteNotificationTapped(stage: stage, mood: mood)
        #else
        mood.pendingVisitStage = stage
        #endif
    }

    static func didComply(mood: MoodStore) {
        #if DEMO
        DemoScheduler.cancelEscalations()
        #endif
    }

    static func didSnooze(mood: MoodStore) {
        #if DEMO
        DemoScheduler.scheduleEscalations(from: Date(), mood: mood)
        #endif
    }
}

#if DEMO
/// Stand-in for the Screen Time extensions when there's no paid developer
/// account. Fires local notifications at lights-off, +15 and +30 minutes,
/// and does the night bookkeeping whenever the app comes to the front.
enum DemoScheduler {
    private static let bedtimeID = "demo.bedtime"
    private static func escalationID(_ n: Int) -> String { "demo.escalation.\(n)" }

    /// Next lights-off, plus the two follow-ups if you ignore her.
    static func schedule(mood: MoodStore) {
        cancelAll()
        let next = nextBedtime(mood: mood)
        let content = RoommateNotifier.content(stage: .sleepy, bedtime: mood.bedtimeString)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: next)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: bedtimeID, content: content, trigger: trigger))
        scheduleEscalations(from: next, mood: mood)
    }

    /// She comes back 15 and 30 minutes after `start` unless you say goodnight.
    static func scheduleEscalations(from start: Date, mood: MoodStore) {
        cancelEscalations()
        let center = UNUserNotificationCenter.current()
        for (n, stage) in [(1, Stage.frustrated), (2, Stage.fuming)] {
            let fire = start.addingTimeInterval(TimeInterval(RoommateConfig.escalationMinutes * 60 * n))
            guard fire > Date() else { continue }
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let content = RoommateNotifier.content(stage: stage, bedtime: mood.bedtimeString)
            center.add(UNNotificationRequest(identifier: escalationID(n), content: content, trigger: trigger))
        }
    }

    static func cancelEscalations() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [escalationID(1), escalationID(2)])
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [bedtimeID, escalationID(1), escalationID(2)])
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    /// Mirrors what the monitor extension would do at interval start / end.
    static func handleForeground(mood: MoodStore) {
        guard mood.isEnabled else { return }
        if mood.isBedtime() {
            if mood.stage == .none {
                mood.nightStarted()
            }
        } else if mood.nightStartedAt != nil {
            mood.nightEnded()
            schedule(mood: mood)   // line up tomorrow night
        } else {
            // Make sure tonight's notifications exist (e.g. after a reinstall).
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                if !requests.contains(where: { $0.identifier == bedtimeID }) {
                    DispatchQueue.main.async { schedule(mood: mood) }
                }
            }
        }
    }

    static func noteNotificationTapped(stage: Stage, mood: MoodStore) {
        if mood.stage == .none { mood.nightStarted() }
        if !mood.compliedTonight, stage.rawValue > mood.stage.rawValue, stage != .asleep {
            mood.escalate(to: stage)
        }
        let latest = stage.rawValue >= mood.stage.rawValue ? stage : mood.stage
        mood.pendingVisitStage = mood.compliedTonight ? .asleep : latest
    }

    private static func nextBedtime(mood: MoodStore) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = mood.bedtime.hour
        comps.minute = mood.bedtime.minute
        let today = cal.date(from: comps) ?? Date()
        return today > Date() ? today : cal.date(byAdding: .day, value: 1, to: today) ?? today
    }
}
#endif
