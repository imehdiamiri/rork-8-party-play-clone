# 8PartyPlay — Complete UI/UX Specification Prompt

Use this prompt to rebuild the **entire visual interface, every screen, every button, every micro-interaction** of 8PartyPlay exactly as it exists. Nothing is left out: colors, positions, typography, animations, states, and what every tap does.

---

## 0. GLOBAL DESIGN SYSTEM

**Theme:** Forced dark mode everywhere (`preferredColorScheme(.dark)`).

**Background (AppBackgroundView):** Layered dark background across all tabs — deep near-black base with subtle blue/purple radial glow in the top-left and magenta/pink glow in the bottom-right. Never flat black.

**Typography:**
- Titles: custom "viral" bold display style (rounded, extra heavy, slight tracking) via `.viralTitleStyle(size:weight:)` — used for screen titles, game names, section headers.
- Labels/small caps: `.system(size: 10, weight: .heavy)` with `.tracking(2)` uppercase (e.g. "PARTY KIT", "CARD LIBRARY", "TOOLS"). Always `.white.opacity(0.45)`.
- Body: SF Pro default, weights `.semibold/.bold` for emphasis, `.secondary` for hints.

**Colors (tints):** blue (primary/system), pink (couple/bottle), purple (team/roleplay), cyan (memory/hourglass), orange (dice/action/discussion), red (penalty/challenge), yellow (coin/funny), green (multi-device/online), mint (trivia), teal (memory vibe).

**Shapes:**
- Cards: `.rect(cornerRadius: 18)` with `.strokeBorder(.white.opacity(0.05–0.1))`
- Pills/chips: `.capsule` with `.white.opacity(0.06–0.1)` fill
- Icons in badges: 38–40pt rounded square with tint.opacity(0.14) fill

**Materials:** `.ultraThinMaterial.opacity(0.72)` for SurfaceCard. iOS 26+ uses `GlassEffectContainer` + `.glassEffect(.regular.tint(...).interactive())` for library tabs and key controls.

**Button press:** `CardPressStyle()` — scale 0.97 + subtle opacity drop on press. All navigation plays `SoundManager.shared.playNavigation()`. Tab switches play `playTabSwitch()`. Sensory feedback via `.sensoryFeedback` on key events.

**Motion:** `.spring(duration: 0.28, bounce: 0.16)` for tab changes; `.spring(duration: 0.22)` for filter chips. Cards slide up on appear with staggered delay `Double(index) * 0.06`.

**Toast overlay:** Global `toastOverlay(appModel:)` at the top, auto-dismissing, for feedback (star rewards, friend requests, errors).

---

## 1. ONBOARDING (first launch only)

Paged `TabView(.page)` with 3 pages and a persistent bottom control row.

### Page 1 — Welcome
- Centered glowing radial gradient (blue→indigo→clear, 200pt, blurred 30)
- `gamecontroller.fill` SF Symbol at 68pt with blue→cyan linear gradient, blue glow shadow, `.symbolEffect(.bounce)`
- Text stack: "Welcome to" (title2, secondary) / "8PartyPlay" (viral 38pt black, gradient) / subtitle "The ultimate party game collection"

### Page 2 — Games Showcase
- Grid/carousel of featured game icons with names
- Short blurb: "11+ mini-games. 1 phone or many. Solo, multi-device, or team mode."

### Page 3 — Name Entry
- Text field: "What should we call you?" with autofocus
- Validates non-empty before enabling "Start Playing"

### Bottom controls
- Left: "Skip" (plain text button, only on pages 1–2)
- Center: 3 page dots (active = white, inactive = white.opacity(0.3))
- Right: "Next" button (blue capsule) → on page 3 becomes "Start Playing" and calls `onComplete(playerName)`

---

## 2. MAIN TAB BAR

Native iOS 18 `TabView` with 4 tabs, SF Symbol icons, dark appearance:

