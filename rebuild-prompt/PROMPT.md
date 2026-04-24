# 8PartyPlay — Full Rebuild Prompt (Firebase Edition)

Use this prompt to rebuild the entire app from scratch, native iOS (Swift + SwiftUI), with **Firebase** as the backend (instead of the original Supabase backend). Target iOS 18+, dark mode only.

---

## 1. High-Level Summary

**8PartyPlay** is a premium native iOS party-game app that turns one or multiple iPhones into a social game console. It bundles 11+ original mini-games, party tools (dice, coin, bottle, hourglass, team splitter), a shuffled Truth-or-Dare style card deck library, an AI card generator, a star/XP economy, subscriptions, friends and multiplayer with rooms & invite codes.

- **Platform:** iOS 18+ (iPhone), SwiftUI, dark mode only, MVVM with `@Observable`.
- **Language:** English (UI). The app is fully localized to English; the code uses a `AppLanguage` enum so more languages can be added later.
- **Backend:** **Firebase** (Auth, Firestore, Realtime Database or Firestore listeners, Cloud Functions, FCM, Storage, Remote Config).
- **Monetization:** RevenueCat (in-app purchases & subscriptions) + Star economy.
- **Theme:** Dark, Apple-native feel, viral/bold title typography, glass / `.ultraThinMaterial` cards, iOS 26 Liquid Glass when available, otherwise graceful fallback.
- **Brand logo:** `h03kekxe8ymunf0mls4b3.png` (provided separately; use for app icon, splash, website favicon).

---

## 2. Information Architecture

Bottom TabView with 4 tabs:

1. **Games** — `gamecontroller.fill` — game library grid + "Join with Code" button + mode filter chips (All / 1 Phone / Multi Phone / Team Mode) + a segmented switch between **Games** (playable) and **Ideas** (party game tutorials).
2. **Tools** — `wrench.and.screwdriver.fill` — Party Tools grid (Dice, Bottle, Hourglass, Coin Flip, Team Splitter) + Card decks library.
3. **Friends** — `person.2.fill` (with badge for pending requests) — Quick Join card, Offline Friends, Online Friends search/add, Public Rooms browser.
4. **Factory** — `wand.and.stars` — AI Card Generator (generates new card prompts using AI based on category + vibe).

A floating **Profile** button (user avatar) is always top-right on every root screen. It opens a `.sheet` showing profile, stats, language, sound, notifications, legal, sign-out.

A top banner appears when network is `reconnecting` or `disconnected`.

---

## 3. Onboarding & Auth

- **Splash** — gamecontroller icon, "8PartyPlay" viral title, progress spinner.
- **Onboarding** — single screen that asks for a display name. On completion, request notification permission.
- **Auth screen** with 4 providers (implement via Firebase Auth):
  - **Username** — email + password (Firebase email/password provider).
  - **Google** — GoogleSignIn SDK + Firebase `GoogleAuthProvider`.
  - **Apple** — Sign in with Apple + Firebase `OAuthProvider("apple.com")`.
  - **Guest** — Firebase `signInAnonymously()`. Guests can play single-device games, but need to log in to use online features (friends, public rooms, multi-device).
- After sign-up: seed a user profile document in Firestore at `/users/{uid}` with `username`, `email`, `publicUserID` (auto-incremented int via a Cloud Function), `avatarURL`, `createdAt`, `stars: 0`, and create a signup-bonus star transaction.
- Handle OAuth callback URLs and **invite deep links** (`https://8partyplay.com/invite?code=ABCD` and custom scheme `partyplay://invite?code=ABCD`).

---

## 4. Game Library (Games Tab)

Grid of 2-column cards. Each card: bold viral title, centered SF Symbol in rounded square, mode icons row (1 Phone / Multi Phone / Team), player count text. Locked games show a transparent **lock badge (top-right)**. Locked games are sorted to the bottom. Tapping a card navigates to a detail screen with description, hero image, mode picker, player setup, and **Play** button.

### Game list

