# 8PartyPlay — Full Rebuild Prompt (Firebase Edition)

Use this prompt to rebuild the entire app from scratch, native iOS (Swift + SwiftUI), with **Firebase** as the backend. Target iOS 18+, dark mode only.

**Read all sibling prompt files together:**
- `GAMES_DETAILED_PROMPT.md` — every game screen, button, timer, animation, scoring rule.
- `MULTI_DEVICE_PROMPT.md` — realtime rooms, multi-device sync, reconnection.
- `APP_EVERYTHING_ELSE_PROMPT.md` — navigation shell, tools, cards, friends, wallet, subscriptions.
- `DESIGN_SYSTEM_PROMPT.md` — full design system, colors, typography, components.
- `FIREBASE_SETUP_PROMPT.md` — Firebase config, Firestore rules, Cloud Functions source.
- `ONBOARDING_AUTH_PROMPT.md` — onboarding slides and auth flow screens.
- `TOOLS_CARDS_DETAILED_PROMPT.md` — party tools and card decks in full detail.
- `FACTORY_TAB_PROMPT.md` — AI game/card generator tab.
- `NOTIFICATIONS_DEEPLINKS_PROMPT.md` — push notifications, deep links, FCM.

---

## 1. High-Level Summary

**8PartyPlay** is a premium native iOS party-game app that turns one or multiple iPhones into a social game console. It bundles 11 original mini-games, party tools (dice, coin, bottle, hourglass, team splitter), a shuffled card deck library, an AI card generator, a ⭐ Star economy, subscriptions, friends, and real-time multiplayer with rooms and invite codes.

- **Platform:** iOS 18+ (iPhone), SwiftUI, dark mode only, MVVM with `@Observable`.
- **Language:** English (UI). `AppLanguage` enum is present so more languages can be added.
- **Backend:** **Firebase** — Auth, Firestore, Realtime Database (presence), Cloud Functions, FCM, Storage, Remote Config, App Check.
- **Monetization:** RevenueCat (subscriptions + consumable star packs).
- **Economy:** Stars (⭐) — earned via subscriptions, daily rewards, invites, sign-up bonus. Spent to unlock premium items one-off.
- **NO XP system.** Do not implement XP, levels, level-up animations, or per-game level progress anywhere. Remove any XP reference you encounter.
- **Theme:** Dark, Apple-native feel, viral/bold title typography, glass / `.ultraThinMaterial` cards, iOS 26 Liquid Glass when available, graceful fallback on iOS 18–25.
- **Brand logo:** `h03kekxe8ymunf0mls4b3.png` — use for app icon, splash, website favicon.

---

## 2. Information Architecture

Bottom **TabView** with 4 tabs:

1. **Games** — `gamecontroller.fill` — 2-column game library grid + "Join with Code" button + mode filter chips (All / 1 Phone / Multi Phone / Team Mode) + a segmented switch between **Games** (playable) and **Ideas** (party game tutorials).
2. **Tools** — `wrench.and.screwdriver.fill` — Party Tools grid (Dice, Bottle, Hourglass, Coin Flip, Team Splitter) + Card decks library.
3. **Friends** — `person.2.fill` (badge for pending requests) — Quick Join card, Offline Friends, Online Friends search/add, Public Rooms browser.
4. **Factory** — `wand.and.stars` — AI Card Generator + AI Party Game Idea Generator.

A floating **Profile** button (user avatar) lives top-right on every root screen. It opens a `.sheet` with profile stats, wallet, settings, legal, sign-out.

A thin top banner appears when network is `reconnecting` or `disconnected`.

---

## 3. Game Library

Grid of 2-column cards. Each card: bold viral title, centered SF Symbol in a rounded square, mode-icon chips, player count text. Locked games show a **transparent lock badge (top-right)**. Locked games are sorted to the bottom.

### Complete game list (order is exact)

| # | Game | Symbol | Modes | Players | Free |
|---|---|---|---|---|---|
| 1 | **Reverse Singing** | `backward.fill` | 1 Phone | 2 | ✅ |
| 2 | **Guess the Seconds** | `stopwatch.fill` | 1 Phone | 2–30 | ✅ |
| 3 | **Imposter** | `eye.fill` | 1 Phone | 4–30 | ✅ |
| 4 | **Memory Grid** | `square.grid.3x3.fill` | 1 / Multi / Team | 1–30 | ✅ |
| 5 | **Truth & Dare** | `arrow.triangle.2.circlepath` | 1 Phone | 3–12 | ✅ |
| 6 | **Ten Tangle** | `theatermasks.fill` | 1 Phone | 3–11 | 💎 |
| 7 | **Memory Path** | `map.fill` | 1 / Multi / Team | 2–30 | 💎 |
| 8 | **Pass & Guess** | `text.bubble.fill` | 1 Phone | 2–30 | 💎 |
| 9 | **Tap in Order** | `number.square.fill` | 1 / Multi | 1–30 | 💎 |
| 10 | **Color Trap** | `paintpalette.fill` | 1 / Multi | 1–30 | 💎 |
| 11 | **Draw & Rush** | `pencil.and.scribble` | 1 / Multi | 2–12 | 💎 |

