# 8PartyPlay — Rebuild Prompt Index

Complete specification for rebuilding 8PartyPlay from scratch. Read every file in the order below.

**Stack:** Swift + SwiftUI · iOS 18+ · Dark mode only · Firebase backend · RevenueCat monetization

---

## Reading / Build Order

Read files in numeric order. Each step builds on the previous one.

| # | File | What it covers |
|---|---|---|
| 01 | `01_PROMPT.md` | Full app overview, game list, architecture, deliverables. **Read first, always.** |
| 02 | `02_DESIGN_SYSTEM_PROMPT.md` | Colors, typography, components, animations, materials |
| 03 | `03_FIREBASE_SETUP_PROMPT.md` | Firebase config, Firestore rules, Cloud Functions, Auth, Storage, RevenueCat |
| 04 | `04_ONBOARDING_AUTH_PROMPT.md` | Splash, onboarding slides, auth screen (Apple / Google / Email / Guest) |
| 05 | `05_APP_SHELL_PROMPT.md` | Navigation shell, Friends tab, Profile sheet, Wallet, subscriptions, paywall |
| 06 | `06_MULTI_DEVICE_PROMPT.md` | Realtime rooms, lobbies, sync, reconnection, host migration |
| 07 | `07_GAMES_OVERVIEW_PROMPT.md` | Summary of all 11 games (quick reference) |
| 08 | `08_GAMES_DETAILED_PROMPT.md` | Every game — every screen, button, timer, phase, scoring rule |
| 09 | `09_TOOLS_CARDS_DETAILED_PROMPT.md` | Dice, Bottle, Hourglass, Coin, Team Splitter + card deck library |
| 10 | `10_FACTORY_TAB_PROMPT.md` | AI game idea generator + AI card pack generator |
| 11 | `11_NOTIFICATIONS_DEEPLINKS_PROMPT.md` | FCM push, local notifications, deep links, universal links |
| 12 | `12_ASSETS_AND_SOUNDS_PROMPT.md` | Images, app icon, launch screen, SFX, music, haptics inventory |
| 13 | `13_ANALYTICS_AND_REMOTE_CONFIG_PROMPT.md` | Firebase Analytics events, Crashlytics, Remote Config keys, App Check |
| 14 | `14_LOCALIZATION_ACCESSIBILITY_PROMPT.md` | Strings catalog, Dynamic Type, VoiceOver, Reduce Motion, contrast |
| 15 | `15_TESTING_AND_QA_PROMPT.md` | Unit + UI tests, manual QA, performance budgets, CI gates |
| 16 | `16_APP_STORE_SUBMISSION_PROMPT.md` | Bundle config, Info keys, metadata, IAPs, privacy label, review notes |

---

## Critical Rules (apply everywhere)

- **NO XP.** Do not implement XP, levels, level-up animations, or per-game level progress. Only track: `matchesPlayed`, `wins`, `stars`.
- **Dark mode only.** `preferredColorScheme(.dark)` at the root. No light variant.
- **Firebase only.** No Supabase. Backend is Firebase (Auth + Firestore + RTDB + Functions + Storage + FCM + Remote Config + App Check).
- **RevenueCat** for all in-app purchases (subscriptions + star packs).
- **iOS 18+** minimum. Use `@available(iOS 26.0, *)` guards for Liquid Glass.
- **MVVM with `@Observable`** — not `ObservableObject`.
- **Strict concurrency** — Codable structs and data types must be `nonisolated`.
- **Don't choose the tech stack** unless told — the AI builder picks frameworks itself, except for the decisions already locked above (Firebase, RevenueCat, SwiftUI, MVVM).

---

## Asset References

| Asset name | File | Usage |
|---|---|---|
| App logo | `h03kekxe8ymunf0mls4b3.png` | App icon, splash screen, About |
| Coin Heads | `5bi465cwzmc67jtcmnxco.png` | Coin Flip tool — heads face |
| Coin Tails | `sq46dl6bh1k6olsges2hi.png` | Coin Flip tool — tails face |
| Bottle | Transparent PNG (vertical beer bottle, cap up) | Truth & Dare game + Bottle Spinner tool |

Full asset + audio + haptics inventory: see `12_ASSETS_AND_SOUNDS_PROMPT.md`.

---

## Feature Completeness Checklist

### Games (11 total)
- [ ] Reverse Singing (Free, 1 Phone, 2 players)
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
- [ ] Dice Roller (1–4 dice, physics animation)
- [ ] Bottle Spinner (player names, real bottle image)
- [ ] Hourglass Timer (configurable, sound at zero)
- [ ] Coin Flip (heads + tails assets, both outcomes possible)
- [ ] Team Splitter (N teams, shuffle animation)

### Card Decks
- [ ] Act · Talk · Challenges · Penalty · Couple
- [ ] Swipeable stack UI, save / share / skip, locked deck paywall

### Factory Tab
- [ ] Game Idea Generator, Card Pack Generator
- [ ] Daily quota (3 free / unlimited Pro)

### Friends & Social
- [ ] Offline friends, Online friends, Room invites, Public rooms browser

### Multiplayer
- [ ] Create / join (code, invite, public), Lobby, Sync, Reconnect, Host migration, Rematch

### Economy
- [ ] Star balance, Daily reward, Star packs, Subscription, Transactions, Invite reward

### Auth & Profile
- [ ] Apple, Google, Email, Guest, Photo, Username, Delete account, Restore purchases

### Notifications & Links
- [ ] FCM tokens, Push events, Local notifications, `partyplay://` scheme, Universal links

### App Shell
- [ ] 4-tab nav, floating Profile, connection banner, global toast, paywall, legal web views

### Non-Functional
- [ ] Assets + sounds + haptics (file 12)
- [ ] Analytics + Remote Config + App Check (file 13)
- [ ] Localization + Accessibility (file 14)
- [ ] Unit + UI tests + manual QA (file 15)
- [ ] App Store submission ready (file 16)
