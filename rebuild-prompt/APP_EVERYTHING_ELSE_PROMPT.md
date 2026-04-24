# 8PartyPlay — App Shell & Everything Else Build Prompt

This prompt describes everything in the app **except** the games and the multi-device realtime system (those live in their own prompts). It covers navigation, design system, tools, cards, AI generator, friends, wallet & stars, subscriptions, onboarding, profile, settings, and platform integrations. Pick whatever tech stack you think fits best.

## Brand & Identity

- App name: **8PartyPlay**.
- Logo: the "8" gold/blue party-play logo (provided). Use it for app icon, splash, App Store, and website consistently.
- Tone: playful, bold, viral. Big display titles with heavy weight. Dark UI with saturated accent colors.
- Tagline: "Party games for your crew."

## Navigation & App Shell

- Dark mode only.
- Root is a **TabView** with 4 tabs:
  1. **Games** (`gamecontroller.fill`) — home grid of all games, with free games on top and locked/premium games shown with a transparent lock badge on the card.
  2. **Tools** (`wrench.and.screwdriver.fill`) — Party tools + Cards decks + AI generator entry.
  3. **Friends** (`person.2.fill`) — offline friend names, online friends, requests, public rooms, Quick Join by code. Badge shows pending request count.
  4. **Factory** (`wand.and.stars`) — AI idea generator for new party games.
- Each tab has its own `NavigationStack` and resets when the user taps the tab again while already selected.
- Top-right of every main screen: a **profile avatar button** that opens the Profile sheet.
- A persistent **active session overlay** (fullScreenCover) takes over the UI whenever a game is in progress, regardless of which tab was active.

## Design System

Build a reusable design system:

- `AppBackgroundView` — animated dark gradient with subtle particle / noise layer used on every screen.
- `SurfaceCard` — rounded 18pt corner card with ultraThinMaterial + soft white stroke border.
- `ViralTitleStyle` — display font modifier with heavy weight and tight tracking for headers / game names.
- `SectionHeaderView` — title + subtitle section header.
- `SecondaryActionButtonStyle` / `CardPressStyle` — button styles with press spring + haptic.
- `StatusPillView` — small capsule with icon + label for mode tags, room status, etc.
- `ProfileToolbarButton` — circular avatar in toolbars (supports custom image or SF Symbol).
- `ToastOverlay` — global toast system attached to the root (success/info/warning/error).
- `FirstTimeHintOverlay` — contextual tutorial overlay shown the first time a user opens a feature.
- iOS 26 Liquid Glass: use `glassEffect` / `GlassEffectContainer` with availability guards. Fall back to material + stroke on iOS 18–25.

Accent palette per game: pink, cyan, teal, orange, red, yellow, purple, blue. Used for gradient card backgrounds and per-game tints.

Accessibility: Dynamic Type everywhere, VoiceOver labels on interactive elements, reduce-motion respected, 44pt minimum touch targets.

## Home Tab (Games)

- Header: "8PartyPlay" title on left, a **Join** pill button (opens the room-code sheet), and the profile avatar on the right.
- Segmented control under header: **Games** / **Ideas** (two library tabs).
- Below: a horizontal **mode filter chip row** — All / 1 Phone / Multi Phone / Team Mode. Taps filter the grid.
- Grid: 2-column `LazyVGrid` of game cards. Each card:
  - Accent gradient background using the game's accent color.
  - Game name in big display font.
  - Symbol in a rounded square.
  - Small mode-icon chips showing which modes it supports (multi-phone chip uses a custom icon, not SF Symbol).
  - Player-count footer ("3–12 players").
  - If locked, a transparent lock badge (lock.fill inside a dark glass circle) pinned to top-right.
- Sort rule: unlocked games first, locked games last. Preserve definition order otherwise.
- Tap unlocked card → navigate to Game Detail → Setup. Tap locked card → Game Detail still previews, with a primary CTA to unlock.
- The **Ideas** sub-tab shows `OtherFunView` — a list of party-game ideas (not built into the app) for inspiration.

