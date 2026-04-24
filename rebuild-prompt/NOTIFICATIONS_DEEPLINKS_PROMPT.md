# 8PartyPlay — Notifications & Deep Links Prompt

This document specifies the full push notification system, local notifications, and deep link routing for 8PartyPlay.

---

## 1. Notification Permission

### When to request
- After completing the onboarding slide flow (Slide 3 → "Done") — request immediately.
- If the user skipped onboarding and is going straight to the main tab, request after they complete their first game.
- Never ask twice in the same session if already denied.

### Request flow
```swift
let center = UNUserNotificationCenter.current()
let status = await center.notificationSettings().authorizationStatus

switch status {
case .notDetermined:
    let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
    if granted { await registerForRemoteNotifications() }
case .authorized, .provisional:
    await registerForRemoteNotifications()
case .denied:
    // Do nothing — user can enable in Settings
default:
    break
}

@MainActor
func registerForRemoteNotifications() async {
    UIApplication.shared.registerForRemoteNotifications()
}
```

### In Settings / Profile sheet
- Toggle: "Notifications" → if currently `.authorized`, shows green toggle ON.
- If toggle is tapped OFF while authorized: open system Settings URL.
- If toggle is tapped ON while `.denied`: show alert "To enable notifications, go to Settings > 8PartyPlay > Notifications." with "Open Settings" button that calls `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`.
- If `.notDetermined`: tapping ON triggers the permission request.

---

## 2. FCM Device Token Management

### `DeviceTokenStore.swift`
```swift
@Observable
@MainActor
final class DeviceTokenStore {

    func storeFCMToken(for uid: String) async {
        do {
            let token = try await Messaging.messaging().token()
            let tokenRef = Firestore.firestore()
                .collection("users/\(uid)/deviceTokens")
                .document(token.hashValue.description)
            try await tokenRef.setData([
                "token": token,
                "platform": "ios",
                "createdAt": FieldValue.serverTimestamp(),
            ], merge: true)
        } catch {
            // Fail silently — non-critical
        }
    }

    func removeToken(for uid: String) async {
        guard let token = try? await Messaging.messaging().token() else { return }
        try? await Firestore.firestore()
            .collection("users/\(uid)/deviceTokens")
            .document(token.hashValue.description)
            .delete()
    }
}
```

Call `storeFCMToken` after successful sign-in. Call `removeToken` before sign-out.

### AppDelegate / SwiftUI lifecycle
```swift
// In AppDelegate (or via UIApplicationDelegateAdaptor):
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
}

func application(_ application: UIApplication,
                 didFailToRegisterForRemoteNotificationsWithError error: Error) {
    // Fail silently in production
}
```

---

## 3. Push Notification Types

All push notifications are sent from Firebase Cloud Functions using `admin.messaging()`.

### 3.1 Friend Request Received
```json
{
  "notification": {
    "title": "{senderName} wants to be your friend",
    "body": "Tap to see their request."
  },
  "data": {
    "type": "friend_request",
    "fromUID": "{uid}"
  }
}
```
**Tap behavior:** open Friends tab → scroll to pending requests.

### 3.2 Friend Request Accepted
```json
{
  "notification": {
    "title": "You and {name} are now friends!",
    "body": "Invite them to a game."
  },
  "data": {
    "type": "friend_accepted",
    "fromUID": "{uid}"
  }
}
```
**Tap behavior:** open Friends tab → online friends section.

### 3.3 Room Invite
```json
{
  "notification": {
    "title": "{hostName} invited you to play",
    "body": "{gameName} · Room code {code}"
  },
  "data": {
    "type": "room_invite",
    "roomID": "{roomID}",
    "roomCode": "{code}",
    "gameName": "{gameName}"
  }
}
```
**Tap behavior:** open join flow pre-filled with room code → show join confirmation sheet.

### 3.4 Room Starting Soon
```json
{
  "notification": {
    "title": "Game starting now!",
    "body": "{gameName} with {hostName} is about to begin."
  },
  "data": {
    "type": "room_starting",
    "roomID": "{roomID}"
  }
}
```
**Tap behavior:** if user is already in the room (player document exists), open the room directly. Otherwise, open join sheet.