| Game | Symbol | Modes | Players | Free | Description |
|---|---|---|---|---|---|
| **Reverse Singing** | `backward.fill` | 1 Phone | 2–30 | ✅ | Pass the phone. Record anything. Hear it reversed. Mimic it. Compare the chaos. |
| **Guess the Seconds** | `stopwatch.fill` | 1 Phone | 2–30 | ✅ | Choose a target time, hide it, count in your head, then stop as close as you can. |
| **Imposter** | `eye.fill` | 1 Phone | 4–30 | ✅ | One player is the Imposter — find them. Has Discussion Mode and Clue Mode, category packs (Animals/Food/Places/Jobs/Movies/Random). |
| **Memory Grid** | `square.grid.3x3.fill` | 1 / Multi / Team | 1–30 | ✅ | Flip tiles, find matching pairs, race the clock. |
| **Ten Tangle** | `theatermasks.fill` | 1 Phone | 3–11 | 💎 Premium | Get a secret 1–10, act it out, fool the guesser. |
| **Memory Path** | `map.fill` | 1 / Multi / Team | 2–30 | 💎 | Find the hidden path from start to end — one wrong step and you restart. |
| **Pass & Guess** | `text.bubble.fill` | 1 Phone | 2–30 | 💎 | Pass one phone, write private answers, then guess who wrote each. |
| **Tap in Order** | `number.square.fill` | 1 / Multi | 1–30 | 💎 | Race to tap numbered tiles in order. Same board for every player. |
| **Color Trap** | `paintpalette.fill` | 1 / Multi | 1–30 | 💎 | Tap every color except the forbidden one. Three strikes and you're out. |
| **Draw & Rush** | `pencil.and.scribble` | 1 / Multi | 2–12 | 💎 | One player draws a secret concept while everyone else rushes to guess. |
| **Truth & Dare** | `arrow.triangle.2.circlepath` | 1 Phone | 3–12 | ✅ | Spin the bottle, get picked, pick Truth or Dare. |

### Game modes

- **1 Phone (Single Device)** — everyone plays on one phone, passing it.
- **Multi Phone (Multi Device)** — each player on their own phone, synced via Firestore realtime listeners / Realtime Database presence.
- **Team Mode** — split into 2 teams and compete (team score + shared turn).

### Matchflow

Each game shares this state machine (see `GameSession`):

```
intro → passToNextPlayer → liveRound → roundResult → (loop) → finished
```

Per-game state is stored in strongly-typed structs (`FakeAnswerRoundState`, `PassGuessRoundState`, `ImposterRoundState`, `GuessTheSecondsGameState`, `MemoryGridGameState`, `MemoryPathGameState`, `TapInOrderGameState`, `ColorTrapGameState`, `SpinBottleState`, `DrawRushState`, `TenTangleState`, etc.). Each with its own ViewModel (`CasualRoomViewModel`, `ColorTrapViewModel`, `DrawRushViewModel`, `MemoryGridViewModel`, `MemoryPathViewModel`, `TapInOrderViewModel`, `TenTangleViewModel`, `CardsViewModel`, `StoreViewModel`, and a central `AppViewModel`).

### Multiplayer rooms

- Each room has: `id`, 4-char `code`, `game`, `mode`, `hostName`, `players[]`, `access` (private / public), `status` (draft/waiting/full/starting/inProgress/completed/cancelled), `minPlayers`, `maxPlayers`, `message`, `invitedFriendIDs`.
- Firestore collections:
  - `/rooms/{roomId}` — room document
  - `/rooms/{roomId}/players/{playerId}` — subcollection
  - `/rooms/{roomId}/state/{docId}` — authoritative game state (host-written)
  - `/rooms/{roomId}/events/{eventId}` — append-only turn events
- Public rooms appear in the **Public Rooms** section of the Friends tab (limited query, ordered by recency, filtered to `access == "public"` and `status in ["waiting","starting"]`).
- Join flow: quick join by code, by invite link, or by tapping a public room.
- Session resilience: `SessionResilienceService` watches Firestore connection, auto-reconnects, shows reconnect banner, offers "rejoin" prompt when a session is interrupted and the player relaunches.
- Host-left detection: if host disconnects > N seconds, show "Host Left" alert and close session.
- Rematch: after a session ends, players can hit "Rematch" which starts a new session keeping the same players & game.

---