### Game modes
- **1 Phone (Single Device)** — everyone plays on one phone, passing it.
- **Multi Phone (Multi Device)** — each player on their own phone, synced via Firestore/Realtime Database.
- **Team Mode** — split into 2 teams and compete.

### Matchflow state machine (shared by all games)
```
intro → passToNextPlayer → liveRound → roundResult → (loop) → finished
```

Per-game state is stored in strongly-typed structs. ViewModels: `CasualRoomViewModel`, `ColorTrapViewModel`, `DrawRushViewModel`, `MemoryGridViewModel`, `MemoryPathViewModel`, `TapInOrderViewModel`, `TenTangleViewModel`, `CardsViewModel`, `StoreViewModel`, central `AppViewModel`.

### Multiplayer rooms
- Each room: `id`, 6-char `code`, `game`, `mode`, `hostID`, `hostName`, `players[]`, `access` (private/public), `status` (draft/waiting/full/starting/inProgress/completed/cancelled), `minPlayers`, `maxPlayers`, `message`, `invitedFriendIDs`.
- Firestore collections: `/rooms/{roomId}`, `/rooms/{roomId}/players/{uid}`, `/rooms/{roomId}/state/current`, `/rooms/{roomId}/events/{autoId}`.
- Public rooms appear in the Friends tab (filtered: `access == "public"` and `status in ["waiting","starting"]`).
- Join by code, by invite link, or tapping a public room.
- `SessionResilienceService` watches Firestore connection, auto-reconnects, shows reconnect banner, offers "rejoin" when a session is interrupted.
- Host-left detection: if host disconnects > grace period, show "Host Left" alert.
- Rematch: after a session ends, start a new session with same players & game.

---

## 4. Party Tools

A 3-column grid at the top of the Tools tab. Each opens as a sheet (`preferredColorScheme(.dark)`) with a Done button.

1. **Dice** — roll 1–4 dice, physics/tumbling animation, haptics, sound. Orange accent.
2. **Bottle Spinner** — a vertical beer-bottle image (cap on top) spins and points at a player. Pink accent.
3. **Hourglass Timer** — adjustable timer, flipping hourglass animation, optional sound at zero. Cyan accent.
4. **Coin Flip** — flip between **Heads** (`5bi465cwzmc67jtcmnxco.png`) and **Tails** (`sq46dl6bh1k6olsges2hi.png`). Both outcomes possible. Yellow accent.
5. **Team Splitter** — enter names, choose team count, randomize with shuffle animation. Green accent.

---

## 5. Card Decks

Tools tab hosts card decks below the tools grid.

- **Categories:** Act (purple), Talk (blue), Challenges (orange), Penalty (red), Couple (pink).
- Each category has subtypes (Act → pantomime, dare, funny action; Talk → starters, personal, discussion, truth, explain/guess, icebreaker; etc.).
- Cards ship in `deck.json`. Some free, some premium.
- Tap a deck → swipeable card-stack UI with shuffle, save, share, skip.
- **Saved** sheet lists user-saved cards.
- Locked decks show a lock overlay and open the paywall.

---

## 6. AI Card Generator (Factory Tab)

- Pick **category + subtype + vibe + audience** → AI generates 5–10 fresh card prompts.
- AI call goes through a **Cloud Function** (`generateCards`) that holds the server-side API key. Client sends Firebase ID token in `Authorization: Bearer`.
- Save generated cards to `/users/{uid}/savedCards/{id}`.
- Premium: unlimited generations. Free: 3/day quota enforced server-side.

---

## 7. Friends & Social

- **Offline friends:** locally-stored display names for single-device games. CRUD list. "Me" is pinned.
- **Online friends:** search by username, email, or `publicUserID`. Send/accept/decline requests. Green online dot.
  - Firestore: `/friendships/{id}` — `requesterID`, `recipientID`, `state` (pending/accepted/blocked), `createdAt`, `updatedAt`.
- **Invites:** push via FCM + incoming invites list in Friends tab.
- **Public Rooms** section shows all open multiplayer rooms to join.
- **Invite Friends** card in Wallet: share-link that earns +30⭐ when a new user signs up with the invite code.

---

## 8. Economy: Stars & Subscriptions

### Stars (⭐)

