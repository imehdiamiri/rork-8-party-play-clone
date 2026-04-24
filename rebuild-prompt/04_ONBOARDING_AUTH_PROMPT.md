# 8PartyPlay — Onboarding & Auth Prompt

This document specifies every screen in the onboarding flow and authentication system.

---

## 1. App Launch & Routing

### `RootView.swift`
The root view checks auth + onboarding state and routes accordingly:

```
App launch
  ↓
SplashView (1.5–2s)
  ↓
AppViewModel.authState ==
  .loading     → keep showing splash
  .signedOut   → OnboardingFlow (if first launch) or AuthView
  .guest       → MainTabView (limited features)
  .signedIn    → MainTabView (full features)
  .needsOnboarding → OnboardingNameView
```

**State machine:**
```swift
enum AuthFlowState {
    case loading
    case splash
    case onboarding           // first-ever launch: show 3-slide onboarding
    case auth                 // returning user, signed out
    case needsDisplayName     // just signed in but no username set
    case main                 // fully authenticated and onboarded
}
```

Persisted flags in `UserDefaults`:
- `has_seen_onboarding` — Bool, set to true after completing slide flow
- `display_name` — String, the user's local display name (set in onboarding)

---

## 2. SplashView

**Layout:**
- Full screen, `AppBackgroundView` background.
- Center: app logo image (`app_logo` asset) 120×120pt, spring scale-in from 0.6 → 1.0 (response 0.6, bounce 0.25), delay 0.2s.
- Below logo: "8PartyPlay" text, `viralTitleStyle` (40pt black), fade-in delay 0.5s.
- Below title: ProgressView `.circular` tinted white, fade-in delay 0.9s.
- Tagline "Party games for your crew." — 16pt medium, white.opacity(0.6), fade-in delay 1.1s.

**Behavior:** stays visible while `AppViewModel.authState == .loading`. Min display time 1.5s to prevent flash.

---

## 3. Onboarding Slides (first launch only)

A `TabView` with `tabViewStyle(.page(indexDisplayMode: .always))` — 3 slides. Page dots at bottom (custom white dots, selected = full white, unselected = white 30%). Skip button top-right. Continue button bottom.

### Slide 1 — Welcome
- Icon: `gamecontroller.fill` 80pt, white, in a 140×140 blue→indigo gradient circle.
- Title: "Welcome to 8PartyPlay" (28pt heavy).
- Body: "Turn your iPhones into the ultimate party game console. Play together — on one phone or many." (17pt, white.opacity(0.75), centered, multiline).

### Slide 2 — How It Works
- Three rows with icons:
  1. `iphone` + "1 Phone Mode" + "Everyone passes one phone. Perfect for anywhere." (blue accent)
  2. `iphone.and.iphone` + "Multi Phone Mode" + "Each player uses their own phone in real time." (indigo accent)
  3. `person.3.fill` + "Team Mode" + "Split into teams and compete together." (purple accent)
- Each row: icon in 44×44 accent-colored rounded square + VStack(title bold 16pt, subtitle regular 14pt secondary).
- Staggered entrance: 0.1s delay per row on appear.

### Slide 3 — Set Your Name
- Icon: `person.crop.circle.badge.plus` 64pt, white, in 100×100 teal gradient circle.
- Title: "What's your name?" (28pt heavy).
- Subtitle: "This is how friends will see you in games." (16pt, secondary).
- `TextField("Your name or nickname", text: $displayName)` — large centered style, 24pt, .default keyboard, `.textContentType(.name)`, max 20 characters.
  - Character counter: "X/20" caption top-right of field, appears when > 15 chars.
  - Validation: trim whitespace, min 1 char.
- Avatar picker row (5 SF Symbol options in colored circles: `person.fill`, `star.fill`, `bolt.fill`, `flame.fill`, `moon.fill` — user taps to pick their avatar icon).

**Continue/Done on Slide 3:**
- Saves `displayName` to `UserDefaults`.
- Requests notification permission (system prompt).
- Sets `has_seen_onboarding = true`.
- Navigates to `AuthView` if not signed in, else to `MainTabView`.

---

## 4. AuthView

**Layout (scrollable, centered):**
- Background: `AppBackgroundView`.
- Top: `app_logo` 80×80pt with viralTitle "8PartyPlay" below.
- Subtitle: "Sign in to save your progress and play with friends." (secondary, centered).
- `SurfaceCard` containing the 4 auth options.

### Auth options (in order, inside the card)

#### 1. Continue with Apple
```swift
SignInWithAppleButton(.continue, onRequest: { request in
    let nonce = authService.prepareAppleSignIn()
    request.requestedScopes = [.fullName, .email]
    request.nonce = nonce
}, onCompletion: { result in
    // call authService.signInWithApple(authorization:)
})
.signInWithAppleButtonStyle(.white)
.frame(height: 50)
.clipShape(.rect(cornerRadius: 12))
```

#### 2. Continue with Google
- Button: white background, Google "G" logo (Image asset `google_logo`), "Continue with Google" 16pt semibold dark text.
- Height 50pt, corner 12, border 1pt gray.

#### 3. Sign in with Email/Username
- Disclosure-style button: `envelope.fill` SF Symbol + "Email / Username" + `chevron.right`.
- Expands inline (or navigates to `EmailAuthView`).