## 5. Party Tools (Tools Tab)

A 3-column grid at the top of the Tools tab with 5 tools. Each opens as a sheet with `preferredColorScheme(.dark)` and a Done button.

1. **Dice** — roll 1 to 4 dice with physics/tumbling animation, haptics, sound. Orange accent.
2. **Bottle Spinner** — a **vertical beer-bottle glass image** (anchored to head/top side) spins and points at a player; caps its spin with dampening, plays a clink. Pink accent.
3. **Hourglass Timer** — adjustable timer, flipping hourglass animation, optional sound at zero. Cyan accent.
4. **Coin Flip** — flip a coin with physics. Use the provided **head** and **tail** asset images (two distinct sides; not both heads). Yellow accent.
5. **Team Splitter** — input a list of names, choose how many teams, randomize into teams with a shuffle animation, share result. Green accent.

---

## 6. Card Decks

Tools tab also hosts the card decks library below the tools grid.

- **Categories:** Act, Talk, Challenges, Penalty, Couple (each with accent color, SF Symbol, subtitle).
- Each category has **subtypes** (e.g. Talk → starters, personal, discussion, truth, explainGuess, icebreaker).
- Decks ship with dozens of pre-written cards (`deck.json`). Some cards are free, others premium.
- Tap a deck → swipeable card-stack UI with shuffle, save, share, skip.
- **Saved** sheet lists user-saved cards.
- Locked decks show a lock overlay and open the paywall.

### AI Card Generator (Factory Tab)

- Pick **category + subtype + vibe + audience** → AI generates 5–10 fresh prompts.
- Uses the AI skill (see `skills/ai/SKILL.md`). With Firebase, put the AI call behind a **Cloud Function** that calls the model provider with the server-side API key. Client hits `https://<region>-<project>.cloudfunctions.net/generateCards` with Firebase ID token in `Authorization: Bearer`.
- Save generated cards to `/users/{uid}/savedCards/{id}`.
- Premium users get unlimited; free users get a daily quota (e.g. 3 generations) enforced in the Cloud Function.

---

## 7. Friends & Social

- **Offline friends:** locally stored display names for Single-Device games. CRUD list. "Me" is pinned.
- **Online friends:** real users. Search by username, email, or `publicUserID`. Send/accept/decline friend requests. Shows online status (green dot).
  - Firestore: `/friendships/{id}` with `requesterId`, `recipientId`, `state` (pending/accepted/blocked), `createdAt`, `updatedAt`.
  - Use a Cloud Function to validate that users can only search users who allow discoverability, and to prevent duplicate requests.
- **Invites:** invite friends to a room; they get a push via FCM + appear in an incoming invites list.
- **Public Rooms** section shows all open multiplayer rooms you can join.
- **Invite Friends** card inside Wallet with a share-link that earns +30 ⭐ when a new user installs and signs up with your code (attribution via invite code stored on signup).

---

## 8. Economy: Stars, XP, Subscriptions

### Stars

- Currency unit: **⭐ Star**.
- Sources: purchase packs, daily reward, subscription bonus, invite reward, signup bonus, refund, admin adjustment.
- Sinks: unlock premium games, unlock premium card decks, consume AI generations.
- Balance + transaction history stored at `/users/{uid}/starTransactions/{id}` and denormalized `/users/{uid}.stars`.
- Use a Cloud Function with a Firestore transaction for every spend/grant to prevent race conditions and negative balances.

### XP per game

- Each game tracks `xp`, `level`, `matchesPlayed`, `wins` at `/users/{uid}/xp/{gameKey}`.
- Level curve via shared helper (`XPLevelCurve`): level N requires `100 * N * (N+1) / 2` XP (or similar — keep same curve as existing `XPLevelCurve`). Show progress ring in profile + post-match.

### Subscriptions (RevenueCat)

- **Tiers:** monthly, yearly, lifetime. Each grants a periodic star bonus (monthly grant, yearly grants monthly drops, lifetime grants one big drop + monthly drips) and unlocks all premium games & decks.
- `StoreViewModel` wires RevenueCat delegates to `AppViewModel`:
  - `onStarsGranted(amount, tier, periodKey, expiresAt)` → credits stars if `periodKey` not already claimed.
  - `onStarPackPurchased(amount, productID)` → credits stars for consumable star packs.