1. **Games** — `gamecontroller.fill` → HomeRootView
2. **Tools** — `wrench.and.screwdriver.fill` → CardsRootView (tools + card library)
3. **Friends** — `person.2.fill` → SocialRootView. **Shows orange `.badge(count)` when friend requests pending.**
4. **Factory** — `wand.and.stars` → GeneratorView (AI idea generator)

Tapping the already-selected Games tab resets its navigation stack to root. Every tap plays `playTabSwitch()`.

**Profile sheet:** opened from every tab's top-right `ProfileToolbarButton` (circular avatar 38pt, either SF Symbol or user's uploaded photo).

**Full-screen cover:** `activeSession` presents `GameSessionView` over everything.

---

## 3. HOME TAB (Games)

### Header row
- Left: "8PartyPlay" (viral 20pt black, white)
- Right:
  - "Join" pill button: `#` icon + "Join" label, white text on white.opacity(0.1) capsule with hairline border → opens `QuickJoinSheet` full-screen cover (see §3.4)
  - Profile avatar button

### Library Tabs segmented control (centered, max 250pt wide)
Two pills in a glass container:
- **Games** (`gamecontroller.fill`) — playable library
- **Ideas** (`shippingbox.fill`) — "Other Fun" non-interactive idea list

Selected pill: blue tint + white text. Unselected: white.opacity(0.6). iOS 26 uses `GlassEffectContainer` for morphing transition.

### Mode filter row (horizontal scroll, when Games tab selected)
Chips: **All**, **1 Phone** (blue), **Multi Phone** (green), **Team Mode** (purple).
- Selected chip: clear bg, tint text, tint.opacity(0.4) stroke
- Unselected: white.opacity(0.07) bg, secondary text, hairline border
- Spring animation on switch

### Games grid (2 columns, LazyVGrid, spacing 12)
Each `GameCardView` is a square card:
- Linear gradient background based on `game.accentName` (pink/cyan/teal/orange/red/yellow/purple/blue) from topLeading→bottomTrailing
- Game title centered at top (viral 20pt black white, 2 lines, minScale 0.7)
- Center: SF Symbol 32pt in a 56×56 white.opacity(0.12) rounded-rect badge
- Bottom: mode icon row (small 20pt circles) — single phone, **custom MultiPhoneIcon** (two overlapping iPhones), team icon
- Below icons: "X–Y players" text (10pt bold white.opacity(0.7))
- Locked games: **dark semi-transparent padlock badge (`lock.fill`) in top-right corner** on a 28pt black.opacity(0.35) circle with white hairline. Unlocked games show no lock.
- Filtered/sorted: free games ALWAYS listed first, locked games at the end
- Slide-up staggered entrance
- Tap → `path.append(.game(game.id))` → GameDetailView

### Empty state
If filter yields nothing: `ContentUnavailableView("No Games", systemImage: "gamecontroller")`.

### 3.4 QuickJoinSheet (full-screen cover from "Join")
- Navigation title "Join Room" (inline), "Cancel" top-left
- Body: `CasualJoinRoomView` — input 6-char code → validate → join → auto-dismiss when session starts

### Ideas tab → OtherFunListView
Static list of non-playable party game ideas (cards with title + description + SF Symbol). Educational/inspirational; no lobby.

---

## 4. GAME DETAIL (HomeRoute.game)

Opens for a selected GameType (not Imposter — that has its own flow).

### Hero section
- Full-width hero image (Color anchor + AsyncImage overlay + `.clipShape(.rect(cornerRadius: 22))` + `allowsHitTesting(false)`) from `game.heroImageURL` if present
- Fallback: large gradient with SF Symbol
- Overlay top-left: back chevron button on material circle
- Overlay bottom-left: game title (viral black 28pt white) + "X–Y players" pill

