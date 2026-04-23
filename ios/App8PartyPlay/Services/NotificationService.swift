import UserNotifications
import UIKit

@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private(set) var isAuthorized: Bool = false

    private override init() {
        super.init()
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    func checkCurrentStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func scheduleRoomCreatedNotification(hostName: String, gameName: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "New Room!"
        content.body = "\(hostName) created a \(gameName) room. Join now!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleFriendRequestNotification(fromName: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Friend Request"
        content.body = "\(fromName) sent you a friend request!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleGameInviteNotification(hostName: String, gameName: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Game Invite"
        content.body = "\(hostName) invited you to play \(gameName)!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleReminderNotification() {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time to Play!"
        content.body = "Your friends are waiting. Jump into a game!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600 * 24, repeats: false)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    }
}
