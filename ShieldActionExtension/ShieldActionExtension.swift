import ManagedSettings
import Foundation

/// Runs when you tap a button on her lock screen.
///  • "okay, goodnight"  → she goes back to bed, the app you were in closes.
///  • "15 more minutes"  → the shield lifts; she comes back after 15 more
///                          minutes of use, a little more frustrated.
final class ShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        let mood = MoodStore.shared
        switch action {
        case .primaryButtonPressed:
            mood.complied()
            // Keep the shield up so she stays asleep; the next shield shows the zzz version.
            Shielding.apply(using: mood)
            return .close
        case .secondaryButtonPressed:
            mood.snoozed()
            Shielding.clear()
            return .none
        @unknown default:
            return .none
        }
    }
}