- **Paywall** screen with tier cards, feature list, restore purchases, legal links. Follows Apple review guidelines.
- **Star Pack purchase detail sheet** shows the pack, tax-inclusive price, confirm button.

---

## 9. Profile Sheet

Content inside the profile `.sheet`:

- Avatar (SF Symbol or uploaded image — upload to Firebase Storage at `/avatars/{uid}.jpg`), editable username.
- Stats: total matches, wins, per-game XP rings.
- Wallet section: star balance, membership status, Invite Friends, Restore Purchases, purchase history.
- Settings: language, sound toggle, haptics toggle, notifications toggle (opens system settings if denied), appearance (always dark).
- Legal: Privacy Policy, Terms of Service (open in-app web view).
- Sign out / Delete account (Delete account calls a Cloud Function that soft-deletes then purges after 30 days; **must be present** for App Store compliance).

---

## 10. Notifications

- **Permission** requested after onboarding.
- Local notifications for: turn reminders, timer end, invite received.
- Push (FCM): friend request, invite to room, room starting soon, subscription renewal, admin broadcasts.
- Store FCM token at `/users/{uid}/deviceTokens/{tokenId}` (`DeviceTokenStore` in the Swift code).
- Notification tap routes deep-link into the corresponding screen (invite → accept flow, friend request → friends tab).

---

## 11. Deep Linking

- Universal links on domain `8partyplay.com` (apple-app-site-association file).
- Custom scheme `partyplay://invite?code=ABCD`.
- On cold start or foreground, `onOpenURL` extracts the invite code and calls `appModel.setPendingInviteCode(code)` which opens the join flow once the user is authed & onboarded.

---

## 12. Architecture & Tech

- **MVVM** with `@Observable` classes (not `ObservableObject`).
- **Strict concurrency**: data/Codable types `nonisolated`, ViewModels on `@MainActor`.
- **Models:** `GameType`, `GameMode`, `GameRoom`, `PlayerProfile`, `GameSession`, `GameRound`, `StarTransaction`, `Friend`, `FriendRequest`, `XPProgress`, `CardCategory`, `CardSubtype`, per-game state structs.
- **Services:**
  - `FirebaseService` (Auth, Firestore, Storage, FCM, Functions wiring).
  - `FirebaseAuthService` (email/password, Google, Apple, anonymous).
  - `FirebaseDatabaseService` (users, rooms, friendships, invites, stars, XP).
  - `FirebaseRealtimeService` (room presence + game state listeners).
  - `CasualRoomService`, `SessionResilienceService`, `NotificationService`, `SoundManager`, `FeedbackService` (haptics + toasts), `DeviceTokenStore`, `MultiplayerTelemetry`, `MemoryPathGenerator`.
- **Packages (SPM):**
  - `firebase-ios-sdk` → FirebaseAuth, FirebaseFirestore, FirebaseFirestoreSwift, FirebaseFunctions, FirebaseMessaging, FirebaseStorage, FirebaseRemoteConfig, FirebaseAnalytics.
  - `GoogleSignIn-iOS`.
  - `purchases-ios-spm` (RevenueCat).
- **Configuration:** `GoogleService-Info.plist` in the Xcode target. Read public env keys via the existing `Config.swift` (RevenueCat iOS key, invite host, etc.).
- **Design system:** `DesignSystem.swift` with `AppBackgroundView`, `SurfaceCard`, `SectionHeaderView`, `StatusPillView`, `CardPressStyle`, `SecondaryActionButtonStyle`, `ViralTitleStyle` (custom bold font), `ProfileToolbarButton`, `ConnectionBannerView`, `ToastOverlay`, `FirstTimeHintOverlay`, `CompactLibraryTabGlassEffect` (uses `glassEffect` when `#available(iOS 26.0, *)` else falls back to `.ultraThinMaterial`).
- **Sound/Haptics:** `SoundManager` plays tab-switch, navigation, win, fail, countdown tick, tool-specific SFX. Haptics via `.sensoryFeedback`.

---

## 13. Firestore Schema (replace Supabase tables)