- Currency unit: **Star (⭐)**.
- **Earn:** purchase packs, daily reward, subscription bonus, invite reward, sign-up bonus, admin adjustment.
- **Spend:** unlock premium games one-off, unlock premium card decks, consume AI card generations.
- Balance + history stored at `/users/{uid}/starTransactions/{id}` and denormalized `/users/{uid}.stars`.
- Cloud Function handles every spend/grant atomically (Firestore transaction) to prevent race conditions and negative balances.

### Subscriptions (RevenueCat)

- **Tiers:** monthly, yearly. Each grants a periodic star bonus and unlocks all premium games & decks.
- `StoreViewModel` wires RevenueCat delegates to `AppViewModel`:
  - `onStarsGranted(amount, tier, periodKey, expiresAt)` — credits stars if `periodKey` not already claimed.
  - `onStarPackPurchased(amount, productID)` — credits stars for consumable packs.
- **Paywall** screen with tier cards, feature list, restore purchases, legal links. Follows Apple review guidelines.
- **Star Pack purchase detail sheet** shows pack, price, confirm button.

> **NO XP.** Do not implement XP, levels, or level-up anywhere. Track only: `matchesPlayed`, `wins`, `stars`.

---

## 9. Profile Sheet

Content inside the profile `.sheet`:

- Avatar (SF Symbol or uploaded image — Firebase Storage `/avatars/{uid}.jpg`), editable username.
- Stats: total matches, wins, star balance.
- Wallet section: star balance, membership status, Invite Friends, Restore Purchases.
- Settings: language, sound toggle, haptics toggle, notifications toggle, appearance (always dark).
- Legal: Privacy Policy, Terms of Service (in-app web view).
- Sign out / Delete account (Cloud Function soft-deletes then purges after 30 days — **required for App Store compliance**).

---

## 10. Architecture & Tech Stack

- **MVVM** with `@Observable` (not `ObservableObject`).
- **Strict concurrency:** data/Codable types `nonisolated`, ViewModels `@MainActor`.
- **Models:** `GameType`, `GameMode`, `GameRoom`, `PlayerProfile`, `GameSession`, `GameRound`, `StarTransaction`, `Friend`, `FriendRequest`, `CardCategory`, `CardSubtype`, per-game state structs.
- **Services:** `FirebaseAuthService`, `FirebaseDatabaseService`, `FirebaseRealtimeService`, `CasualRoomService`, `SessionResilienceService`, `NotificationService`, `SoundManager`, `FeedbackService`, `DeviceTokenStore`, `MultiplayerTelemetry`, `MemoryPathGenerator`.
- **SPM Packages:**
  - `firebase-ios-sdk` → FirebaseAuth, FirebaseFirestore, FirebaseFirestoreSwift, FirebaseFunctions, FirebaseMessaging, FirebaseStorage, FirebaseRemoteConfig, FirebaseAnalytics.
  - `GoogleSignIn-iOS`.
  - `purchases-ios-spm` (RevenueCat).
- **Config:** `GoogleService-Info.plist` in Xcode target. RevenueCat iOS key via `Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY`.
- **Design system:** see `DESIGN_SYSTEM_PROMPT.md`.

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
  subscriptionExpiresAt: timestamp | null
  createdAt: timestamp
  lastActiveAt: timestamp
  matchesPlayed: int
  wins: int

/users/{uid}/starTransactions/{id}
  amount, type, description, referenceID, timestamp

/users/{uid}/savedCards/{id}
  category, subtype, text, createdAt

/users/{uid}/deviceTokens/{tokenId}
  token, platform, createdAt

/usernames/{usernameLower}        → { uid }   // uniqueness guard
/publicIDs/{publicUserID}         → { uid }

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
  currentRoundIndex, phase, secondsRemaining,
  perGameState (union by game type), stateVersion, updatedAt

/rooms/{roomId}/events/{autoId}
  actorID, type, payload, createdAt

/invites/{id}
  code, roomID, createdBy, maxUses, usedBy: [uid], expiresAt

/roomCodes/{code} → { roomID }    // quick-join lookup

