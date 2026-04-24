# 8PartyPlay — Full Rebuild Prompt (Multi-Platform, Firebase + Stripe)

Use this prompt to rebuild the entire **8PartyPlay** product from scratch as a **cross-platform** app available on:

- **iOS** (iPhone, iOS 18+) — native Swift + SwiftUI
- **Android** (Android 10+ / API 29+) — native Kotlin + Jetpack Compose
- **Web** (responsive PWA) — Next.js + React + TypeScript + Tailwind

All three clients share a single **Firebase** backend (Auth, Firestore, Realtime DB, Cloud Functions, Storage, FCM, Remote Config, App Check) and a unified **Stripe** payments layer (web + Android) alongside native store purchases on iOS. Every platform must render the same feature set, the same data, the same rooms, and the same economy — a user who signs up on the web can open the iPhone or Android app and find the exact same profile, friends, stars, saved cards, and in-progress rooms.

**Read all sibling prompt files together:**
- `02_DESIGN_SYSTEM_PROMPT.md` — full design system, colors, typography, components (applies to iOS, Android, Web).
- `03_FIREBASE_SETUP_PROMPT.md` — Firebase config, Firestore rules, Cloud Functions source (shared by all clients).
- `04_ONBOARDING_AUTH_PROMPT.md` — onboarding slides and auth flow screens.
- `05_APP_SHELL_PROMPT.md` — navigation shell, tools, cards, friends, wallet, subscriptions.
- `06_MULTI_DEVICE_PROMPT.md` — realtime rooms, multi-device sync, reconnection.
- `07_GAMES_OVERVIEW_PROMPT.md` — summary of every game.
- `08_GAMES_DETAILED_PROMPT.md` — every game screen, button, timer, animation, scoring rule.
- `09_TOOLS_CARDS_DETAILED_PROMPT.md` — party tools and card decks in full detail.
- `10_FACTORY_TAB_PROMPT.md` — AI game/card generator tab.
- `11_NOTIFICATIONS_DEEPLINKS_PROMPT.md` — push notifications, deep links, FCM, universal links, App Links.
- `12_ASSETS_AND_SOUNDS_PROMPT.md` — images, icons, splash, SFX, haptics.
- `13_ANALYTICS_AND_REMOTE_CONFIG_PROMPT.md` — analytics, Crashlytics, Remote Config, App Check.
- `14_LOCALIZATION_ACCESSIBILITY_PROMPT.md` — localization, Dynamic Type, VoiceOver/TalkBack, screen-reader support on web.
- `15_TESTING_AND_QA_PROMPT.md` — unit + UI tests, manual QA, performance budgets.
- `16_APP_STORE_SUBMISSION_PROMPT.md` — App Store, Google Play, and web deployment.
- `17_ANDROID_APP_PROMPT.md` — native Android client (Kotlin + Compose) full spec.
- `18_WEB_APP_PROMPT.md` — Next.js web / PWA client full spec.
- `19_STRIPE_PAYMENTS_PROMPT.md` — Stripe Checkout, Billing, Customer Portal, webhooks.
- `20_CROSS_PLATFORM_SYNC_PROMPT.md` — how iOS, Android and Web stay in sync through Firebase.

---

## 1. High-Level Summary

**8PartyPlay** is a premium cross-platform party-game product that turns one or multiple phones (and/or a laptop) into a social game console. It bundles 11 original mini-games, party tools (dice, coin, bottle, hourglass, team splitter), a shuffled card deck library, an AI card generator, a ⭐ Star economy, subscriptions, friends, and real-time multiplayer with rooms and invite codes.

- **Clients:**
  - **iOS 18+** — SwiftUI, MVVM with `@Observable`, dark-mode only.
  - **Android 10+ (API 29+)** — Kotlin, Jetpack Compose, MVVM with `ViewModel` + `StateFlow`, Material 3 dark theme.
  - **Web (PWA)** — Next.js 14 App Router, React 18, TypeScript, Tailwind, `shadcn/ui`, dark-only. Installable as a PWA, works on desktop + mobile browsers.