```
/users/{uid}
  username: string
  usernameLower: string       // for case-insensitive search
  email: string | null
  publicUserID: int            // unique, auto via counter
  avatarURL: string | null
  stars: int
  subscriptionTier: "none"|"monthly"|"yearly"|"lifetime"
  subscriptionExpiresAt: timestamp | null
  createdAt: timestamp
  lastActiveAt: timestamp

/users/{uid}/starTransactions/{id}
  amount, type, description, referenceID, timestamp

/users/{uid}/xp/{gameKey}
  gameKey, gameName, xp, matchesPlayed, wins

/users/{uid}/savedCards/{id}
  category, subtype, text, createdAt

/users/{uid}/deviceTokens/{tokenId}
  token, platform, createdAt

/usernames/{usernameLower}        -> { uid }   // uniqueness guard
/publicIDs/{publicUserID}         -> { uid }

/friendships/{id}
  requesterID, recipientID, state, createdAt, updatedAt
  // composite index (recipientID, state) for incoming requests

/rooms/{roomId}
  code, game, mode, hostID, hostName, access, status,
  minPlayers, maxPlayers, message, createdAt, startedAt, closedAt,
  invitedFriendIDs: [uid]

/rooms/{roomId}/players/{uid}
  username, isHost, isReady, isOnline, score, joinedAt

/rooms/{roomId}/state/current
  currentRoundIndex, phase, secondsRemaining, liveState,
  perGameState (union by game type), stateVersion, updatedAt

/rooms/{roomId}/events/{autoId}
  actorID, type, payload, createdAt

/invites/{id}
  code, roomID, createdBy, maxUses, usedBy: [uid], expiresAt

/roomCodes/{code} -> { roomID }     // lookup for quick join

/adminConfig/remote                 // flags, version gates, maintenance
```

**Firestore rules** must enforce:

- Only the owner can write their `/users/{uid}` document (except `lastActiveAt` from trusted functions).
- `starTransactions` and `stars` only writable by **Cloud Functions** (use `request.auth.token.admin` or check caller is a callable function via App Check).
- Rooms: only host can mutate `/state/current`, only authenticated players in the room can append `/events/*`, code lookup is public read-only.
- Friendships: only the two involved users can read, only the requester can create `pending`, only recipient can flip to `accepted`.

Enable **Firebase App Check** (DeviceCheck/App Attest) on every Firestore & Functions call.

---

## 14. Cloud Functions (Node / TypeScript)

- `onUserCreate` (Auth trigger) — create user doc, assign `publicUserID`, signup bonus ⭐.
- `redeemInviteCode(code)` — validate, join room, reward referrer.
- `spendStars({ amount, reason })` / `grantStars(...)` — atomic transaction.
- `searchUsers(query)` — case-insensitive username/email/publicUserID search with rate limit.
- `sendFriendRequest`, `respondFriendRequest` — write friendships + FCM push.
- `startRoom`, `closeRoom`, `kickPlayer` — host-only room mutations.
- `generateCards({ category, subtype, vibe, count })` — calls AI provider with server secret; enforces daily quota.
- `revenueCatWebhook` — receives RevenueCat webhooks, grants subscription stars idempotently (keyed by `periodKey`).
- `dailyReward` — scheduled function pings eligible users with a +5 ⭐ daily reward (optional pull-model from client instead).

---

## 15. Website (Next.js) — Marketing + Legal

The `website/` folder contains the marketing site (Next.js + Tailwind). It must:

- Use the same **8PartyPlay logo** everywhere (favicon, OG image, header, hero).
- Hero with the tagline "Your iPhone is the party." CTA → App Store link.
- Feature grid (11 games with screenshots), Tools strip (Dice/Bottle/Hourglass/Coin/Teams), Testimonials, FAQ.
- **Invite landing page** at `/invite?code=...` that deep-links into the iOS app or falls back to the App Store with the code persisted in local storage.
- **Privacy Policy** and **Terms of Service** pages aligned with Apple review (in-app purchases, subscriptions, user-generated content moderation, account deletion, age rating 12+, data collection disclosure).
- Dark theme, modern, Apple-like.

---