### Info cards
- **Short description** (2–3 lines, `.foregroundStyle(.primary)`)
- **How to play** collapsible section from `PartyGameTutorial` — numbered steps, each with SF Symbol leading icon
- **Supported modes pills:** 1 Phone / Multi Phone / Team Mode — only modes in `game.supportedModes` are shown, tinted by mode color

### Mode selector
Large tappable rows (full-width cards):
- 1 Phone — "Everyone plays on one phone"
- Multi Phone — "Everyone plays on their own phone"
- Team Mode — "Split into 2 teams" (only for Memory Grid, Memory Path)

Each row: tint-colored icon badge left, title + subtitle middle, chevron right. Tapping routes to the appropriate setup view.

### Locked overlay
If `!canPlayGame`: a blurred veil over the whole Start CTA with a **lock icon + "Unlock with Stars (X ★)" or "Unlock Premium"** button opening PaywallView.

### Primary CTA
Pinned bottom: "Start" button, blue capsule full-width, 56pt tall, plays sound + haptic on tap.

---

## 5. SETUP FLOWS (per game, shared components from UnifiedSetupComponents)

Every setup follows the same skeleton but exposes game-specific knobs.

### Shared components
- **Header:** back chevron + game name + mode pill
- **Player picker:** chip grid of offline friends + "Me" + `+Add` field → reorderable; minimum enforced per game. Counter shows `X / Max`.
- **Round stepper:** `−` / number / `+` capsule, range clamped per game.
- **Timer stepper:** seconds/minutes, used in games with timers.
- **Category/difficulty selector:** horizontal chip scroll, one selectable.
- **Mode-specific toggles:** listed below per game.
- **Start button:** blue full-width capsule, pinned at bottom, disabled until minimum players met.

### 5.1 Reverse Singing (Free, 1 Phone, 2–30 players, 75s)
- Player list
- Rounds per player (default 1)
- Recording time per turn (default 10s)
- Start

### 5.2 Guess the Seconds (Free, 1 Phone, 2–30 players)
- Players list
- Rounds per player stepper (default 3, total turns = players × rounds)
- Target time selector — visual dial 5–60s
- Start

### 5.3 Imposter (Free, 1 Phone, 4–30, two substyles)
Routes through **ImposterStyleSelectionView** first:
- Two big cards side-by-side: **Discussion Mode** (orange, bubble icon) vs **Clue Mode** (purple, magnifying glass)
- Each shows 3 bullet details
- Tap → `ImposterGameDetailView(style)` → `ImposterSingleDeviceSetupView`

Setup:
- Players list
- Rounds stepper (default 3)
- Discussion duration (for discussion mode only, default 60s)
- Category pack horizontal chips: Animals, Food & Drinks, Places, Jobs, Movies, Random
- Start

### 5.4 Memory Grid (Free, 1/Multi/Team, 1–30)
- Player list
- Grid size selector: Small 4×4, Medium 4×6, Large 6×6 (emoji pair count shown)
- Mode-specific:
  - Team Mode → routes through `TeamModeEntryView` → `TeamSetupView` (split players into Team A/B drag-chips)
  - Multi Device → creates a room via CasualRoom flow
- Start

### 5.5 Ten Tangle (Premium, 1 Phone, 3–11)
- Player list
- "How to play" inline
- Start

### 5.6 Memory Path (Premium, 1/Multi/Team, 2–30)
- Player list
- Difficulty chips: Easy, Medium, Hard (grid size + path length changes)
- Game mode chips: Time Race / First to Finish
- Start

### 5.7 Pass & Guess (Premium, 1 Phone, 2–30)
- Player list
- Rounds (default 1)
- Question mode toggle: **Predefined** (carousel of preset questions) vs **Custom** (text field)
- Answer time stepper (default 45s), Guess time (default 30s)
- Start

### 5.8 Tap in Order (Premium, 1/Multi, 1–30)
- Player list
- Rounds
- Grid size / number count
- Start

### 5.9 Color Trap (Premium, 1/Multi, 1–30)
- Player list
- Rounds
- Forbidden color preview
- Start