- **Language:** English (UI). `AppLanguage` enum / i18n scaffolding present on all three clients so more languages can be added.
- **Backend:** **Firebase** — Auth, Firestore, Realtime Database (presence), Cloud Functions, FCM, Storage, Remote Config, App Check. Single source of truth for all three clients.
- **Monetization:**
  - **iOS** → RevenueCat (wraps StoreKit for App Store-compliant subscriptions + consumable star packs).
  - **Android** → **Stripe** (Stripe Checkout + Billing) via the mobile Payment Sheet, plus optional Google Play Billing through RevenueCat for the Play Store build. Default is Stripe for parity with web.
  - **Web** → **Stripe** Checkout + Customer Portal for subscriptions and one-off star packs.
  - All entitlements converge server-side: Cloud Functions + webhooks (`revenueCatWebhook`, `stripeWebhook`) write the same `subscriptionTier`, `subscriptionExpiresAt`, and `stars` fields on `/users/{uid}`.
- **Economy:** Stars (⭐) — earned via subscriptions, daily rewards, invites, sign-up bonus. Spent to unlock premium items one-off. Balance is per-user and identical across devices.
- **NO XP system.** Do not implement XP, levels, level-up animations, or per-game level progress anywhere. Remove any XP reference you encounter.
- **Theme:** Dark, Apple-native feel on iOS; Material-You-tuned-dark on Android; Tailwind dark neutral with matching accents on web. Viral/bold title typography, glass / `.ultraThinMaterial` (iOS), `Surface` with blur (Android), `backdrop-blur` (web). iOS 26 Liquid Glass when available, graceful fallback on iOS 18–25.
- **Brand logo:** `h03kekxe8ymunf0mls4b3.png` — use for app icon, splash, website favicon across all platforms.

---

## 2. Information Architecture (same on every platform)

Bottom **TabView** (iOS) / **NavigationBar** (Android) / **Sidebar on desktop + bottom tabs on mobile web** with 4 tabs:

1. **Games** — `gamecontroller.fill` / `Icons.Filled.SportsEsports` / `GamepadIcon` — 2-column game library grid + "Join with Code" button + mode filter chips (All / 1 Phone / Multi Phone / Team Mode) + a segmented switch between **Games** (playable) and **Ideas** (party game tutorials).
2. **Tools** — `wrench.and.screwdriver.fill` / `Icons.Filled.Build` / `WrenchIcon` — Party Tools grid (Dice, Bottle, Hourglass, Coin Flip, Team Splitter) + Card decks library.
3. **Friends** — `person.2.fill` / `Icons.Filled.Group` / `UsersIcon` (badge for pending requests) — Quick Join card, Offline Friends, Online Friends search/add, Public Rooms browser.
4. **Factory** — `wand.and.stars` / `Icons.Filled.AutoAwesome` / `SparklesIcon` — AI Card Generator + AI Party Game Idea Generator.

A floating **Profile** button (user avatar) lives top-right on every root screen. It opens a bottom sheet (mobile) or a right-side drawer (desktop web) with profile stats, wallet, settings, legal, sign-out.

A thin top banner appears when network is `reconnecting` or `disconnected`.

---

## 3. Game Library

Grid of 2-column cards (3- or 4-column on tablet and desktop web). Each card: bold viral title, centered icon in a rounded square, mode-icon chips, player count text. Locked games show a **transparent lock badge (top-right)**. Locked games are sorted to the bottom.

### Complete game list (order is exact)

| # | Game | Icon (iOS SF / Android M3 / Web Lucide) | Modes | Players | Free |
|---|---|---|---|---|---|
| 1 | **Reverse Singing** | `backward.fill` / `FastRewind` / `Rewind` | 1 Phone | 2 | ✅ |
| 2 | **Guess the Seconds** | `stopwatch.fill` / `Timer` / `Timer` | 1 Phone | 2–30 | ✅ |
| 3 | **Imposter** | `eye.fill` / `Visibility` / `Eye` | 1 Phone | 4–30 | ✅ |
| 4 | **Memory Grid** | `square.grid.3x3.fill` / `GridOn` / `Grid3x3` | 1 / Multi / Team | 1–30 | ✅ |
| 5 | **Truth & Dare** | `arrow.triangle.2.circlepath` / `SwapHoriz` / `RefreshCw` | 1 Phone | 3–12 | ✅ |
| 6 | **Ten Tangle** | `theatermasks.fill` / `TheaterComedy` / `Drama` | 1 Phone | 3–11 | 💎 |
| 7 | **Memory Path** | `map.fill` / `Map` / `Map` | 1 / Multi / Team | 2–30 | 💎 |
| 8 | **Pass & Guess** | `text.bubble.fill` / `ChatBubble` / `MessageSquare` | 1 Phone | 2–30 | 💎 |
| 9 | **Tap in Order** | `number.square.fill` / `Filter1` / `Hash` | 1 / Multi | 1–30 | 💎 |
| 10 | **Color Trap** | `paintpalette.fill` / `Palette` / `Palette` | 1 / Multi | 1–30 | 💎 |
| 11 | **Draw & Rush** | `pencil.and.scribble` / `Draw` / `Pencil` | 1 / Multi | 2–12 | 💎 |