### 3.5 Daily Reward Available
```json
{
  "notification": {
    "title": "Your daily stars are ready ⭐",
    "body": "Claim your free {amount} stars today."
  },
  "data": {
    "type": "daily_reward"
  }
}
```
**Tap behavior:** open Profile → Wallet → scroll to daily reward claim button.

### 3.6 Subscription Renewal
```json
{
  "notification": {
    "title": "Thanks for being Pro!",
    "body": "Your monthly stars have been added."
  },
  "data": {
    "type": "subscription_renewal",
    "amount": "{starsAmount}"
  }
}
```
**Tap behavior:** open Profile → Wallet → star balance.

---

## 4. Local Notifications

Scheduled using `UNUserNotificationCenter`.

### 4.1 Hourglass Timer End
Triggered by `HourglassViewModel` when the user starts a timer.
```swift
func scheduleTimerNotification(seconds: TimeInterval, label: String) {
    let content = UNMutableNotificationContent()
    content.title = "Timer finished!"
    content.body = "\(label) is done."
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
    let request = UNNotificationRequest(identifier: "hourglass_\(UUID())", content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
}

// Cancel when user stops timer manually
func cancelTimerNotification(identifier: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
}
```

### 4.2 Turn Reminder (multi-device, if app goes background mid-game)
If the app is backgrounded during a multi-device game and it's the user's turn:
```swift
let content = UNMutableNotificationContent()
content.title = "It's your turn!"
content.body = "Your opponents are waiting in \(gameName)."
content.sound = .default
content.userInfo = ["type": "turn_reminder", "roomID": roomID]

// 30s delay trigger
let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
```
Cancel this notification when the app foregrounds and the turn state is resolved.

---

## 5. Notification Handling (`NotificationService.swift`)

```swift
@Observable
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate, MessagingDelegate {

    weak var appViewModel: AppViewModel?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }

    // MARK: - Foreground notification display
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show as in-app toast instead of system banner for certain types
        let type = notification.request.content.userInfo["type"] as? String
        if type == "friend_request" || type == "room_invite" {
            Task { @MainActor in
                self.appViewModel?.showToast(.init(
                    type: .info,
                    message: notification.request.content.title
                ))
                self.handleNotificationData(notification.request.content.userInfo)
            }
            completionHandler([]) // don't show system banner
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }

    // MARK: - Tap on notification (app in background/killed)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            self.handleNotificationData(response.notification.request.content.userInfo)
        }
        completionHandler()
    }

    // MARK: - FCM token refresh
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task { @MainActor in
            guard let uid = Auth.auth().currentUser?.uid else { return }
            await DeviceTokenStore().storeFCMToken(for: uid)
        }
    }

    // MARK: - Route based on notification type
    @MainActor
    private func handleNotificationData(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "friend_request":
            appViewModel?.navigateTo(.friends)
        case "friend_accepted":
            appViewModel?.navigateTo(.friends)
        case "room_invite", "room_starting":
            if let roomCode = userInfo["roomCode"] as? String {
                appViewModel?.setPendingRoomCode(roomCode)
            }
        case "daily_reward":
            appViewModel?.navigateTo(.wallet)
        case "subscription_renewal":
            appViewModel?.navigateTo(.wallet)
        default:
            break
        }
    }
}
```

---

## 6. Deep Links

### Supported URL formats

| URL | Action |
|---|---|
| `partyplay://invite?code=ABCD` | Open invite redemption + join room |
| `partyplay://room/ABCDEF` | Open join sheet pre-filled |
| `partyplay://friends` | Navigate to Friends tab |
| `partyplay://factory` | Navigate to Factory tab |
| `partyplay://wallet` | Open Profile → Wallet |
| `https://8partyplay.com/invite?code=ABCD` | Same as custom scheme invite |
| `https://8partyplay.com/room/ABCDEF` | Same as custom scheme room |

