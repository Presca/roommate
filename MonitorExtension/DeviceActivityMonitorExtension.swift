import DeviceActivity
import ManagedSettings
import Foundation

/// iOS launches this at bedtime, at wake time, and every time you've used
/// your phone for another 15 minutes after she asked you to stop.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let mood = MoodStore.shared

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == RoommateConfig.bedtimeActivity else { return }

        mood.nightStarted()
        Shielding.apply(using: mood)
        RoommateNotifier.post(stage: .sleepy, bedtime: mood.bedtimeString)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == RoommateConfig.bedtimeActivity else { return }

        Shielding.clear()
        RoommateNotifier.clearAll()
        mood.nightEnded()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == RoommateConfig.bedtimeActivity,
              let step = event.disturbedStep else { return }

        // She only comes back if you actually let her go ("15 more minutes").
        // While the shield is up you can't rack up usage, so thresholds
        // only tick when you chose to keep going.
        let next: Stage = step <= 1 ? .frustrated : .fuming
        mood.escalate(to: next)
        Shielding.apply(using: mood)
        RoommateNotifier.post(stage: next, bedtime: mood.bedtimeString)
    }
}