### Game modes
- **1 Phone (Single Device)** — everyone plays on one device, passing it. Works on iOS, Android, and even the web on a laptop or tablet.
- **Multi Phone (Multi Device)** — each player on their own device (any mix of iOS / Android / Web), synced via Firestore + Realtime Database.
- **Team Mode** — split into 2 teams and compete.

### Matchflow state machine (shared by all games, identical on all clients)
```
intro → passToNextPlayer → liveRound → roundResult → (loop) → finished
```

Per-game state is stored in strongly-typed structs (Swift), data classes (Kotlin), and TypeScript types. All three clients write the same shape to Firestore so any platform can host and any platform can join.

### Multiplayer rooms
- Each room: `id`, 6-char `code`, `game`, `mode`, `hostID`, `hostName`, `hostPlatform` (`ios`/`android`/`web`), `players[]`, `access` (private/public), `status` (draft/waiting/full/starting/inProgress/completed/cancelled), `minPlayers`, `maxPlayers`, `message`, `invitedFriendIDs`.
- Firestore collections: `/rooms/{roomId}`, `/rooms/{roomId}/players/{uid}`, `/rooms/{roomId}/state/current`, `/rooms/{roomId}/events/{autoId}`.
- Public rooms appear in the Friends tab (filtered: `access == "public"` and `status in ["waiting","starting"]`).
- Join by code, by invite link, tapping a public room, or clicking a shared web URL (`https://8partyplay.app/r/<code>` auto-opens the native app on iOS/Android via universal links or falls back to the web client).
- `SessionResilienceService` (per platform) watches the Firestore connection, auto-reconnects, shows a reconnect banner, offers "rejoin" when a session is interrupted.
- Host-left detection: if host disconnects > grace period, show "Host Left" alert. Optional **host migration** promotes the next player if the host stays offline past the timeout.
- Rematch: after a session ends, start a new session with same players & game.

---

## 4. Party Tools

A 3-column grid at the top of the Tools tab. Each opens as a sheet / modal with a Done button. Dark-only styling.

1. **Dice** — roll 1–4 dice, physics/tumbling animation, haptics, sound. Orange accent.
2. **Bottle Spinner** — a vertical beer-bottle image (cap on top) spins and points at a player. Pink accent.
3. **Hourglass Timer** — adjustable timer, flipping hourglass animation, optional sound at zero. Cyan accent.
4. **Coin Flip** — flip between **Heads** (`5bi465cwzmc67jtcmnxco.png`) and **Tails** (`sq46dl6bh1k6olsges2hi.png`). Both outcomes possible. Yellow accent.
5. **Team Splitter** — enter names, choose team count, randomize with shuffle animation. Green accent.

All five tools must work offline. No backend calls except for telemetry events.

---

## 5. Card Decks

Tools tab hosts card decks below the tools grid.

- **Categories:** Act (purple), Talk (blue), Challenges (orange), Penalty (red), Couple (pink).
- Each category has subtypes (Act → pantomime, dare, funny action; Talk → starters, personal, discussion, truth, explain/guess, icebreaker; etc.).
- Cards ship in `deck.json` bundled in every client build.
- Tap a deck → swipeable card-stack UI with shuffle, save, share, skip.
- **Saved** sheet lists user-saved cards (synced through Firestore `/users/{uid}/savedCards/*` — visible on every platform).
- Locked decks show a lock overlay and open the paywall.

---

## 6. AI Card Generator (Factory Tab)

- Pick **category + subtype + vibe + audience** → AI generates 5–10 fresh card prompts.
- AI call goes through a **Cloud Function** (`generateCards`) that holds the server-side API key. Client sends Firebase ID token in `Authorization: Bearer`. Same function called from iOS, Android, and Web.
- Save generated cards to `/users/{uid}/savedCards/{id}`.
- Premium: unlimited generations. Free: 3/day quota enforced server-side.

