# 8PartyPlay — Android App Prompt (Kotlin + Jetpack Compose)

This document specifies the native Android client. Feature parity with iOS and Web. Single Firebase backend shared with the other clients.

---

## 1. Tech Stack

- **Language:** Kotlin 2.0+
- **UI:** Jetpack Compose + Material 3 (dark theme only)
- **Architecture:** MVVM with `ViewModel` + `StateFlow` / `SharedFlow`
- **Navigation:** `androidx.navigation:navigation-compose` with type-safe routes (Kotlin Serialization)
- **DI:** Hilt (`dagger.hilt.android`)
- **Async:** Kotlin Coroutines + Flow
- **Min SDK:** 29 (Android 10) · **Target SDK:** 34+
- **Build:** Gradle Kotlin DSL, version catalog (`libs.versions.toml`)

### Gradle dependencies (key)
```kotlin
// Firebase
implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
implementation("com.google.firebase:firebase-auth-ktx")
implementation("com.google.firebase:firebase-firestore-ktx")
implementation("com.google.firebase:firebase-database-ktx")
implementation("com.google.firebase:firebase-functions-ktx")
implementation("com.google.firebase:firebase-messaging-ktx")
implementation("com.google.firebase:firebase-storage-ktx")
implementation("com.google.firebase:firebase-config-ktx")
implementation("com.google.firebase:firebase-analytics-ktx")
implementation("com.google.firebase:firebase-crashlytics-ktx")
implementation("com.google.firebase:firebase-appcheck-playintegrity")

// Google Sign-In (Credential Manager on 34+)
implementation("androidx.credentials:credentials:1.3.0")
implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

// Stripe
implementation("com.stripe:stripe-android:21.1.0")
implementation("com.stripe:paymentsheet:21.1.0")

// Compose
implementation(platform("androidx.compose:compose-bom:2024.10.01"))
implementation("androidx.compose.material3:material3")
implementation("androidx.activity:activity-compose")
implementation("androidx.navigation:navigation-compose:2.8.3")
implementation("androidx.hilt:hilt-navigation-compose:1.2.0")
implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")

// Other
implementation("io.coil-kt.coil3:coil-compose:3.0.0")
implementation("com.google.accompanist:accompanist-permissions:0.36.0")
```

---

## 2. Project Structure

```
android/
  app/
    src/main/java/app/partyplay/
      PartyPlayApplication.kt       // Hilt entry, Firebase init, Stripe init
      MainActivity.kt               // sets content, handles intents, deep links
      ui/
        theme/                      // Material 3 dark palette, typography, shapes
        components/                 // shared Compose widgets (GlassCard, ViralTitle, etc.)
        screens/
          splash/
          onboarding/
          auth/
          home/                     // tab container with 4 destinations
          games/                    // library + per-game setup + session
          tools/                    // dice/bottle/hourglass/coin/splitter + cards
          friends/
          factory/
          profile/
          paywall/
      feature/
        games/                      // per-game ViewModels + state machines
        rooms/                      // CasualRoomService, SessionResilience
        cards/                      // deck loading, saved cards
        economy/                    // stars, transactions
      data/
        firebase/                   // Firestore + RTDB + Functions wrappers
        auth/
        storage/
        stripe/                     // StripeRepository, checkout, portal
        notifications/              // FCM service
      domain/
        model/                      // data classes mirroring Firestore shape
        usecase/
    src/main/res/
      drawable/                     // bottle, coin heads/tails, splash
      mipmap-*/                     // app icon (from h03kekxe8ymunf0mls4b3.png)
      values/
        strings.xml
        themes.xml
    AndroidManifest.xml
    google-services.json            // Firebase config (not committed)
  build.gradle.kts (project)
  settings.gradle.kts
  gradle/libs.versions.toml
```

---

## 3. Theme

- Material 3 `darkColorScheme` with custom seed `#6366F1` (indigo) → violet/pink accents.
- `Surface` rounded 18dp, border `Color.White.copy(alpha = 0.05f)`.
- Background: `Box` with layered `Brush.radialGradient` + `blur(80.dp)` blobs + near-black base (`#05060B`).
- Typography: `Inter` (body), `SpaceGrotesk` or `Anton` (viral titles) — bundled as font resources.
- Shape tokens: `small` 10dp, `medium` 14dp, `large` 18dp, `xlarge` 28dp.

---

## 4. Navigation & Screens

Top-level: `SplashScreen` → `OnboardingScreen` (first run) → `AuthScreen` → `HomeScreen` (4 tabs).

Tabs use `NavigationBar` with `NavigationBarItem`s. Each tab has its own nested `NavHost`.

Screens (mirrors iOS / web):
- Splash, Onboarding (3 slides with PageIndicator)
- Auth (Sign in with Google + Email + Guest; **Sign in with Apple** via Credential Manager REST flow when available)
- Games library, Game setup per game, Game session per game, Join with Code, Room lobby, Room session
- Tools grid + 5 tool sheets (dice, bottle, hourglass, coin, splitter)
- Card deck library, card deck viewer, saved cards
- Friends (offline, online, requests, public rooms)
- Factory (AI card generator, AI game idea generator)
- Profile drawer (stats, wallet, settings, legal, sign-out)
- Paywall, Star Pack detail sheet