### 5.10 Draw & Rush (Premium, 1/Multi, 2–12, 100s)
- Player list
- Rounds
- Drawing time per round
- Category/difficulty
- Start

### 5.11 Truth & Dare / Spin Bottle (Free, 1 Phone, 3–12)
- Player list (arranged in circle preview)
- Rounds/turns
- Category chips
- Start

---

## 6. LIVE GAME SESSIONS

Shared session chrome (all via `GameSessionView`):
- **Top bar:** round indicator "Round X of Y", pause `pause.fill` button (→ confirm quit sheet), exit chevron
- **Timer pill:** top-center with `.sensoryFeedback` pulsing when <10s
- **Phase subviews:** intro → passToNextPlayer (big "Pass to {Name}" card with tap-to-continue) → liveRound → roundResult → finished
- **Result screens:** leaderboard (rank medals 🥇🥈🥉, score, stars/XP earned), "Play Again" + "Exit" buttons
- Haptic + sound at phase transitions.

### Per-game session UIs

**Reverse Singing:** mic permission prompt → big red record button → countdown → plays back reversed via AVAudioEngine → imitation record → compare playback → score self/friends vote.

**Guess the Seconds:** "Hide the phone" card → invisible counter running → tap STOP button (huge yellow) → reveal delta from target → next player passes.

**Imposter:**
- Role reveal: hold-to-reveal card per player ("Your word: PIZZA" or "You are the Imposter").
- Discussion mode: timer counts down, all discuss aloud.
- Clue mode: turn indicator shows current player, they say one clue, tap Next.
- Voting: grid of player buttons; tap suspect. Reveal screen: crown on Imposter, win/loss banner.

**Memory Grid:** 4×4/4×6/6×6 tile grid, tap to flip (3D rotation), matches stay up, mismatches flip back after 0.8s. Timer + move counter in corner. Multi-device shows mini spectator grids for other players. Team mode alternates turns.

**Memory Path:** hidden path revealed briefly, then grid goes blank. Tap tiles one-by-one; wrong tile = red flash + haptic + reset to start; right tile = green glow. Progress bar and attempts counter shown.

**Tap in Order:** grid of numbered tiles shuffled. Tap 1, 2, 3 … in order. Wrong = red shake. Time per player; leaderboard ranks by time.

**Color Trap:** one forbidden color shown at top. Colored squares flash; tap every one except forbidden. 3 strikes = out. Speed increases over time.

**Pass & Guess:** round 1 — each player answers secretly (pass phone, type, hide); round 2 — answers shown anonymously, everyone guesses who wrote what (tap player avatar per answer); reveal scoreboard.

**Ten Tangle:** secret number 1–10 shown to active player → they act out a scenario matching the intensity → guesser picks number on a 1–10 slider → score by proximity.

**Draw & Rush:** drawer sees prompt; uses canvas (finger draw, colors, thickness, eraser, clear) → others see drawing live; first to type correct guess wins. Multi-device broadcasts strokes.

**Truth & Dare / Spin Bottle:** a **realistic 3D bottle shape** (amber beer-bottle look with highlight + shadow) spins; physics-based deceleration → points at a player. They pick **Truth or Dare** → card drawn from deck → tap "Next".

**Guess-the-Seconds waiting-room icon style:** all spectator views show player avatars + live progress bars.

---

## 7. TOOLS TAB (CardsRootView)

### Header
- Left small-caps "PARTY KIT" + viral title "Tools"
- Right: bookmark button (filled when saved cards exist) → SavedCardsSheet; profile avatar

### Party Tools section (LazyVGrid, 3 columns)
Five tool cards, each tinted:
- **Dice** (orange, `die.face.5.fill`) — "Roll 1–4 dice"
- **Bottle** (pink, `waterbottle.fill`) — "Spin to pick"
- **Hourglass** (cyan, `hourglass`) — "Set a timer"
- **Coin Flip** (yellow, `circle.circle.fill`) — "Heads or tails"
- **Team Splitter** (green, `person.2.badge.gearshape.fill`) — "Split into teams"