---

## 7. Friends & Social

- **Offline friends:** locally-stored display names for single-device games. CRUD list. "Me" is pinned. Stored in platform storage (UserDefaults / DataStore / IndexedDB), optionally mirrored to Firestore for cross-device parity.
- **Online friends:** search by username, email, or `publicUserID`. Send/accept/decline requests. Green online dot.
  - Firestore: `/friendships/{id}` — `requesterID`, `recipientID`, `state` (pending/accepted/blocked), `createdAt`, `updatedAt`.
- **Invites:** push via FCM + incoming invites list in Friends tab. FCM wired on iOS (APNs), Android (native FCM), and Web (FCM Web SDK + Service Worker).
- **Public Rooms** section shows all open multiplayer rooms to join.
- **Invite Friends** card in Wallet: share-link that earns +30⭐ when a new user signs up with the invite code — share sheet on iOS, share intent on Android, Web Share API on web.

---

## 8. Economy: Stars & Subscriptions

### Stars (⭐)

- Currency unit: **Star (⭐)**.
- **Earn:** purchase packs, daily reward, subscription bonus, invite reward, sign-up bonus, admin adjustment.
- **Spend:** unlock premium games one-off, unlock premium card decks, consume AI card generations.
- Balance + history stored at `/users/{uid}/starTransactions/{id}` and denormalized `/users/{uid}.stars`.
- Cloud Function handles every spend/grant atomically (Firestore transaction) to prevent race conditions and negative balances.
- Balance is always fetched live from Firestore; every client listens to the user doc so all platforms stay in sync in real time.

### Subscriptions & Payments

Entitlements are platform-agnostic — the user gets the same `subscriptionTier` regardless of where they paid.

**iOS — RevenueCat (StoreKit):**
- Tiers: monthly, yearly. Each grants a periodic star bonus and unlocks all premium games & decks.
- `StoreViewModel` wires RevenueCat delegates to `AppViewModel`:
  - `onStarsGranted(amount, tier, periodKey, expiresAt)` — credits stars if `periodKey` not already claimed.
  - `onStarPackPurchased(amount, productID)` — credits stars for consumable packs.
- `revenueCatWebhook` Cloud Function writes entitlement to `/users/{uid}`.

**Android & Web — Stripe:**
- Stripe Products mirror the RevenueCat offerings (same prices, same billing intervals).
- **Web** uses Stripe Checkout (redirect) + Stripe Customer Portal (manage billing).
- **Android** uses the Stripe Android SDK + Payment Sheet (Google Pay supported). Fallback to Stripe Checkout in a Custom Tab if Play Store build forbids external payments.
- `stripeWebhook` Cloud Function verifies signatures, idempotently credits stars and writes `subscriptionTier` / `subscriptionExpiresAt`.
- Full details in `19_STRIPE_PAYMENTS_PROMPT.md`.

**Paywall** screen with tier cards, feature list, restore purchases (iOS) / manage billing (Android + Web), legal links. Follows each store's review guidelines. Star Pack purchase detail sheet shows pack, price, confirm button.

> **NO XP.** Do not implement XP, levels, or level-up anywhere. Track only: `matchesPlayed`, `wins`, `stars`.

---

## 9. Profile Sheet

Content inside the profile sheet / drawer (identical on every platform):

- Avatar (SF Symbol / Material icon / Lucide icon, or uploaded image — Firebase Storage `/avatars/{uid}.jpg`), editable username.
- Stats: total matches, wins, star balance.
- Wallet section: star balance, membership status, Invite Friends, Restore Purchases (iOS) / Manage Subscription (Android Stripe + Web, links to Stripe Customer Portal).
- Settings: language, sound toggle, haptics toggle (iOS + Android), notifications toggle, appearance (always dark).
- Legal: Privacy Policy, Terms of Service — in-app web view on iOS, Custom Tab on Android, dedicated page on web.
- Sign out / Delete account (Cloud Function soft-deletes then purges after 30 days — **required for App Store + Google Play compliance**).

---

## 10. Architecture & Tech Stack

### Shared
- Single **Firebase** project; shared Firestore schema; shared Cloud Functions; shared FCM topics; shared Remote Config.
- Same domain model on all clients (games, modes, rooms, players, star transactions, card categories, etc.).
- All platform-specific secrets (RevenueCat key, Stripe publishable key) loaded from environment config at build time — never hardcoded.