### Game Detail
- Hero image (from `heroImageURL` if provided, else a gradient + symbol).
- Title, short description, supported modes, min/max players, premium/free status.
- **How to Play** button opens a localized long-form guide.
- Mode picker (segmented). For Imposter, picks go through an extra Game Style screen (Discussion vs Clue).
- "Start Game" button → the game's setup view (player count, names, difficulty, per-game options).
- If locked, show a Paywall CTA instead of Start.

## Tools Tab

Two stacked sections:

### Party Tools (row of five)
1. **Dice** — roll 1–4 dice, results animate, tap to re-roll.
2. **Bottle** — spin-the-bottle helper using the same beer-bottle image as the Truth & Dare game. Player inputs names, spins, and the bottle lands on one. Separate from the full Truth & Dare game.
3. **Hourglass** — configurable countdown timer with haptics at end.
4. **Coin Flip** — flipping animation between **Heads** and **Tail** faces (use the provided head and tail asset images). Both outcomes must be possible.
5. **Team Splitter** — enter names and split into 2 teams with a shuffle animation.

Each tool opens as a full-screen sheet with its own playful visual.

### Cards (Party Decks)
- 5 categories with accent colors: **Act** (purple), **Talk** (blue), **Challenges** (orange), **Penalty** (red), **Couple** (pink).
- Each category has multiple subtypes (Act: pantomime, dare, funny action; Talk: starters, personal, discussion, truth, explain/guess, icebreaker; Challenges: speech, behavior, time limit; Penalty: funny, embarrassing, group choice; Couple: questions, dynamics, playful).
- Category grid → deck view with swipeable card stack, skip / save / next. Bookmark icon in toolbar opens saved cards sheet.
- Some packs are free, some require subscription. Locked packs are visible but need unlock.
- **AI Card Generator** entry: a second path from Tools that lets the user generate a custom card deck by prompt (theme + tone + count). Uses an LLM to produce cards and streams them into a new deck the user can save.

## Factory Tab (AI Party-Game Generator)

- Screen lets the user pick a **Vibe** (Couple, Funny, Memory, Action, Cards, Trivia, Roleplay, Challenge), optional player count, optional extra notes.
- Hitting Generate calls an LLM and streams back one `GeneratedPartyIdea` at a time:
  - `title`, one-paragraph description, 3–6 numbered steps, a few short tags.
- Results are shown as swipeable cards the user can save to a local list, share, or regenerate.
- Locked behind subscription after a small free quota.

## Friends Tab

- Header with notifications pill (pending request count).
- **Quick Join** card — big "Enter Code" button opening the room-code sheet.
- **Offline Friends** — locally-stored names used in single-device games. Add / rename / delete. "Me" entry always present.
- **Online Friends** — requires login. Search by username / email / public ID. Send / accept / decline requests. Invite to game (opens a room picker).
- **Public Rooms** — live list of joinable public multiplayer rooms (see multi-device prompt for data source).
- Empty states include a **ShareLink** to invite friends to download the app.

## Profile Sheet

Opens from any tab's profile button. Sections:

- **Header:** avatar (image or SF Symbol), username, public numeric ID (copyable), provider badge (Username / Google / Apple / Guest).
- **Stats block:** games played, wins, stars balance. (No XP — do not surface XP anywhere.)
- **Wallet entry** → opens the Wallet screen.
- **Settings:**
  - Language (English).
  - Sound toggle, Haptics toggle, Reduce motion.
  - Notifications toggle.
  - Account: sign in / sign out / delete account.
  - Restore purchases.
  - Manage subscription (links to Apple subscription management).
  - Legal: Privacy Policy, Terms of Service, Support email, Rate the App, Share the App.
- **Version footer.**

## Wallet & Stars Economy

- Currency: **Stars** (★). No XP.
- Balance shown in a hero card with current total and recent delta.
- **Earn sources:**
  - Daily reward (once per day, claim button).
  - Subscription bonus (monthly stipend while subscribed).
  - Invite reward (+30 ★ when an invited friend joins).
  - Sign-up bonus (one-time first-run gift).
  - Admin adjustments (for support).
- **Spend sources:** unlock premium games/decks one-off instead of subscribing (configurable `unlockCostStars` per item).
- **Purchase:** in-app star packs bought via StoreKit (small / medium / large / mega tiers).
- **History list** with transaction type icon, title, delta, timestamp.
- **Invite friends card** — opens a share sheet with a referral link.
- **Restore purchases** row at the bottom.

