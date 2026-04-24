# 8PartyPlay — Rebuild Prompt Index

Complete specification for rebuilding 8PartyPlay from scratch as a cross-platform product.

**Stack:** iOS (Swift + SwiftUI) · Android (Kotlin + Jetpack Compose) · Web (Next.js + Tailwind) — all dark-mode-only, all on a single **Firebase** backend, with **Stripe** payments on Android + Web and **RevenueCat / StoreKit** on iOS.

---

## Reading / Build Order

Read files in numeric order. Each step builds on the previous one.

| # | File | What it covers |
|---|---|---|
| 01 | `01_PROMPT.md` | Full product overview, platforms, game list, architecture, deliverables. **Read first, always.** |
| 02 | `02_DESIGN_SYSTEM_PROMPT.md` | Colors, typography, components, animations, materials (tokens for SwiftUI + Compose + Tailwind) |
| 02A | `02A_RESPONSIVE_AND_FONTS_PROMPT.md` | Cross-platform fonts (SF Pro / Inter / JetBrains Mono), type scale, breakpoints (xs–2xl), spacing tokens, motion tokens |
| 02B | `02B_SCREEN_WIREFRAMES_PROMPT.md` | Per-screen textual wireframes — every element, anchor, size, and behavior for all 23 screens |
| 02C | `02C_STATE_MATRIX_PROMPT.md` | Loading / empty / error / offline state for every screen, skeleton recipes, error copy library |
| 03 | `03_FIREBASE_SETUP_PROMPT.md` | Firebase config, Firestore rules, Cloud Functions, Auth, Storage |
| 04 | `04_ONBOARDING_AUTH_PROMPT.md` | Splash, onboarding slides, auth screen (Apple / Google / Email / Guest) |
| 05 | `05_APP_SHELL_PROMPT.md` | Navigation shell, Friends tab, Profile sheet, Wallet, subscriptions, paywall |
| 06 | `06_MULTI_DEVICE_PROMPT.md` | Realtime rooms, lobbies, sync, reconnection, host migration |
| 07 | `07_GAMES_OVERVIEW_PROMPT.md` | Summary of all 11 games (quick reference) |
| 08 | `08_GAMES_DETAILED_PROMPT.md` | Every game — every screen, button, timer, phase, scoring rule |
| 09 | `09_TOOLS_CARDS_DETAILED_PROMPT.md` | Dice, Bottle, Hourglass, Coin, Team Splitter + card deck library |
| 10 | `10_FACTORY_TAB_PROMPT.md` | AI game idea generator + AI card pack generator |
| 11 | `11_NOTIFICATIONS_DEEPLINKS_PROMPT.md` | FCM push, local notifications, deep links, universal links, Android App Links |
| 12 | `12_ASSETS_AND_SOUNDS_PROMPT.md` | Images, app icon, launch screen, SFX, music, haptics inventory |
| 13 | `13_ANALYTICS_AND_REMOTE_CONFIG_PROMPT.md` | Firebase Analytics events, Crashlytics, Remote Config keys, App Check |
| 14 | `14_LOCALIZATION_ACCESSIBILITY_PROMPT.md` | Strings catalog, Dynamic Type / sp / rem, VoiceOver / TalkBack / ARIA |
| 15 | `15_TESTING_AND_QA_PROMPT.md` | Unit + UI tests, manual QA, performance budgets, CI gates |
| 16 | `16_APP_STORE_SUBMISSION_PROMPT.md` | App Store + Google Play + Web deployment checklist |
| 17 | `17_ANDROID_APP_PROMPT.md` | Native Android client (Kotlin + Jetpack Compose) full spec |
| 18 | `18_WEB_APP_PROMPT.md` | Next.js marketing site + full web app (PWA) full spec |
| 19 | `19_STRIPE_PAYMENTS_PROMPT.md` | Stripe Checkout, Billing Portal, webhooks, Cloud Functions |
| 20 | `20_CROSS_PLATFORM_SYNC_PROMPT.md` | How iOS + Android + Web stay in sync through Firebase |

---

## Critical Rules (apply everywhere)

