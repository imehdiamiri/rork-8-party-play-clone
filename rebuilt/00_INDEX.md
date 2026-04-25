# 8PartyPlay — Rebuild Prompt Set (v2)

A fresh, numbered, end-to-end prompt set to recreate **8PartyPlay** from scratch.
Read prompts in numeric order. Each prompt is self-contained but assumes earlier ones are done.

> Source of truth = the latest build of the iOS app (`ios/App8PartyPlay/`). When in doubt, the existing Swift code is authoritative.

## Order

| # | File | Scope |
|---|---|---|
| 01 | `01_OVERVIEW.md` | What 8PartyPlay is, brand, target users, hard rules |
| 02 | `02_TECH_STACK.md` | Stack, packages, Xcode setup, env vars, Info.plist |
| 03 | `03_DESIGN_SYSTEM.md` | Dark-only mesh-gradient look, typography, components |
| 04 | `04_DATA_MODELS.md` | Every Swift model, enum, and shared type |
| 05 | `05_BACKEND_SUPABASE.md` | Schema, RLS, RPCs, realtime channels |
| 06 | `06_AUTH.md` | SupabaseAuthService + AuthView (Apple/Google/Username/Guest) |
| 07 | `07_APP_SHELL.md` | App entry, ContentView, splash, connection banner, MainTabView |
| 08 | `08_ONBOARDING.md` | 3-page onboarding (welcome / showcase / name entry) |
| 09 | `09_HOME_TAB.md` | Home — Games / Ideas tabs, mode filters, GameCardView grid |
| 10 | `10_GAME_DETAIL.md` | Shared GameDetailView (mode picker, players, start) |
| 11 | `11_GAME_REVERSE_SINGING.md` | Record + reverse + mimic |
| 12 | `12_GAME_GUESS_SECONDS.md` | Time-target stopping game |
| 13 | `13_GAME_IMPOSTER.md` | Discussion / Clue, Single / Multi / Team |
| 14 | `14_GAME_MEMORY_GRID.md` | Pair-matching, Single / Multi / Team |
| 15 | `15_GAME_MEMORY_PATH.md` | Hidden path on grid |
| 16 | `16_GAME_TEN_TANGLE.md` | Secret number 1–10 acting |
| 17 | `17_GAME_PASS_GUESS.md` | Pass-the-phone written-answer guessing |
| 18 | `18_GAME_TAP_IN_ORDER.md` | Race-to-tap numbered tiles |
| 19 | `19_GAME_COLOR_TRAP.md` | Tap-everything-but-the-forbidden-color |
| 20 | `20_GAME_TRUTH_DARE.md` | Spin-the-bottle Truth & Dare |
| 21 | `21_GAME_DRAW_RUSH.md` | Drawing + guessing |
| 22 | `22_TOOLS_TAB.md` | Cards root + Coin / Dice / Bottle / Hourglass / Team Splitter |
| 23 | `23_CARDS_DECKS.md` | Card decks (Act / Talk / Challenges / Penalty / Couple) + AI generator |
| 24 | `24_FACTORY_TAB.md` | AI game-idea generator |
| 25 | `25_FRIENDS_TAB.md` | Offline / online friends, search, requests, public rooms |
| 26 | `26_MULTIPLAYER.md` | CasualRoom create/join, lobby, realtime sync, host migration |
| 27 | `27_PROFILE_WALLET.md` | Profile sheet, stars wallet, daily reward, transactions |
| 28 | `28_ECONOMY_PAYWALL.md` | Subscriptions (RevenueCat), star packs, paywall, premium gating |
| 29 | `29_NOTIFICATIONS_DEEPLINKS.md` | UNNotificationCenter, invite scheme + universal links |
| 30 | `30_SOUND_HAPTICS.md` | SoundManager + FeedbackService |
| 31 | `31_LOCALIZATION_QA.md` | English-only locale, accessibility, build/QA, App Store |

## Hard Rules

- **iOS 18 minimum**, Swift 6 strict concurrency, SwiftUI + MVVM with `@Observable`.
- **Dark mode only** (`preferredColorScheme(.dark)` at root).
- **Mesh-gradient black background** everywhere (`AppBackgroundView`).
- **No XP, no levels, no progress curves.** Track only `matchesPlayed`, `wins`, `stars`.
- **No Persian/RTL.** English only. No Vazirmatn font; SF Pro Rounded for titles via `viralTitleStyle`.
- **Backend = Supabase only.** Auth + Postgres + Realtime + RPCs. No Firebase.
- **Payments = RevenueCat / StoreKit on iOS.**
- **No camera fallback UI.** No mock device modes.
- **Tab order:** Games · Tools · Friends · Factory.
- **App brand name: `8PartyPlay`** (display) — bundle id and Xcode project use `App8PartyPlay`.

## Game Library (11 games — exact list)

Free: Reverse Singing, Guess the Seconds, Imposter, Memory Grid, Truth & Dare.
Premium: Ten Tangle, Memory Path, Pass & Guess, Tap in Order, Color Trap, Draw & Rush.