## 16. Visual Design

- **Background:** `AppBackgroundView` — deep near-black base with a subtle animated mesh gradient (blue/indigo/purple/pink) plus blurred blob highlights.
- **Cards:** `.ultraThinMaterial.opacity(0.72)` over the bg, 18pt rounded rects, 1pt hairline border `.white.opacity(0.05)`.
- **Game cards:** per-game accent gradient (pink/red/purple, cyan/mint, teal/green/mint, orange/red/yellow, red/pink/orange, yellow/orange/red, purple/indigo/pink, blue/indigo/purple). Rounded 18pt, 1:1 aspect, lock badge top-right when locked.
- **Typography:** `viralTitleStyle` — bold condensed display font for titles; SF Pro rounded/default for body. Varied weights (black, bold, semibold, medium) for hierarchy.
- **Tint:** system `.blue` unless a screen has a dominant accent.
- **Symbols:** SF Symbols throughout; use filled variants; gradient foregrounds for hero icons.
- **Iconography of this app:**
  - Use the provided 8PartyPlay logo (`h03kekxe8ymunf0mls4b3.png`) for app icon, splash, About dialog.
  - Truth & Dare uses a vertical **beer-bottle glass** bottle spinner with the cap pointing at the head direction.
  - Coin Flip uses the provided **head** (`5bi465cwzmc67jtcmnxco.png`) and **tail** (`sq46dl6bh1k6olsges2hi.png`) images on opposite faces.

---

## 17. Accessibility & Polish

- Dynamic Type support on body text.
- VoiceOver labels on every tappable control.
- Haptic feedback for taps, correct/wrong, win, countdown.
- Sound can be muted globally from the profile.
- Landscape not required; portrait only.
- Keyboard: a global tap/pan gesture dismisses the keyboard (`AppDelegate.installGlobalKeyboardDismissGestures`).
- iOS 26 `glassEffect` used where available, `.ultraThinMaterial` fallback.

---

## 18. Analytics & Telemetry

- Firebase Analytics events: `onboarding_completed`, `auth_success(provider)`, `game_started(game, mode)`, `game_finished(game, mode, duration, players)`, `stars_spent`, `stars_purchased(pack)`, `subscription_started(tier)`, `invite_sent`, `invite_redeemed`, `room_joined`, `card_generated_ai`.
- `MultiplayerTelemetry` writes aggregated room health metrics to Firestore for admin dashboard.

---

## 19. Non-Functional Requirements

- Offline-first for Single-Device flows: the UI must continue to work without network; only multiplayer requires Firestore.
- All network calls use structured error → toast mapping; never show raw errors.
- Retry with exponential backoff on transient Firestore errors.
- No hardcoded secrets; use `GoogleService-Info.plist`, RevenueCat public key via `Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY`, AI provider key lives server-side in Cloud Functions only.
- App Store review readiness: privacy manifest (`PrivacyInfo.xcprivacy`), entitlements, Sign in with Apple as an option wherever other third-party sign-ins are offered, Delete Account flow, working Restore Purchases, age-appropriate content filter for AI-generated cards.

---

## 20. Deliverables

1. A fresh iOS Xcode project named **8PartyPlay** (Swift + SwiftUI, iOS 18+, dark mode).
2. Firebase project set up with Auth, Firestore, Functions, Storage, Messaging, App Check.
3. Cloud Functions source (TypeScript) deployed.
4. RevenueCat offerings configured for monthly/yearly/lifetime + star packs.
5. `website/` marketing site deployed with updated logo and legal pages.
6. All 11 games implemented with their respective setup + session views and ViewModels listed in **Section 12**.
7. Party Tools (Dice, Bottle, Hourglass, Coin, Team Splitter) implemented with the specified assets.
8. Card decks + AI generator working.
9. Friends, invites, rooms, rematch, reconnect — all wired end-to-end.
10. Existing App Store screenshots in `screenshots/iphone/en/` remain valid: `01_dice_roller`, `02_bottle_spinner`, `03_hourglass_timer`, `04_coin_flip` — extend as needed.

Build it cleanly, Apple-quality, with no "AI slop" aesthetic. Every screen should feel like a first-class native iOS app.
