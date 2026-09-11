import Foundation
import UIKit
import UserNotifications

/// Local notifications posted by the monitor extension when she comes out.
/// Tapping one opens the app straight into her animated visit.
enum RoommateNotifier {
    static let categoryIdentifier = "roommate.visit"
    static let stageKey = "stage"

    static func post(stage: Stage, bedtime: String) {
        let content = UNMutableNotificationContent()
        content.title = RoommateLines.shieldTitle(for: stage)
        content.body = RoommateLines.lines(for: stage, bedtime: bedtime).joined(separator: " ")
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [stageKey: stage.rawValue]
        content.sound = nil
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        if let attachment = imageAttachment(named: stage.standingPose) {
            content.attachments = [attachment]
        }
        let request = UNNotificationRequest(identifier: "roommate.visit.\(stage.rawValue)",
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    static func clearAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Writes one of her poses from the asset catalog to a temp file so it
    /// can ride along on the notification.
    private static func imageAttachment(named name: String) -> UNNotificationAttachment? {
        guard let image = UIImage(named: name, in: .main, with: nil),
              let data = image.pngData() else { return nil }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString).png")
        do {
            try data.write(to: tmp)
            return try UNNotificationAttachment(identifier: name, url: tmp, options: nil)
        } catch {
            return nil
        }
    }
}
