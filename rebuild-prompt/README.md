# 8PartyPlay — Rebuild Prompt Index

Complete specification for rebuilding 8PartyPlay from scratch. Read all files together.

**Stack:** Swift + SwiftUI · iOS 18+ · Dark mode only · Firebase backend · RevenueCat monetization

---

## Reading Order

Start with `PROMPT.md` for the big picture, then read each domain file before building that part.

| File | What it covers | Read when |
|---|---|---|
| `PROMPT.md` | Full app overview, game list, Firestore schema, architecture, deliverables | First — always |
| `DESIGN_SYSTEM_PROMPT.md` | Colors, typography, components, animations, sounds, haptics | Before writing any UI |
| `FIREBASE_SETUP_PROMPT.md` | Firebase config, Firestore rules, Cloud Functions TypeScript source, RevenueCat | Before any backend work |
| `ONBOARDING_AUTH_PROMPT.md` | Splash, onboarding slides, auth screen, email/password, Google, Apple, Guest | Before auth screens |
| `GAMES_DETAILED_PROMPT.md` | Every game — every screen, button, timer, phase, animation, scoring rule | Before building any game |
| `GAMES_PROMPT.md` | Games summary overview (shorter version) | Quick reference |
| `MULTI_DEVICE_PROMPT.md` | Realtime rooms, lobbies, sync, reconnection, host migration | Before multiplayer features |
| `TOOLS_CARDS_DETAILED_PROMPT.md` | Dice, Bottle, Hourglass, Coin, Team Splitter + card deck library + all card content | Before Tools tab |
| `FACTORY_TAB_PROMPT.md` | AI game idea generator + AI card pack generator | Before Factory tab |
| `APP_EVERYTHING_ELSE_PROMPT.md` | Navigation shell, Friends tab, Profile sheet, Wallet, subscriptions, paywall | Before app shell |
| `NOTIFICATIONS_DEEPLINKS_PROMPT.md` | FCM push notifications, local notifications, deep links, universal links | Before notifications/links |

---

## Critical Rules (apply everywhere)

- **NO XP.** Do not implement XP, levels, level-up animations, or per-game level progress. Only track: `matchesPlayed`, `wins`, `stars`.
- **Dark mode only.** `preferredColorScheme(.dark)` at the root. No light variant.
- **Firebase only.** No Supabase. Backend is Firebase (Auth + Firestore + Functions + Storage + FCM).
- **RevenueCat** for all in-app purchases (subscriptions + star packs).
- **iOS 18+** minimum. Use `@available(iOS 26.0, *)` guards for Liquid Glass.
- **MVVM with `@Observable`** — not `ObservableObject`.
- **Strict concurrency** — Codable structs and data types must be `nonisolated`.

---

## Asset References

| Asset name | File | Usage |
|---|---|---|
| App logo | `h03kekxe8ymunf0mls4b3.png` | App icon, splash screen, About |
| Coin Heads | `5bi465cwzmc67jtcmnxco.png` | Coin Flip tool — heads face |
| Coin Tails | `sq46dl6bh1k6olsges2hi.png` | Coin Flip tool — tails face |
| Bottle | Transparent PNG (vertical beer bottle, cap up) | Truth & Dare game + Bottle Spinner tool |

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
- [ ] Act (pantomime, dare, funny action)
- [ ] Talk (starters, personal, discussion, truth, explain/guess, icebreaker)
- [ ] Challenges (speech, behavior, time limit)
- [ ] Penalty (funny, embarrassing, group choice)
- [ ] Couple (questions, dynamics, playful)
- [ ] Swipeable card stack UI
- [ ] Save / share / skip
- [ ] Locked deck paywall

### Factory Tab
- [ ] Game Idea Generator (vibe + player count + notes → AI idea)
- [ ] Card Pack Generator (category + subtype + vibe + audience → AI cards)
- [ ] Daily quota system (3 free/day, unlimited for Pro)
- [ ] Save / share generated content

### Friends & Social
- [ ] Offline friends list (CRUD, "Me" pinned)
- [ ] Online friends (search, request, accept/decline)
- [ ] Room invites via push notification
- [ ] Public rooms browser

### Multiplayer
- [ ] Create room (game, mode, access type)
- [ ] Join by code / invite / public rooms
- [ ] Lobby (player list, ready state, host controls)
- [ ] Real-time game state sync
- [ ] Reconnection + session resilience
- [ ] Host migration
- [ ] Rematch flow

### Economy
- [ ] Star balance display
- [ ] Daily reward claim
- [ ] Star pack purchases (StoreKit via RevenueCat)
- [ ] Subscription (monthly + yearly via RevenueCat)
- [ ] Transaction history
- [ ] Invite reward (+30⭐)

### Auth & Profile
- [ ] Sign in with Apple
- [ ] Sign in with Google
- [ ] Email/password auth
- [ ] Guest mode
- [ ] Profile photo (Firebase Storage)
- [ ] Change username
- [ ] Delete account (App Store required)
- [ ] Restore purchases

### Notifications & Links
- [ ] FCM device token storage
- [ ] Push: friend request, invite, room starting, daily reward
- [ ] Local: hourglass end, turn reminder
- [ ] Deep link: `partyplay://invite?code=`, `partyplay://room/CODE`
- [ ] Universal links: `8partyplay.com/invite?code=`

### App Shell
- [ ] 4-tab navigation (Games, Tools, Friends, Factory)
- [ ] Profile floating button on every root tab
- [ ] Connection banner (reconnecting/disconnected)
- [ ] Global toast overlay
- [ ] iOS 26 Liquid Glass with iOS 18 fallback
- [ ] Paywall screen
- [ ] Privacy Policy + Terms of Service (in-app web view)
