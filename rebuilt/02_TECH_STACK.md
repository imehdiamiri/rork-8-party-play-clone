# 02 — Tech Stack & Project Setup

## Toolchain
- Xcode 16+, Swift 6 strict concurrency on, default actor isolation = `MainActor`.
- iOS 18 minimum deployment target.
- SwiftUI app lifecycle (`@main` struct conforming to `App`).
- MVVM with `@Observable` view models, NavigationStack-based navigation.

## Folder layout (mirror exactly)
```
ios/App8PartyPlay/
├─ App8PartyPlayApp.swift    # @main + RevenueCat config + AppDelegate
├─ ContentView.swift          # routing splash/onboarding/auth/main
├─ Config.swift               # auto-generated EXPO_PUBLIC_* env (do not edit)
├─ App8PartyPlay.entitlements # Sign in with Apple, push notifications
├─ PrivacyInfo.xcprivacy
├─ Assets.xcassets
├─ Models/
├─ ViewModels/
├─ Services/
├─ Utilities/
└─ Views/
```

## Swift Package Manager dependencies
1. **supabase-swift** — `https://github.com/supabase/supabase-swift.git` (Auth, Postgrest, Realtime, Storage). Products: `Supabase`.
2. **purchases-ios-spm** — `https://github.com/RevenueCat/purchases-ios-spm.git`. Product: `RevenueCat`.

That's it. No Firebase, no third-party UI kits, no analytics SDKs. Use SF Symbols only.

## Required `INFOPLIST_KEY_*` entries (in `project.pbxproj`)
- `INFOPLIST_KEY_CFBundleDisplayName = 8PartyPlay`
- `INFOPLIST_KEY_NSMicrophoneUsageDescription = "8PartyPlay needs microphone access for the Reverse Singing game."`
- `INFOPLIST_KEY_NSUserNotificationsUsageDescription = "8PartyPlay sends notifications for friend requests and game invites."`
- `INFOPLIST_KEY_UIBackgroundModes = ["remote-notification"]`
- `INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES`
- `INFOPLIST_KEY_UILaunchScreen_Generation = YES`
- URL Types entry for `invite` scheme + Supabase OAuth callback scheme `app.rork.cejfnhlng6nv3gg1g94ab`.
- Associated Domains: `applinks:8partyplay.com`, `applinks:www.8partyplay.com`, `applinks:app.8partyplay.com`.

## Entitlements
`App8PartyPlay.entitlements`:
- `com.apple.developer.applesignin = ["Default"]`
- `aps-environment = development`
- `com.apple.developer.associated-domains` = the three applinks above.

## Env / Config
Public env keys exposed via the auto-generated `Config.swift`. Required:
- `EXPO_PUBLIC_REVENUECAT_IOS_API_KEY`
- `EXPO_PUBLIC_RORK_API_BASE_URL`
- `EXPO_PUBLIC_TOOLKIT_URL`
- `EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY`
- `EXPO_PUBLIC_PROJECT_ID`, `EXPO_PUBLIC_TEAM_ID`

Hardcoded constants live in `Utilities/AppConstants.swift`:
```swift
nonisolated enum AppConstants {
    enum Supabase {
        static let urlString = "https://lhbepwdudjhghxgiegnl.supabase.co"
        static let anonKey = "sb_publishable_0gBYSRLqEyJrrN6bDp5mag_jOPIzSzR"
        static let callbackScheme = "app.rork.cejfnhlng6nv3gg1g94ab"
    }
    enum URLs {
        static let privacyPolicy = URL(string: "https://www.8partyplay.com/privacy.html")!
        static let termsOfService = URL(string: "https://www.8partyplay.com/terms.html")!
        static let marketingSite = URL(string: "https://www.8partyplay.com")!
    }
    enum Invite {
        static let allowedHosts: Set<String> = ["8partyplay.com", "www.8partyplay.com", "app.8partyplay.com"]
        static let inviteScheme = "invite"
    }
}
```

## App entry (`App8PartyPlayApp.swift`) responsibilities
- `@State private var appModel = AppViewModel()`, `@State private var store = StoreViewModel()`.
- `init()` → configure RevenueCat with `Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY` and set log level (debug in DEBUG, error otherwise).
- `WindowGroup` → `ContentView(appModel:, store:)` with `.preferredColorScheme(.dark)`, English-only locale environment, `.onAppear { store.start() }`, `.onOpenURL { … }` to extract invite codes (custom `invite://?code=…` or `https://(www.)?8partyplay.com/invite?code=…`) and route to either `appModel.setPendingInviteCode(code)` or `appModel.handleOAuthCallback(url)`.
- `.onChange(of: scenePhase)` forwards to `appModel.handleScenePhaseChange(to:)`.

## AppDelegate (`UIApplicationDelegateAdaptor`)
- Sets `UNUserNotificationCenter.current().delegate = NotificationService.shared`.
- Installs global keyboard-dismiss tap+pan gesture recognizers on every `UIWindow` (skip when touch is inside `UITextField` / `UITextView` / `UISearchBar`).
- Implements `didRegisterForRemoteNotificationsWithDeviceToken` → store hex token in `DeviceTokenStore.shared.latestToken`.