- **Cross-platform parity.** iOS, Android, and Web all ship the same features, the same games, the same rooms, the same economy. One Firebase project, one Firestore schema, shared Cloud Functions.
- **NO XP.** Do not implement XP, levels, level-up animations, or per-game level progress. Only track: `matchesPlayed`, `wins`, `stars`.
- **Dark mode only** on every client.
- **Firebase only.** No Supabase. Backend is Firebase (Auth + Firestore + RTDB + Functions + Storage + FCM + Remote Config + App Check).
- **Payments:** **RevenueCat / StoreKit on iOS** and **Stripe on Android + Web**. Both converge on the same Firestore entitlements via webhooks.
- **iOS 18+** minimum, **Android API 29+** minimum, modern evergreen browsers for Web.
- **MVVM** — `@Observable` on iOS, `ViewModel + StateFlow` on Android, Zustand / hooks on Web.
- **Strict concurrency** on iOS — Codable structs and data types must be `nonisolated`.
- **Don't choose the tech stack** beyond the decisions locked here (Firebase, Stripe, RevenueCat, SwiftUI, Compose, Next.js) — the builder picks the rest.

---

## Asset References

| Asset name | File | Usage |
|---|---|---|
| App logo | `h03kekxe8ymunf0mls4b3.png` | App icon, splash, favicon (all platforms) |
| Coin Heads | `5bi465cwzmc67jtcmnxco.png` | Coin Flip tool — heads face |
| Coin Tails | `sq46dl6bh1k6olsges2hi.png` | Coin Flip tool — tails face |
| Bottle | Transparent PNG (vertical beer bottle, cap up) | Truth & Dare + Bottle Spinner |

Full asset + audio + haptics inventory: see `12_ASSETS_AND_SOUNDS_PROMPT.md`.

---

## Feature Completeness Checklist

### Clients
- [ ] iOS app (Swift + SwiftUI)
- [ ] Android app (Kotlin + Jetpack Compose)
- [ ] Web app (Next.js, installable PWA)

### Games (11 total — on every client)
- [ ] Reverse Singing (Free, 1 Phone, 2)
- [ ] Guess the Seconds (Free, 1 Phone, 2–30)
- [ ] Imposter (Free, 1 Phone, 4–30) — Discussion + Clue modes
- [ ] Memory Grid (Free, 1/Multi/Team, 1–30)
- [ ] Truth & Dare (Free, 1 Phone, 3–12)
- [ ] Ten Tangle (Premium, 1 Phone, 3–11)
- [ ] Memory Path (Premium, 1/Multi/Team, 2–30)
- [ ] Pass & Guess (Premium, 1 Phone, 2–30)
- [ ] Tap in Order (Premium, 1/Multi, 1–30)
- [ ] Color Trap (Premium, 1/Multi, 1–30)
- [ ] Draw & Rush (Premium, 1/Multi, 2–12)

### Party Tools (5 total)
- [ ] Dice Roller · Bottle Spinner · Hourglass Timer · Coin Flip · Team Splitter

### Card Decks
- [ ] Act · Talk · Challenges · Penalty · Couple, swipeable stack, saved / shared / locked

### Factory Tab
- [ ] Game Idea Generator, Card Pack Generator, quota enforced server-side

### Friends & Social
- [ ] Offline friends, Online friends, Room invites, Public rooms browser

### Multiplayer (cross-client)
- [ ] iOS host ↔ Android joiner ↔ Web joiner all work in the same room
- [ ] Create / join (code, invite, public), Lobby, Sync, Reconnect, Host migration, Rematch

### Economy & Payments
- [ ] Star balance, Daily reward, Star packs, Subscription (monthly + yearly)
- [ ] iOS: RevenueCat + StoreKit
- [ ] Android: Stripe Checkout via Custom Tab (or PaymentSheet)
- [ ] Web: Stripe Checkout + Customer Portal
- [ ] Shared Firestore entitlements (`subscriptionTier`, `subscriptionSource`, `subscriptionExpiresAt`)

### Auth & Profile
- [ ] Apple, Google, Email, Guest, Avatar upload, Username, Delete account, Restore purchases / Manage billing

### Notifications & Links
- [ ] FCM tokens (iOS / Android / Web), Push events, Local notifications
- [ ] `partyplay://` scheme, `https://8partyplay.app/...` universal + App Links

### App Shell
- [ ] 4-tab nav (iOS + Android + mobile Web), Sidebar on desktop Web
- [ ] Floating Profile, connection banner, global toast, paywall, legal pages

### Non-Functional
- [ ] Assets + sounds + haptics (file 12)
- [ ] Analytics + Remote Config + App Check (file 13)
- [ ] Localization + Accessibility (file 14)
- [ ] Unit + UI + E2E tests (file 15)
- [ ] App Store + Google Play + Vercel submissions ready (file 16)