/adminConfig/remote               // feature flags, version gates, maintenance mode
```

**Firestore security rules** must enforce:
- Only owner can write `/users/{uid}` (except `lastActiveAt` from Cloud Functions).
- `starTransactions` and `stars` only writable by Cloud Functions (App Check enforced).
- Rooms: only host mutates `/state/current`; only authenticated room members append `/events/*`; code lookup is public read-only.
- Friendships: only the two involved users can read; only requester creates `pending`; only recipient flips to `accepted`.

Enable **Firebase App Check** (DeviceCheck / App Attest) on every Firestore and Functions call.

---

## 12. Cloud Functions (TypeScript)

See `FIREBASE_SETUP_PROMPT.md` for full source. Summary:

- `onUserCreate` — Auth trigger: create user doc, assign `publicUserID`, signup bonus ⭐.
- `redeemInviteCode(code)` — validate, join room, reward referrer.
- `spendStars({ amount, reason })` / `grantStars(...)` — atomic Firestore transaction.
- `searchUsers(query)` — case-insensitive search with rate limit.
- `sendFriendRequest`, `respondFriendRequest` — write friendships + FCM push.
- `startRoom`, `closeRoom`, `kickPlayer` — host-only room mutations.
- `generateCards({ category, subtype, vibe, count })` — AI provider call with server secret + daily quota.
- `revenueCatWebhook` — receives RevenueCat webhooks, grants subscription stars idempotently.
- `dailyReward` — scheduled function grants +5⭐ to eligible users daily.

---

## 13. Website (Next.js) — Marketing + Legal

The `website/` folder contains the Next.js + Tailwind marketing site:

- Logo everywhere (favicon, OG, header, hero).
- Hero: "Your iPhone is the party." CTA → App Store link.
- Feature grid (11 games with screenshots), Tools strip, Testimonials, FAQ.
- **Invite landing page** at `/invite?code=...` — deep-links into the iOS app or App Store (code persisted in localStorage).
- **Privacy Policy** and **Terms of Service** pages aligned with Apple review.
- Dark theme, modern, Apple-like.

---

## 14. Visual Design

See `DESIGN_SYSTEM_PROMPT.md` for the full spec. Summary:

- **Background:** `AppBackgroundView` — deep near-black + animated mesh gradient (blue/indigo/purple/pink) + blurred blob highlights.
- **Cards:** `.ultraThinMaterial` at 72% opacity, 18pt corners, 1pt hairline border `white.opacity(0.05)`.
- **Game cards:** per-game accent gradient, 18pt corners, 1:1 aspect ratio.
- **Typography:** `viralTitleStyle` — bold condensed display for titles; SF Pro for body. Varied weights for hierarchy.
- **Symbols:** SF Symbols throughout; filled variants; gradient foregrounds for hero icons.
- **Special assets:**
  - App icon / splash: `h03kekxe8ymunf0mls4b3.png`.
  - Coin Heads: `5bi465cwzmc67jtcmnxco.png` / Coin Tails: `sq46dl6bh1k6olsges2hi.png`.
  - Bottle: vertical beer-bottle transparent PNG (cap pointing up).

---

## 15. Accessibility & Polish

- Dynamic Type on all body text.
- VoiceOver labels on every interactive control.
- Haptic feedback for taps, correct/wrong, win, countdown.
- Sound globally mutable from the profile (Sound toggle).
- Portrait only.
- Global tap/pan gesture dismisses keyboard (`AppDelegate.installGlobalKeyboardDismissGestures`).
- iOS 26 `glassEffect` with `.ultraThinMaterial` fallback.

---

## 16. Analytics

Firebase Analytics events: `onboarding_completed`, `auth_success(provider)`, `game_started(game, mode)`, `game_finished(game, mode, duration, players)`, `stars_spent`, `stars_purchased(pack)`, `subscription_started(tier)`, `invite_sent`, `invite_redeemed`, `room_joined`, `card_generated_ai`.

---

## 17. Non-Functional Requirements

- Offline-first for single-device flows; only multiplayer requires Firestore.
- All network errors → structured error → user-friendly toast; never show raw errors.
- Retry with exponential backoff on transient Firestore errors.
- No hardcoded secrets. `GoogleService-Info.plist` in target. RevenueCat key via `Config`. AI keys server-side only.
- App Store review readiness: `PrivacyInfo.xcprivacy`, entitlements, Sign in with Apple wherever other third-party sign-ins are offered, Delete Account flow, working Restore Purchases, age-appropriate content filter for AI-generated cards.

---

## 18. Deliverables

1. Fresh iOS Xcode project **8PartyPlay** (Swift + SwiftUI, iOS 18+, dark mode).
2. Firebase project: Auth, Firestore, Functions, Storage, Messaging, App Check.
3. Cloud Functions (TypeScript) deployed.
4. RevenueCat offerings: monthly + yearly subscriptions + consumable star packs.
5. `website/` marketing site deployed with logo and legal pages.
6. All 11 games implemented with setup + session views and ViewModels.
7. Party Tools (Dice, Bottle, Hourglass, Coin, Team Splitter) with specified assets.
8. Card decks + AI generator working.
9. Friends, invites, rooms, rematch, reconnect — wired end-to-end.

Build it cleanly, Apple-quality, no "AI slop" aesthetic. Every screen should feel like a first-class native iOS app.