Tap → presents tool in a sheet inside a `NavigationStack`.

### Tool interactions
- **Dice:** 1–4 selectable; big Roll button; 3D dice with realistic rolling animation, final faces shown with sum; Re-roll button.
- **Bottle:** circle of player avatars around a beer-style bottle; Spin button with random angular velocity, slow deceleration spring, haptic tick on near-stop; selected player highlighted.
- **Hourglass:** configurable minutes/seconds; start/pause/reset; ⏳ symbol flips and animates sand (particle style); alarm on finish.
- **Coin Flip:** two-sided coin with image 8 on heads, image 2 on tails (both user-provided asset images, no placeholder symbol). Tap flip → 3D rotation on X-axis, random end side. **Both heads and tails outcomes must occur (~50/50)**. Result shown as "HEAD" or "TAIL" caption.
- **Team Splitter:** player chip list → pick team count → Randomize → animated shuffle → two/three color-coded team cards.

### Card Library section
- Small-caps "CARD LIBRARY" + viral title "Ready to Use Cards" + total count pill
- **AI Generate row** (top) — gradient card, `wand.and.stars`, "Create any card with AI" → `AICardGeneratorView`
- **Category rows** (list, full-width, vertical stack):
  - **Act** (purple, theater masks) — "Perform it out loud"
  - **Talk** (blue, bubbles) — "Speak, answer, discuss"
  - **Challenges** (orange, bolt) — "Short rules with a twist"
  - **Penalty** (red, warning triangle) — "A playful consequence"
  - **Couple** (pink, heart) — "Just for two"

Each row: tint icon badge, title + subtitle, count pill, chevron. Tap → `CardsDeckView(category)`.

### CardsDeckView
- Subtype chips (horizontal scroll): subtypes per category (e.g. Pantomime/Dare/Funny Action for Act)
- Card stack (Tinder-style): swipe right = save/bookmark, swipe left = skip. Tap to flip if needed.
- Spicy cards are gated behind paywall — show a blurred lock if not unlocked, triggering `onUnlock`.
- Top-right: counter "N of M", heart button to save.

### AI Card Generator
- Category picker
- Subtype picker
- Style/spicy toggle
- Prompt text field (moderated via `AIContentModeration`)
- Generate button → streams 5–10 cards; each can be Saved or added to deck
- Premium-gated: non-premium sees "3 free per day" meter; beyond = paywall

### SavedCardsSheet
- List of all saved cards grouped by category; swipe-to-delete; share button per card.

---

## 8. FRIENDS TAB (SocialRootView)

### Header
- "Friends" viral title
- If requests > 0: orange "bell.badge + N" pill
- Profile avatar

### Quick Join card (top)
- Blue `number.square.fill` icon, "Join with Code" / "Enter a room code to join instantly", blue "Enter Code" pill → full-screen CasualJoinRoomView.

### Offline Friends section
- Section header "Offline Friends" / "Local names for Single Device games."
- Add row: text field "Add name" + blue "Add" button
- List: each row has avatar (first letter), name, optional "me" blue pill, "Edit" and trash buttons (hidden for Me)

### Online Friends section
- Section header "Online Friends" / "For Multi Device games and invites."
- Search field: "Search username, email, or ID" (email keyboard, lowercase) — debounced; shows Results list below
- If request list not empty: "Requests" subsection — each with Decline (plain) + Accept (blue) buttons
- If online friends empty: icon + "No Online Friends" + share link "Invite friends to play" (blue rect button with share sheet)
- If populated: list rows with avatar (green dot = online), name, blue "Invite" pill