---

## 5. Firebase Integration

- `PartyPlayApplication.onCreate()` — `FirebaseApp.initializeApp(this)`, install Play Integrity App Check provider, set Crashlytics user id, subscribe to FCM topic `all`.
- `AuthRepository` wraps `FirebaseAuth` with suspend functions and `authStateFlow: Flow<FirebaseUser?>`.
- `FirestoreRepository` exposes typed flows: `userFlow(uid)`, `roomFlow(roomId)`, `publicRoomsFlow()`, `friendshipsFlow(uid)`, `savedCardsFlow(uid)`.
- `FunctionsRepository` — typed wrappers for `spendStars`, `grantStars`, `searchUsers`, `generateCards`, `startRoom`, `closeRoom`, `kickPlayer`, `createStripeCheckoutSession`, `createStripePortalSession`.
- `RealtimeRepository` — presence: sets `/presence/{uid}` online, uses `onDisconnect` to flip to offline.
- `FcmService: FirebaseMessagingService` — stores tokens in `/users/{uid}/deviceTokens/*`, renders notifications with deep-link intent.

---

## 6. Games — Parity Rules

Every per-game ViewModel is the Kotlin equivalent of the iOS one, with the same state machine, same timings, same scoring, same Firestore shape. Shared state lives in Firestore `/rooms/{roomId}/state/current` so an Android host can run a session with iOS + Web joiners.

See `08_GAMES_DETAILED_PROMPT.md` for the exhaustive per-game logic. All numbers, durations, and phase transitions must be copied verbatim.

---

## 7. Payments — Stripe

- `StripeRepository.startSubscription(tier)`:
  1. Call `createStripeCheckoutSession` Cloud Function with `{ uid, priceId, successUrl, cancelUrl, mode: "subscription" }`.
  2. Function returns `{ url }`. Open the URL in a **Chrome Custom Tab**.
  3. Stripe redirects to `partyplay://billing/success` (App Link) which the MainActivity intent filter handles.
  4. The user's Firestore doc is updated by `stripeWebhook` before success returns.
- `StripeRepository.openPortal()` — calls `createStripePortalSession`, opens returned URL in Custom Tab.
- `StripeRepository.buyStarPack(packId)` — same flow but `mode: "payment"`.
- Optional: use `PaymentSheet` for in-app card entry when the Play Store policy permits.
- Manifest intent-filters for `partyplay://billing/success` and `partyplay://billing/cancel` and `https://8partyplay.app/billing/*` (App Links).

---

## 8. Notifications & Deep Links

- FCM data-only payloads handled in `FcmService`; build a Notification with `PendingIntent` → `MainActivity` + `deepLink` extra.
- Deep link schemes handled in MainActivity:
  - `partyplay://room/<code>` — Quick-join
  - `partyplay://invite/<code>` — Redeem invite
  - `partyplay://billing/(success|cancel)` — Stripe return
  - `https://8partyplay.app/r/<code>` — Universal App Link (with `assetlinks.json`)
- Local notifications with `WorkManager` for daily star reward reminders.

---

## 9. Haptics & Sound

- `HapticFeedback` via `View.performHapticFeedback` / `VibrationEffect.createPredefined` for tap/correct/wrong/win.
- `SoundManager` uses `SoundPool` for short SFX and `MediaPlayer` for loops. Global mute toggle from profile writes to DataStore.

---

## 10. Accessibility

- `contentDescription` on every `Image` / `Icon`.
- Dynamic font scale via Material typography + `sp`.
- `Modifier.semantics` on game-specific custom views.
- Respect `AccessibilityManager.isReduceMotionEnabled` — skip the non-essential spring animations.

---

## 11. Permissions (AndroidManifest)

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />  <!-- Reverse Singing -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />  <!-- Avatar -->
```

Runtime permission requests via `accompanist-permissions` with rationale dialogs.

---

## 12. Config / Secrets

- `google-services.json` — Firebase (not committed).
- `BuildConfig.STRIPE_PUBLISHABLE_KEY` — from `gradle.properties` or CI env var `STRIPE_PUBLISHABLE_KEY`.
- `BuildConfig.STRIPE_PRICE_MONTHLY`, `STRIPE_PRICE_YEARLY`, `STRIPE_PRICE_STAR_PACK_*` — product price IDs.
- Firebase Remote Config for feature flags at runtime.

---

## 13. Testing

- Unit tests (JUnit 5 + MockK) for every ViewModel and Repository.
- Compose UI tests for key flows: auth, paywall, game setup, room join.
- Instrumented smoke test that signs in as anonymous, creates a room, starts Memory Grid, finishes a round.

---

## 14. Play Store Submission

See `16_APP_STORE_SUBMISSION_PROMPT.md` for the Google Play checklist: Data Safety form, Content Rating, target API policy, Play Integrity, screenshots, privacy policy URL, delete-account URL.
