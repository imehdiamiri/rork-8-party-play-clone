# 06 — Auth

## `Services/SupabaseService.swift`
Tiny singleton that wraps `SupabaseClient` from supabase-swift. Initialized with `AppConstants.Supabase.urlString` and `anonKey`. Exposes `client`, `auth`, `database`, `realtime` properties.

## `Services/SupabaseAuthService.swift`
Class (`@Observable`) with all auth operations. Uses `nonisolated` on data DTOs.
- `currentUser: SupabaseUser?` (mirror of `auth.session.user`).
- `signUpWithUsernamePassword(username:password:)` — creates `{username}@8partyplay.local` user, then calls `set_username` RPC.
- `signIn(username:password:)` — calls `auth.signIn(email:, password:)` with the same email derivation.
- `signInAnonymously()` — used for guest play.
- `signInWithApple(presentingFrom:)` — async coordinator wrapping `ASAuthorizationAppleIDProvider`. Generates a SHA-256 nonce, sets it as `request.nonce`, then `auth.signInWithIdToken(provider: .apple, idToken: …, nonce: rawNonce)`.
- `signInWithGoogle()` — opens `auth.signInWithOAuth(provider: .google, redirectTo: app.rork.cejfnhlng6nv3gg1g94ab://callback)` via `ASWebAuthenticationSession`. The returned URL is forwarded to `auth.session(from:)` in `handleOAuthCallback(url:)`.
- `signOut()`.
- `deleteAccount()` — calls `delete_account` RPC then signs out.
- `refreshSession()` — pulls current session and emits `currentUser`.

## AuthView (`Views/AuthView.swift`)
Full screen, dark, with `AppBackgroundView`. Layout (top to bottom):
1. Optional close button (`xmark` 32pt circle) when presented as a sheet.
2. `gamecontroller.fill` icon (38pt) on a 14% blue 22-rounded square.
3. Title `8PartyPlay` (viralTitleStyle 32, .black).
4. Subtitle `"Sign in to claim 100 ★, friends, and AI cards."`.
5. `Username` TextField (no autocapitalization, content-type `.username`) → `Password` SecureField (content-type `.password` for login, `.newPassword` for signup). Both 16/14 padding, 6% white fill, 8% white stroke, 14-rounded.
6. Primary button: `"Login"` or `"Create Account"` (PrimaryActionButtonStyle, disabled until both fields non-empty).
7. `"Continue with Apple"` (apple.logo + label) — 9% white pill.
8. `"Continue with Google"` (globe + label) — 6.5% white pill.
9. Inline `errorMessage` in red when `appModel.errorMessage != nil`.
10. Toggle row `"Don't have an account? Sign Up"` ↔ `"Already have an account? Login"` — toggles `isLogin` boolean.
11. Bottom block: `Continue as Guest` text button (calls `appModel.continueAsGuest()`), `"You can log in anytime later from your profile."` caption, Privacy / Terms `Link`s.

While `appModel.isBusy`, overlay a black-35% scrim with a centered `ProgressView()` in `ultraThinMaterial` rounded card.

`onChange(of: appModel.currentProvider)`: when not `.guest`, dismiss keyboard and (if presented as sheet) dismiss self.

## Guest mode
- `appModel.continueAsGuest()` calls `signInAnonymously()` and sets `currentProvider = .guest`. Guest users still get a stars balance (zero) and can play single-device games and join casual rooms but cannot send friend requests, claim signup bonus, or appear in search results.

## Account flow rules
- After first sign-up, automatically claim signup bonus (100 ★) via `claim_signup_bonus` and write to `star_transactions`.
- After login, fetch profile + stars_balance + active subscription + invite reward state in parallel.
- `currentProvider` is computed from the latest auth identity (`apple` / `google` / `username` / `guest`).
- `appModel.isAuthenticated == true` for any signed-in user including guests; the AuthView is shown only when there's no session at all.
- `OnboardingView` runs **before** auth on first launch; the player name captured there persists locally and is the default `username` for guests.
