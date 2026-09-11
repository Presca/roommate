import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Decides what the lock screen looks like when she's standing in front of an app.
/// Apple only lets us pick an icon, two lines of text, and two buttons here –
/// no animation. The animated version lives in the app (tap the notification).
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make()
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        make()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        make()
    }

    private func make() -> ShieldConfiguration {
        let mood = MoodStore.shared
        let stage = mood.stage == .none ? .sleepy : mood.stage

        let ink = UIColor(red: 0.24, green: 0.20, blue: 0.18, alpha: 1)
        let soft = UIColor(red: 0.45, green: 0.40, blue: 0.38, alpha: 1)
        let cream = UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
        let blush = UIColor(red: 0.93, green: 0.55, blue: 0.60, alpha: 1)
        let sky = UIColor(red: 0.60, green: 0.72, blue: 0.84, alpha: 1)

        let icon = UIImage(named: stage.standingPose, in: .main, with: nil)
            ?? UIImage(systemName: "moon.zzz.fill")

        let primary: String
        let secondary: String?
        switch stage {
        case .asleep:
            primary = "goodnight 🌙"
            secondary = "I really need my phone..."
        default:
            primary = "okay, goodnight 🌙"
            secondary = "15 more minutes..."
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: cream,
            icon: icon,
            title: ShieldConfiguration.Label(text: RoommateLines.shieldTitle(for: stage), color: ink),
            subtitle: ShieldConfiguration.Label(
                text: RoommateLines.shieldSubtitle(for: stage, bedtime: mood.bedtimeString),
                color: soft),
            primaryButtonLabel: ShieldConfiguration.Label(text: primary, color: .white),
            primaryButtonBackgroundColor: stage == .fuming ? blush : sky,
            secondaryButtonLabel: secondary.map { ShieldConfiguration.Label(text: $0, color: soft) }
        )
    }
}