### iOS
- **MVVM** with `@Observable` (not `ObservableObject`).
- **Strict concurrency:** data/Codable types `nonisolated`, ViewModels `@MainActor`.
- **Models:** `GameType`, `GameMode`, `GameRoom`, `PlayerProfile`, `GameSession`, `GameRound`, `StarTransaction`, `Friend`, `FriendRequest`, `CardCategory`, `CardSubtype`, per-game state structs.
- **Services:** `FirebaseAuthService`, `FirebaseDatabaseService`, `FirebaseRealtimeService`, `CasualRoomService`, `SessionResilienceService`, `NotificationService`, `SoundManager`, `FeedbackService`, `DeviceTokenStore`, `MultiplayerTelemetry`, `MemoryPathGenerator`.
- **SPM Packages:** `firebase-ios-sdk`, `GoogleSignIn-iOS`, `purchases-ios-spm` (RevenueCat).
- **Config:** `GoogleService-Info.plist` in Xcode target. RevenueCat iOS key via `Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY`.

### Android
- **MVVM** with `ViewModel` + `StateFlow` / `SharedFlow`.
- **Jetpack Compose** UI, Material 3 dark theme.
- **Services:** Kotlin equivalents of every iOS service.
- **Gradle dependencies:** `firebase-bom`, `firebase-auth`, `firebase-firestore`, `firebase-database`, `firebase-messaging`, `firebase-functions`, `firebase-storage`, `firebase-appcheck-playintegrity`, `play-services-auth`, `stripe-android`, `stripe-paymentsheet`.
- **Config:** `google-services.json` in `app/`. Stripe publishable key via `BuildConfig.STRIPE_PUBLISHABLE_KEY`.
- Full spec in `17_ANDROID_APP_PROMPT.md`.

### Web
- **Next.js 14 App Router**, **React 18**, **TypeScript**, **Tailwind**, `shadcn/ui`, **Framer Motion** for animations.
- **Firebase JS SDK v10** (modular).
- **Stripe.js** + `@stripe/react-stripe-js` + server-side Stripe Node SDK in Next.js route handlers.
- Installable **PWA** with offline fallback and installable icon (from `h03kekxe8ymunf0mls4b3.png`).
- Full spec in `18_WEB_APP_PROMPT.md`.

### Design system
See `02_DESIGN_SYSTEM_PROMPT.md` — includes tokens for SwiftUI, Compose, and Tailwind so every client renders the same palette, typography, and spacing.

---

## 11. Firestore Schema

```
/users/{uid}
  username: string
  usernameLower: string           // for case-insensitive search
  email: string | null
  publicUserID: int               // unique, auto via Cloud Function counter
  avatarURL: string | null
  stars: int
  subscriptionTier: "none"|"monthly"|"yearly"
  subscriptionSource: "apple"|"stripe"|null
  subscriptionExpiresAt: timestamp | null
  stripeCustomerID: string | null
  createdAt: timestamp
  lastActiveAt: timestamp
  matchesPlayed: int
  wins: int
  platforms: { ios?: timestamp, android?: timestamp, web?: timestamp }

/users/{uid}/starTransactions/{id}
  amount, type, description, referenceID, source ("apple"|"stripe"|"system"), timestamp

/users/{uid}/savedCards/{id}
  category, subtype, text, createdAt

/users/{uid}/deviceTokens/{tokenId}
  token, platform ("ios"|"android"|"web"), createdAt

/usernames/{usernameLower}        → { uid }   // uniqueness guard
/publicIDs/{publicUserID}         → { uid }

/friendships/{id}
  requesterID, recipientID, state, createdAt, updatedAt
  // composite index (recipientID, state) for incoming requests

/rooms/{roomId}
  code, game, mode, hostID, hostName, hostPlatform, access, status,
  minPlayers, maxPlayers, message, createdAt, startedAt, closedAt,
  invitedFriendIDs: [uid]

/rooms/{roomId}/players/{uid}
  username, platform, isHost, isReady, isOnline, score, joinedAt

/rooms/{roomId}/state/current
  currentRoundIndex, phase, secondsRemaining,
  perGameState (union by game type), stateVersion, updatedAt

/rooms/{roomId}/events/{autoId}
  actorID, type, payload, createdAt

/invites/{id}
  code, roomID, createdBy, maxUses, usedBy: [uid], expiresAt

/roomCodes/{code} → { roomID }    // quick-join lookup

/stripeCustomers/{uid}
  stripeCustomerID, defaultPaymentMethod, createdAt

/stripeEvents/{eventId}           // idempotency log for webhook
  type, processedAt

/adminConfig/remote               // feature flags, version gates, maintenance mode
```