### Public Rooms section
- Section header "Public Rooms" / "Open multiplayer rooms you can join."
- If guest: blue "Login" pill top-right → AuthView sheet
- Rooms list: each row shows green game icon, game name + mode pill, "N/M players • Host", chevron. Tap → WaitingRoomView.

### Search results
- Each result: avatar, username, "ID #X" or "No public ID", Add/Added/Sent/Pending/You pill (blue if actionable, grey if not).

---

## 9. FACTORY TAB (GeneratorView)

AI party-idea generator.

### Header
- Small-caps "AI FACTORY" + viral "Game Factory"
- Profile avatar

### Controls card
- **Vibe picker:** 2×4 grid of chips — Couple (pink heart), Funny (yellow smile), Memory (teal brain), Action (orange runner), Cards (blue club), Trivia (mint ?), Roleplay (purple masks), Challenge (red flame). Selected = tint bg.
- **Player count stepper:** 2–20
- **Context prompt** (optional): multiline text field
- **Generate** button: blue full-width capsule with `wand.and.stars`; disabled while generating; loading shows progress

### Results
- 3 idea cards per generation:
  - Title (viral 22pt)
  - Description (one-line hook)
  - Numbered steps list
  - Tag chips at bottom
  - Save/Share buttons per idea
- Error state: red banner + retry

---

## 10. WAITING ROOM / LOBBY (multi-device)

- Top: game hero, room code big (copyable + share), code QR
- Player grid: avatars with name + ready checkmark; host has crown icon
- Chat message bar (optional)
- Host: "Start Game" button (disabled until min players reached & all ready)
- Guest: "Ready" toggle
- "Leave" button

**Casual Create Room:** host picks mode, access (Private/Public), max players → creates → navigates to WaitingRoom.
**Casual Join Room:** input 6-digit code → fetches → joins.

---

## 11. PROFILE SHEET

Presented via `isShowingProfile` sheet from any tab.

- Avatar (tappable → PhotosPicker to upload)
- Username + public ID ("ID #12345"), copy button
- Buttons row: Edit profile, Sign out, Delete account (destructive red)
- Settings list:
  - Language (English only)
  - Sound / haptics toggles
  - Notifications
  - Manage subscription → opens App Store
  - Restore purchases
  - Privacy policy, Terms of service, Support email (external links via `AppConstants.URLs`)
- Version footer

### AuthView (sheet)
- Apple sign-in button (black, Apple logo)
- Google sign-in button (white, G logo)
- "Continue with Username" (email/password form)
- Guest link
- Legal footnote

---

## 12. WALLET / ECONOMY (accessed via Profile → "Wallet" or premium CTAs)

- Star balance hero: huge ⭐ number with glow
- Feedback card (if any recent reward/spend)
- Membership card: "Premium" pill if active, else "Upgrade" CTA → PaywallView
- Star economy card: earn rates (win, invite, daily)
- Star sources: buy packs, earn by playing, invite friends
- **Invite Friends card:** pink gift icon + "Invite Friends" + "Earn +30 ★ when a friend joins" → InviteView sheet (share link + code)
- History section: transaction list with icon + title + ±N stars
- Restore purchases row

### PurchaseDetailView (sheet)
- Pack details, price from StoreKit, "Buy" CTA, Terms link

### PaywallView
- Hero banner with premium perks (unlock all games, all categories, AI generator unlimited, no ads)
- Plan toggle: monthly / yearly (yearly "Save 40%" pill)
- Continue button (blue), "Restore Purchases" link, Terms/Privacy links

---

## 13. TUTORIAL / FIRST-TIME HINTS

`FirstTimeHintOverlay` shows once per feature:
- Dim veil
- Callout arrow pointing at target
- Bold title + body
- "Got it" pill dismiss

Used on: first session start, first card swipe, first AI generation, first tool use.

---

## 14. TOAST / FEEDBACK

- Top-center slide-down capsule
- Variants: success (green check), info (blue i), warning (orange), error (red x)
- Auto-dismiss 2.5s with spring; tap to dismiss early