## Subscriptions / Paywall

- Single subscription product: **8PartyPlay Pro** (monthly + yearly, yearly with savings badge).
- Benefits: unlock all games, unlock all card decks, unlimited AI generations, monthly star stipend, ad-free, early access to new games.
- Paywall view: hero, benefit list with icons, plan toggle, price with "7-day trial" if offered, big CTA, small legal text, Restore button, Terms + Privacy links.
- Triggered from: locked game cards, locked decks, AI generator quota exceeded, Profile → "Go Pro", onboarding optional upsell.

## Authentication

- Supported providers: **Username** (email + password), **Sign in with Apple**, **Google**, and **Guest** (no account).
- Guest mode lets users play single-device games and join rooms with a code, but not friend system or cross-device history.
- Link-account flow: a guest can upgrade to a real account later without losing local state.
- Delete account flow must be reachable from Settings and must actually delete remote data.

## Onboarding

- First-run flow (3–4 slides): welcome → how it works (1 phone / multi phone / team) → choose a display name and avatar → optional sign in → drop into home.
- Tutorial overlays (`FirstTimeHintOverlay`) the first time the user opens: the Games grid, a multi-device lobby, the Factory generator, and the Wallet.

## Notifications

- Ask permission after the user completes onboarding or the first game.
- Push notifications for: incoming friend requests, room invites, a friend starting a public room, subscription renewal reminders.
- In-app toasts for every success/error event (use the global `ToastOverlay`).

## Sound & Haptics

- `SoundManager` with small library: tab switch, navigation forward/back, spin, win fanfare, wrong buzz, tick, countdown end, card flip.
- Haptic feedback on every primary button and game event. Respect the user's Haptics toggle in Settings.

## Session Resilience (app-level)

- If a game is in progress and the app is killed or backgrounded for a long time, on relaunch restore the session (for single-device games from local state, for multi-device via the realtime system's snapshot flow).
- Maintain a light telemetry log of multiplayer events for debugging connection issues (opt-in).

## Platform Integrations

- **SF Symbols** for all icons except: the coin Heads/Tail faces, the beer-bottle image (Truth & Dare + Bottle tool), and the app logo — those use the provided raster assets.
- **ShareLink** wherever a user can invite friends or share a result.
- **StoreKit 2** for subscriptions and star-pack purchases (use your favorite wrapper). Wire Restore Purchases.
- **Deep links:** `8partyplay://room/<code>` opens the Join sheet pre-filled.
- **Universal links** to the marketing site / support pages.
- **iOS 26 Liquid Glass** where it adds polish (segmented tabs, pills, hero buttons) with iOS 18 fallbacks.
- **Widgets / Live Activities (optional stretch):** show an active room code on the Lock Screen while a multi-device lobby is open.

## Data & Persistence

- Local storage for: offline friend names, saved cards, saved AI ideas, user preferences (sound/haptics/language/reduce motion), stars balance mirror, last seen room codes, session tokens.
- Remote storage for: user accounts, friends/requests, rooms, room players, realtime game state snapshots, star transaction log, subscription entitlement.
- Everything must be functional while offline for single-device games and tools.

## Marketing & Legal Surfaces

- Marketing site at `https://www.8partyplay.com` with hero, game showcases, mode explainer, subscription pitch, download links, Privacy, Terms.
- In-app links to Privacy Policy and Terms of Service that open in a web sheet.
- App Store listing: icon, screenshots for each major flow (home grid, a multi-device lobby, Truth & Dare spin, Memory Grid, Cards deck, AI Factory, Paywall, Wallet).

## What NOT To Include

- **Do not implement XP, levels, leveling curves, level-up animations, or per-game level progress.** The app tracks matches played, wins, and stars — nothing else.
- No ads.
- No chat moderation beyond basic sanitization + rate limiting.
- No web build of the app itself (web = marketing site only).

Everything above plus the two sibling prompts (games + multi-device) fully specifies the 8PartyPlay app. Build it with whatever stack you think fits best.