**Firestore security rules** must enforce:
- Only owner can write `/users/{uid}` (except `lastActiveAt`, `stars`, `subscription*`, `stripeCustomerID` from Cloud Functions).
- `starTransactions` and `stars` only writable by Cloud Functions (App Check enforced).
- Rooms: only host mutates `/state/current`; only authenticated room members append `/events/*`; code lookup is public read-only.
- Friendships: only the two involved users can read; only requester creates `pending`; only recipient flips to `accepted`.
- `/stripeCustomers/*` and `/stripeEvents/*` — server-only.

Enable **Firebase App Check** (DeviceCheck / App Attest on iOS, Play Integrity on Android, reCAPTCHA v3 on web) on every Firestore and Functions call.

---

## 12. Cloud Functions (TypeScript)

See `03_FIREBASE_SETUP_PROMPT.md` and `19_STRIPE_PAYMENTS_PROMPT.md` for full source. Summary:

- `onUserCreate` — Auth trigger: create user doc, assign `publicUserID`, signup bonus ⭐.
- `redeemInviteCode(code)` — validate, join room, reward referrer.
- `spendStars({ amount, reason })` / `grantStars(...)` — atomic Firestore transaction.
- `searchUsers(query)` — case-insensitive search with rate limit.
- `sendFriendRequest`, `respondFriendRequest` — write friendships + FCM push.
- `startRoom`, `closeRoom`, `kickPlayer` — host-only room mutations.
- `generateCards({ category, subtype, vibe, count })` — AI provider call with server secret + daily quota.
- `revenueCatWebhook` — receives RevenueCat webhooks, grants subscription stars idempotently (iOS).
- **`stripeWebhook`** — receives Stripe webhooks (`checkout.session.completed`, `customer.subscription.created|updated|deleted`, `invoice.paid`), verifies signature with `STRIPE_WEBHOOK_SECRET`, updates `/users/{uid}` and logs `/stripeEvents/{eventId}` for idempotency.
- **`createStripeCheckoutSession`** — callable, creates a Checkout Session for a subscription tier or star pack; returns `url`.
- **`createStripePortalSession`** — callable, returns a Billing Portal URL for the signed-in user.
- `dailyReward` — scheduled function grants +5⭐ to eligible users daily.

---

## 13. Website (Next.js) — Marketing + App + Legal

The `website/` folder contains the Next.js + Tailwind site. It is both the **marketing site** and the **full web app**.

- Logo everywhere (favicon, OG, header, hero).
- Hero: "Your phone is the party." CTA → App Store link + Google Play link + "Play on web".
- Feature grid (11 games with screenshots), Tools strip, Testimonials, FAQ.
- **`/app`** — the full web app (games, tools, cards, friends, factory, profile). Same Firebase + Stripe integration as the native apps.
- **Invite landing page** at `/invite?code=...` — deep-links into the native app or opens the web app (code persisted in localStorage).
- **Privacy Policy** and **Terms of Service** pages aligned with Apple + Google review.
- Dark theme, modern, Apple-like.
- Deployed to Vercel. PWA manifest + Service Worker for installability and offline-friendly tools.

Full spec in `18_WEB_APP_PROMPT.md`.

---

## 14. Visual Design

See `02_DESIGN_SYSTEM_PROMPT.md` for the full spec and per-platform tokens. Summary:

- **Background:** `AppBackgroundView` — deep near-black + animated mesh gradient (blue/indigo/purple/pink) + blurred blob highlights. Same recipe in SwiftUI (`MeshGradient`), Compose (`Brush.linearGradient` + blur), and web (`radial-gradient` + `backdrop-blur`).
- **Cards:** translucent material at 72% opacity, 18pt corners, 1pt hairline border `white.opacity(0.05)`.
- **Game cards:** per-game accent gradient, 18pt corners, 1:1 aspect ratio.
- **Typography:** bold condensed display for titles; SF Pro / Roboto / Inter for body. Varied weights for hierarchy.
- **Icons:** SF Symbols (iOS) / Material Symbols (Android) / Lucide (web). Each icon in the game table lists all three.
- **Special assets:**
  - App icon / splash: `h03kekxe8ymunf0mls4b3.png`.
  - Coin Heads: `5bi465cwzmc67jtcmnxco.png` / Coin Tails: `sq46dl6bh1k6olsges2hi.png`.
  - Bottle: vertical beer-bottle transparent PNG (cap pointing up).