---

## 15. SF SYMBOLS & ASSETS USED

Core symbols: `gamecontroller.fill`, `wrench.and.screwdriver.fill`, `person.2.fill`, `wand.and.stars`, `waterbottle.fill`, `die.face.5.fill`, `hourglass`, `circle.circle.fill`, `lock.fill`, `bolt.fill`, `heart.fill`, `theatermasks.fill`, `bubble.left.and.bubble.right.fill`, `exclamationmark.triangle.fill`, `number.square.fill`, `paintpalette.fill`, `pencil.and.scribble`, `eye.fill`, `square.grid.3x3.fill`, `map.fill`, `stopwatch.fill`, `backward.fill`, `arrow.triangle.2.circlepath`, `text.bubble.fill`, `bell.badge.fill`, `sparkles.rectangle.stack.fill`.

Custom assets:
- **Coin — Heads image** (user asset) and **Coin — Tails image** (user asset) — both sides must render, ~50/50 outcomes.
- **Spin bottle** — amber 3D beer-bottle shape with highlight/shadow & cap.
- **App logo** — single canonical 8PartyPlay mark used in app icon, splash, website, App Store, onboarding.
- **Game hero images** — 4–5 unique illustrations stored on R2 CDN (URLs in `GameType`).

---

## 16. ACCESSIBILITY

- Full Dynamic Type scaling on all text labels
- `accessibilityLabel` on every icon-only button (profile, join, bookmark, trash, lock)
- Sufficient contrast (min 4.5:1) on all text over gradients
- `sensoryFeedback` + VoiceOver announcements on phase transitions
- Respect `reduceMotion` — disable spinning bottle / flipping coin animations and snap to result

---

## 17. STATES MATRIX (do not forget)

Every screen covers:
- **Loading** — skeleton or ProgressView
- **Empty** — ContentUnavailableView with icon + helpful body + primary CTA
- **Error** — inline red banner + Retry button
- **Offline** — top banner "No connection" + retry
- **Locked** — lock icon overlay + unlock CTA (stars or paywall)
- **Success** — toast + haptic

---

## 18. AUDIO

`SoundManager.shared` plays: tab switch, navigation, button tap, success, error, coin flip, bottle spin tick, dice roll, timer tick, timer-end alarm, match start/end. All gated by user's sound toggle.

---

## 19. WHAT EACH TAP DOES — CHEAT SHEET

| Element | Action |
|---|---|
| Home header "Join" | Opens QuickJoinSheet (code entry) |
| Home profile avatar | Opens ProfileView sheet |
| Home library pill | Switches between Games/Ideas |
| Home mode chip | Filters game grid |
| Game card (unlocked) | Navigates to GameDetailView |
| Game card (locked) | Navigates to GameDetailView with paywall CTA |
| Game detail mode row | Navigates to that mode's setup view |
| Setup Start | Creates session / room and navigates to GameSessionView |
| Tool card | Presents tool sheet |
| Coin flip tap | Animates 3D flip; shows Head (image 8) or Tail (image 2) |
| Bottle tap | Spins; picks random player |
| Category row | Opens CardsDeckView |
| AI Generate row | Opens AICardGeneratorView |
| Save bookmark on card | Adds to saved; toast confirms |
| Friends tab add button | Appends offline friend |
| Friends search | Queries Supabase for users |
| Invite button | Sends friend invite / notification |
| Requests Accept/Decline | Updates relationship state |
| Factory Generate | Streams 3 AI ideas |
| Wallet Buy pack | Opens PurchaseDetailView → StoreKit |
| Paywall Continue | Triggers RevenueCat purchase |
| Profile Sign out | Logs out, returns to AuthView |

---

**Rule of thumb:** if a user sees a button, it MUST do exactly what is described here, with a haptic, a sound, a spring animation, and a clearly visible state change. Nothing is silent, nothing is static, and no state is ever a dead-end.