#### 4. Play as Guest
- Secondary style: `person.fill` + "Continue as Guest" in white opacity 70%.
- Tapping signs in anonymously via Firebase.
- Below: small text "Guest mode lets you play solo & join rooms. Sign in anytime to unlock friends and cloud saves." (caption, secondary).

### Divider between Apple/Google and Email
- "OR" with horizontal lines.

### EmailAuthView (separate screen)

Pushed when user taps email option. Has two modes toggled by segmented control: **Sign In** / **Create Account**.

**Sign In mode:**
- `TextField("Email")` `.keyboardType(.emailAddress)` `.autocapitalization(.never)`.
- `SecureField("Password")` `.textContentType(.password)`.
- "Forgot Password?" link (sends Firebase password reset email).
- Primary "Sign In" button.

**Create Account mode:**
- `TextField("Display Name")` `.textContentType(.name)` max 20 chars.
- `TextField("Email")` `.keyboardType(.emailAddress)`.
- `SecureField("Password")` `.textContentType(.newPassword)` — show strength indicator (weak/fair/strong based on length + symbols).
- `SecureField("Confirm Password")`.
- Primary "Create Account" button.
- Inline validation:
  - Email: must contain `@` and `.`
  - Password: min 8 chars
  - Confirm: must match
  - Username: 3–20 chars, letters/numbers/underscore only

**Loading state:** buttons show ProgressView, all fields disabled during async op.

**Error handling:** display error as red inline text below the form + error haptic. Map Firebase auth error codes to friendly messages:
```
"auth/email-already-in-use"  → "That email is already registered. Try signing in."
"auth/wrong-password"        → "Incorrect password."
"auth/user-not-found"        → "No account found with that email."
"auth/network-request-failed" → "Check your internet connection."
"auth/too-many-requests"     → "Too many attempts. Please wait a moment."
(default)                    → "Something went wrong. Please try again."
```

---

## 5. Profile — Account Management

Accessible from the Profile sheet → Settings section.

### Link Account (Guest upgrade)
When user is a guest, show a "Link Account" section above Sign Out:
- Title: "Save Your Progress"
- Body: "Link an account to keep your stats and play with friends."
- Buttons: "Link with Apple", "Link with Google", "Link with Email".
- On success: guest data merges into the linked account.

### Change Username
- Sheet: `TextField` with current username pre-filled, 3–20 char validation, real-time uniqueness check (debounced 0.5s), "Save" button disabled until valid + changed.
- On save: calls `FirebaseDatabaseService.updateUsername(uid:newUsername:)`.

### Change Password (email users only)
- Sheet: current password + new password + confirm, same strength indicator as signup.

### Delete Account
- Reachable from Settings → Account → "Delete Account".
- Two-step confirmation:
  1. Alert: "Are you sure? This will permanently delete your account and all data." → "Delete Account" destructive / "Cancel".
  2. If user has active subscription: second alert "You have an active subscription. It will not be cancelled automatically — manage it in Settings > Subscriptions." → "I understand, delete anyway".
- On confirm: calls Cloud Function `deleteUserAccount`, then `Auth.auth().currentUser?.delete()`.
- Signs out and shows auth screen after deletion.

---

## 6. AppViewModel — Auth State Management

```swift
@Observable
@MainActor
final class AppViewModel {
    var authFlowState: AuthFlowState = .loading
    var currentUserProfile: UserProfile?
    var starBalance: Int = 0
    var isPro: Bool = false
    var pendingInviteCode: String?
    var connectionState: ConnectionState = .connected
    var toastQueue: [Toast] = []

    private let authService = FirebaseAuthService()
    private let dbService = FirebaseDatabaseService()
    private var profileListener: ListenerRegistration?
    private var starListener: ListenerRegistration?

    func initialize() async {
        // Watch auth state
        for await user in authService.userStream {
            if let user {
                await loadUserProfile(uid: user.uid)
                authFlowState = .main
            } else {
                currentUserProfile = nil
                starBalance = 0
                let seen = UserDefaults.standard.bool(forKey: "has_seen_onboarding")
                authFlowState = seen ? .auth : .onboarding
            }
        }
    }

    private func loadUserProfile(uid: String) async {
        currentUserProfile = try? await dbService.fetchUser(uid: uid)
        // Set up real-time listener for star balance
        starListener = dbService.listenToStarBalance(uid: uid) { [weak self] stars in
            self?.starBalance = stars
        }
    }

    func setPendingInviteCode(_ code: String) {
        pendingInviteCode = code
        // If user is already in main state, open the join flow immediately
    }

    func showToast(_ toast: Toast) {
        toastQueue.append(toast)
    }
}
```

---

## 7. Sign-Out Flow

From Profile sheet → Settings → "Sign Out":
1. Alert: "Sign Out?" body "You can sign back in anytime." — "Sign Out" / "Cancel".
2. On confirm: `try authService.signOut()` → AppViewModel routes to auth screen.
3. Clear local caches: pending invite code, room state, cached profile.

---

## 8. Entitlements Required

In `8PartyPlay.entitlements`:
```xml
<key>com.apple.developer.applesignin</key>
<array>
  <string>Default</string>
</array>
```

In `project.pbxproj` `INFOPLIST_KEY_` entries:
```
INFOPLIST_KEY_NSUserNotificationsUsageDescription = "To notify you about game invites and friend requests."
INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "To let you set a profile photo."
```

URL schemes in Info (for Google Sign-In):
```
REVERSED_CLIENT_ID from GoogleService-Info.plist
```
