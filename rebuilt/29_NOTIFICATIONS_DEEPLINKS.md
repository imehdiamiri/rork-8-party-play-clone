# 29 — Notifications & Deep Links

Files: `Services/NotificationService.swift`, `Services/DeviceTokenStore.swift`, `App8PartyPlayApp.swift` (URL handling).

## Local & remote notifications
- `NotificationService.shared` is `UNUserNotificationCenterDelegate`.
- `requestPermission()` — async, triggers `requestAuthorization(options: [.alert, .badge, .sound])`. Updates `isAuthorized: Bool`.
- `checkCurrentStatus()` — pulls current settings, updates `isAuthorized`.
- `userNotificationCenter(_:willPresent:withCompletionHandler:)` — show banner + sound while in foreground.
- `userNotificationCenter(_:didReceive:withCompletionHandler:)` — extract `userInfo["invite_code"]` or `userInfo["room_id"]`, route to `appModel.handleNotificationPayload(_:)`.

## Push token
- `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` writes hex to `DeviceTokenStore.shared.latestToken`.
- After the user signs in, `appModel.uploadPushToken()` posts to Supabase `device_tokens` table (upsert by user_id+token).
- Supabase Edge Function `send_push` sends push via APNs HTTP/2 with the team key from secrets. Used for friend requests, invites, daily reminder.

## Deep links

### Custom scheme
- `invite://?code=ABC123` — opens the app, captures the code, applies it on the next event boundary (sign-up bonus + invite reward).
- The OAuth callback uses scheme `app.rork.cejfnhlng6nv3gg1g94ab://callback`, handled by `appModel.handleOAuthCallback(_:)`.

### Universal links
- Domains: `8partyplay.com`, `www.8partyplay.com`, `app.8partyplay.com`.
- Path: `/invite?code=…`.
- `App8PartyPlayApp.extractInviteCode(from:)` parses both schemes.

## Pending invite handling
- `appModel.setPendingInviteCode(code)` stores code. After the user reaches `MainTabView`, prompt: "Use invite code {code}? +30 ★" with Apply / Dismiss. On Apply call `apply_invite_code` RPC.

## `applinks` plist
Add associated domains entitlement (file 02). Apple-app-site-association file is hosted on the marketing site under `.well-known/`.

## Notification copy presets
- Friend request: "{name} sent you a friend request" → tap opens Friends tab with Requests highlighted.
- Friend accepted: "{name} added you as a friend".
- Room invite: "{host} invited you to play {game}" → tap opens `WaitingRoomView` for that room.
- Daily reminder (optional, opt-in): "Your daily ★ is ready!" → opens Wallet.

## Toggle in Settings
The Profile tab "Notifications" row reflects current authorization. If denied, button text becomes "Open Settings" deep link to `UIApplication.openSettingsURLString`.