### Universal Links setup (`apple-app-site-association`)

Host at `https://8partyplay.com/.well-known/apple-app-site-association`:
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "<TEAM_ID>.com.8partyplay.app",
        "paths": [
          "/invite*",
          "/room*"
        ]
      }
    ]
  }
}
```

In `8PartyPlay.entitlements`:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:8partyplay.com</string>
</array>
```

In `project.pbxproj` INFOPLIST_KEY entries, add URL scheme:
```
URL Scheme: partyplay
```

### Swift deep link handling

In `RootView.swift`:
```swift
.onOpenURL { url in
    appViewModel.handleIncomingURL(url)
}
```

In `AppViewModel`:
```swift
func handleIncomingURL(_ url: URL) {
    // Parse both custom scheme and universal links
    let code: String?

    if url.scheme == "partyplay" {
        switch url.host {
        case "invite":
            code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value
            if let code { handleInviteCode(code) }
        case "room":
            code = url.pathComponents.dropFirst().first
            if let code { setPendingRoomCode(code) }
        case "friends":
            selectedTab = .friends
        case "factory":
            selectedTab = .factory
        case "wallet":
            showWallet = true
        default:
            break
        }
    } else if url.host == "8partyplay.com" {
        let path = url.path
        if path.hasPrefix("/invite") {
            code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value
            if let code { handleInviteCode(code) }
        } else if path.hasPrefix("/room/") {
            let roomCode = String(path.dropFirst("/room/".count))
            if !roomCode.isEmpty { setPendingRoomCode(roomCode) }
        }
    }
}

private func handleInviteCode(_ code: String) {
    // If user is authed and onboarded, open join flow immediately
    // Otherwise, store pending code and open after auth/onboarding
    pendingInviteCode = code
    if authFlowState == .main {
        showJoinRoomSheet = true
    }
    // When onboarding/auth completes, check pendingInviteCode and open join flow
}

func setPendingRoomCode(_ code: String) {
    pendingRoomCode = code
    if authFlowState == .main {
        showJoinRoomSheet = true
    }
}
```

### Cold start handling

On cold launch via a deep link, `onOpenURL` fires after the view appears. The `AppViewModel.initialize()` async sequence runs in parallel. The solution:

1. Store the incoming URL in `pendingURL` immediately in `AppDelegate.application(_:open:options:)` or in a `@State` on `RootView`.
2. After `AppViewModel.authFlowState` transitions to `.main`, check `pendingURL` and call `handleIncomingURL`.
3. Clear `pendingURL` after handling.

```swift
// In RootView:
.onChange(of: appViewModel.authFlowState) { _, newState in
    if newState == .main, let url = pendingURL {
        appViewModel.handleIncomingURL(url)
        pendingURL = nil
    }
}
```

---

## 7. Badge Management

- App badge count = number of unread friend requests + unread room invites.
- Update badge after every Firestore listener callback:
```swift
func updateBadgeCount(pendingFriendRequests: Int, pendingInvites: Int) {
    let total = pendingFriendRequests + pendingInvites
    UNUserNotificationCenter.current().setBadgeCount(total)
}
```
- Clear badge when user opens the Friends tab or accepts/declines all pending items.
- Never show a badge for already-seen items.

---

## 8. Notification Content Extensions (optional stretch goal)

For room invite notifications, a **Notification Content Extension** can show:
- Game name + mode
- Host avatar + name
- Two action buttons: "Join" (opens app to join flow) and "Decline"

Register category in `NotificationService.init()`:
```swift
let joinAction = UNNotificationAction(identifier: "JOIN", title: "Join", options: .foreground)
let declineAction = UNNotificationAction(identifier: "DECLINE", title: "Decline", options: .destructive)
let category = UNNotificationCategory(
    identifier: "ROOM_INVITE",
    actions: [joinAction, declineAction],
    intentIdentifiers: [],
    options: []
)
UNUserNotificationCenter.current().setNotificationCategories([category])
```

Set `"category": "ROOM_INVITE"` in the FCM payload for room invite notifications.