---

## 15. Accessibility & Polish

- Dynamic Type (iOS) / scalable `sp` text (Android) / `rem` + `prefers-reduced-motion` (web) on every body text.
- VoiceOver / TalkBack / ARIA labels on every interactive control.
- Haptic feedback for taps, correct/wrong, win, countdown on iOS and Android; soft visual feedback on web.
- Sound globally mutable from the profile (Sound toggle).
- Portrait only on phones. Tablet + desktop web adapt to landscape layouts.
- Global tap/pan gesture dismisses keyboard (iOS `AppDelegate.installGlobalKeyboardDismissGestures`, Android `WindowInsetsController`, web `onClickOutside`).
- iOS 26 `glassEffect` with `.ultraThinMaterial` fallback; Android `BlurBehind` with solid fallback; web `backdrop-blur` with solid fallback.

---

## 16. Analytics

Firebase Analytics events (fired from all three clients with a `platform` parameter):
`onboarding_completed`, `auth_success(provider)`, `game_started(game, mode)`, `game_finished(game, mode, duration, players)`, `stars_spent`, `stars_purchased(pack, source)`, `subscription_started(tier, source)`, `invite_sent`, `invite_redeemed`, `room_joined`, `card_generated_ai`, `stripe_checkout_opened`, `stripe_checkout_completed`, `stripe_portal_opened`.

Crashlytics enabled on iOS and Android. Web uses Firebase Performance Monitoring + Sentry (optional).

---

## 17. Non-Functional Requirements

- Offline-first for single-device flows on every client; only multiplayer requires Firestore.
- All network errors → structured error → user-friendly toast; never show raw errors.
- Retry with exponential backoff on transient Firestore errors.
- No hardcoded secrets. `GoogleService-Info.plist` in iOS target, `google-services.json` in Android, public Firebase config in web (server secrets in Vercel env). RevenueCat key via `Config`. Stripe publishable keys in each client, Stripe secret + webhook secret server-side only. AI keys server-side only.
- App Store review readiness: `PrivacyInfo.xcprivacy`, entitlements, Sign in with Apple wherever other third-party sign-ins are offered, Delete Account flow, working Restore Purchases, age-appropriate content filter for AI-generated cards.
- Google Play review readiness: Data Safety form, Play Integrity App Check, Delete Account flow, Play Billing Library if Play build is used (else Stripe with compliant disclosure).
- Web: GDPR cookie notice, consent for analytics, SSL enforced, HSTS.

---

## 18. Deliverables

1. **iOS** Xcode project **8PartyPlay** (Swift + SwiftUI, iOS 18+, dark mode) — full feature set.
2. **Android** Gradle project **8PartyPlay** (Kotlin + Compose, min SDK 29, dark theme) — full feature set.
3. **Web** Next.js app in `website/` — marketing + legal + `/app` (full feature set).
4. **Firebase** project: Auth, Firestore, Realtime DB, Functions, Storage, Messaging, Remote Config, App Check, Analytics.
5. **Cloud Functions** (TypeScript) deployed — including `stripeWebhook`, `createStripeCheckoutSession`, `createStripePortalSession`.
6. **RevenueCat** offerings: monthly + yearly subscriptions + consumable star packs (iOS).
7. **Stripe** products mirroring RevenueCat: same monthly/yearly prices + star packs (Android + Web).
8. All 11 games implemented on all three clients with setup + session views and ViewModels.
9. Party Tools (Dice, Bottle, Hourglass, Coin, Team Splitter) with specified assets on all clients.
10. Card decks + AI generator working on all clients.
11. Friends, invites, rooms, rematch, reconnect — wired end-to-end across iOS + Android + Web.

Build it cleanly, Apple-quality on iOS, Material-3 crisp on Android, Vercel-grade on web, no "AI slop" aesthetic. Every screen should feel like a first-class native app on its platform, and the three clients should feel like siblings — not copies.
