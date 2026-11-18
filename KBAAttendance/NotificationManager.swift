import Foundation
import UserNotifications
import UIKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
                if granted {
                    self.scheduleDailyAttendanceReminder()
                }
            }
        }
    }

    func scheduleDailyAttendanceReminder() {
        let center = UNUserNotificationCenter.current()
        let identifier = "kba_daily_attendance_reminder"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "KBA Chấm công"
        content.body = "Đã đến giờ làm việc! Đừng quên chấm công buổi sáng nhé."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 5

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let err = error {
                print("Failed to schedule daily reminder: \(err)")
            }
        }
    }

    // Present banner, sound, and badge even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    func triggerMessageNotification(title: String, body: String, conversationId: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("message_sound.mp3"))
        content.userInfo = ["conversationId": conversationId]

        let request = UNNotificationRequest(
            identifier: "msg_\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let err = error {
                print("Failed to add notification request: \(err)")
            }
        }

        // Also trigger sound directly to ensure audible playback
        SoundManager.shared.playMessageSound()
    }
}
