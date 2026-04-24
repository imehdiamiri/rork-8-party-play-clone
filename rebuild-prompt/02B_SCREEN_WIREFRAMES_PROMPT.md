# 8PartyPlay — Per-Screen Wireframes (Textual)

This file gives a **precise textual wireframe** for every screen in the app. Each wireframe lists every visible element, its position (anchor + padding in pt/dp/px — same number on all platforms), size, and behavior. Use these alongside `02_DESIGN_SYSTEM_PROMPT.md` (tokens) and `02A_RESPONSIVE_AND_FONTS_PROMPT.md` (fonts/breakpoints).

Notation:
- `[topLeft 16, 16]` = anchored to the top-left of the safe area, 16pt from top, 16pt from leading.
- `[topTrailing 16, 16]` = anchored to the top-right.
- `H × W` = height × width in pt/dp/px (same number on every platform; Web converts to rem at runtime).
- "stack" = vertical stack (VStack / Column / flex-col), "row" = horizontal stack.
- "fill" = stretches to parent width with the given horizontal padding.

Page horizontal padding is **16pt mobile / 24pt md / 32pt lg+** unless overridden.

---

## 1. Splash Screen
- Background: `AppBackgroundView` full-bleed.
- Center stack (VStack, spacing 16):
  - App logo `app_logo` — 120 × 120, corner radius 28, shadow (radius 24, y 8, color black 40%).
  - Title "8PartyPlay" — `viralTitle`, white, scale 1.0, fade-in 0.4s.
  - Subtitle "Party games for every gathering" — `caption`, secondary.
- Bottom: `ProgressView()` 24 × 24 + caption "Loading…" — anchored bottom-center, padding-bottom 48.
- Auto-advance to Onboarding (first launch) or Auth/Home (returning) after 1.2s.

---

## 2. Onboarding (3 slides, paged)
- Background: `AppBackgroundView`.
- Top: skip button "Skip" — `[topTrailing 16, 16]`, secondary text, 17pt.
- Middle (TabView, paged):
  - Slide hero (illustration or SF Symbol gradient) — 220 × 220 centered.
  - Title — `gameTitle`, primary.
  - Body — `body`, secondary, max-width 320, multiline center.
- Page indicators: 3 dots, 8×8, 12pt below middle stack, active = white, inactive = white 25%.
- Bottom CTA: PrimaryButton fill, 56 high, label "Continue" → "Get Started" on last page. `[bottom 24]` with 16 horizontal padding.

---

## 3. Auth Screen
- Background: `AppBackgroundView`.
- Top: app logo 80×80 + "8PartyPlay" `gameTitle` — center, padding-top 64.
- Mid stack (spacing 12, padding-horizontal 16):
  - **Continue with Apple** — black button, Apple logo, 56 high, full-width.
  - **Continue with Google** — white button, Google "G", 56 high.
  - **Continue with Email** — outlined button (white 10% bg), envelope icon, 56 high.
  - Divider row "or" — hairline + label.
  - **Continue as Guest** — text-only secondary button, 17pt.
- Bottom: legal microcopy "By continuing you agree to our Terms and Privacy" — caption tertiary, 16pt below CTAs, links underlined.

States: loading (spinner replacing label), error (toast at bottom).

---

## 4. Email Sign-Up / Sign-In sheet
- Sheet detents `[.medium, .large]`.
- Header: title "Sign in" or "Create account" + segmented control to switch.
- Form (stack, spacing 12):
  - Email field — 56 high, rounded 14, white 8% bg.
  - Password field — same, with eye toggle on right.
  - (Sign-up only) Username field.
- "Forgot password?" — caption tinted, right-aligned.
- PrimaryButton "Continue" — fill, 56 high, bottom-anchored 16 padding.

---

## 5. Home Tab (Games)
- NavigationStack header:
  - Title "Games" — `viralTitle`, leading.
  - Right toolbar (row, spacing 12):
    - **Join pill** — capsule, 36 high, "Join with code" label + qrcode icon, glassEffect (iOS 26) or thinMaterial.
    - **ProfileToolbarButton** — 36×36 circle.
- Subtitle: "Pick a game and bring the chaos" — `caption`, secondary, 16 horizontal padding, 4 below title.
- Mode filter chips row (horizontal scroll, padding 16, spacing 8): "All", "1 Phone", "Multi", "Team", "Free", "Premium" — 32 high, rounded full, white 8% bg, selected = accent gradient.
- Game grid: LazyVGrid 2 columns (mobile) / 3 (md) / 4 (lg) / 5 (2xl), spacing 12, padding 16. Each cell = `GameCard`.
- Floating "What's New" banner (optional, dismissible) above grid: 64 high SurfaceCard with icon + text + chevron.

---

## 6. Game Card (component recap)
- Aspect 1:1, gradient bg, 20 corner.
- Top-left: 64×64 white-15% rounded square containing 36pt SF Symbol white.
- Bottom-left stack:
  - Game name — `gameTitle`, white.
  - Mode chips row (max 2) — capsules 20 high, white 18% bg + white text, 11pt semibold.
  - Player count — caption white 70%, person.fill icon + "2–30".
- Top-right overlay: lock badge (28×28 black 60% circle + 14pt lock.fill) only if locked.

---

## 7. Friends Tab
- Header: title "Friends" + add-friend button (plus.circle.fill, 28pt) `[topTrailing 16]`.
- Search field (full-width, 44 high, magnifyingglass icon, "Search friends" placeholder, padding 16).
- Segmented control: "Online", "Offline", "Requests" (badge if pending).
- Body = List with sections:
  - **Online** — rows: avatar 40×40, name + status pill ("In a room" / "Idle"), trailing "Invite" button.
  - **Offline** — rows: avatar 40 (grayscale), last-seen caption, trailing "..." menu.
  - **Requests** — rows: avatar + name + Accept (success) / Decline (destructive).
- Empty state: friends.fill icon 64pt + title "No friends yet" + "Find Friends" PrimaryButton.

---

## 8. Public Rooms Browser
- Header: title "Live Rooms" + refresh button.
- Filter chips: "All", "Free", "Premium", per-game.
- List of `RoomRow` cards (stack, spacing 12):
  - Row contents: game gradient stripe (4 wide, full height) + VStack(host name, game title, "3/8 players") + capacity bar + Join button.
- Empty state: "No public rooms — start one!" + Create button.

---

## 9. Profile Sheet (mobile) / Drawer (desktop)
Detents `[.medium, .large]` (mobile). Drawer 360 wide on desktop.
- Header row: avatar 72×72 + VStack(username 22pt heavy, handle caption secondary) + edit pencil button.
- Stat row (3 chips equal-width): "Wins · 24", "Matches · 102", "Stars · 1,420".
- Section "Account":
  - Row "Edit profile" (chevron).
  - Row "Subscription" — caption shows tier + Manage chevron.
  - Row "Wallet" — star icon + balance + chevron.
- Section "App":
  - Row "Sound" toggle.
  - Row "Haptics" toggle.
  - Row "Reduce Motion" toggle.
  - Row "Language" — chevron.
  - Row "Notifications" — chevron.
- Section "Legal":
  - Row "Terms", "Privacy", "Support".
- Footer: "Sign out" destructive text-button + "Delete account" tertiary destructive.

---

## 10. Wallet
- Top hero: SurfaceCard 96 high — star.fill icon 36pt + balance number `viralTitle` (monospaced digits) + "Stars".
- Daily reward strip: 7-day grid, today highlighted with accent ring; "Claim" PrimaryButton if eligible (otherwise countdown timer).
- Section "Buy Stars" — grid of 4 packs (`PackCard` 1:1 — bundle icon, count, price, "Most popular" ribbon if applicable).
- Section "History" — list of recent transactions with sign + delta + caption.

---

## 11. Subscriptions / Paywall
- Hero: gradient header 220 high — gradient text "Go Premium" `viralTitle` + 3 feature bullets.
- Tier cards (2): "Monthly" / "Yearly (Save 30%)" — selectable, accent border on selected, price + per-period caption + savings chip.
- Bullet feature list (sf checkmark.circle.fill green): "All 11 games", "All card decks", "Unlimited Factory generations", "No ads", "Priority multiplayer".
- PrimaryButton fill bottom: "Start free trial" / "Subscribe".
- Caption microcopy: cancellation policy.
- Trailing footer row: "Restore purchases" (text-button) on iOS, "Manage billing" on Android/Web.

---

## 12. Lobby (multiplayer room)
- Header: room code chip (top-center, large 22pt monospaced, copy icon) + close X `[topTrailing 16]`.
- Hero: game name + mode chip + host badge.
- Players grid (LazyVGrid 3 columns, spacing 12): each tile = avatar 56 + name + ready dot (green/red).
- Ready toggle PrimaryButton (host sees "Start game" instead, disabled until ≥ min players).
- Bottom row: "Invite" (share.sheet trigger) + "Public toggle" (host only).

---

## 13. In-Game Top HUD (shared across all games)
- Left: round counter pill "Round 2 / 5".
- Center: `CurrentTurnPill` (per `02 §5`).
- Right: timer pill (monospaced digits, color shifts to warning at <5s, destructive at <3s).
- Pause button `[topTrailing 16]` 36×36 glass.

---

## 14. Game-specific screens
For each game, see `08_GAMES_DETAILED_PROMPT.md` for complete flows. The wireframe rules below apply to **all** game screens:
- Top HUD as above.
- Center: game phase content (full screen, no scroll unless explicit).
- Bottom action: 1 PrimaryButton fill OR a 2-button row (cancel + confirm), 56 high, 16 padding from bottom safe area.
- Pass-the-phone interstitial (`PassThePhoneView`) between turns.
- End-of-game screen: confetti + winner card + Rematch / Home buttons.

---

## 15. Tools Tab
- Header: title "Tools" + caption.
- Grid 2 columns (md: 3, lg: 4) of ToolCard 1:1, gradient backgrounds (per `02 §2`):
  - Dice Roller (orange) — die 36pt symbol.
  - Bottle Spinner (pink) — wineglass.fill or custom bottle PNG.
  - Hourglass (cyan) — hourglass.tophalf.filled.
  - Coin Flip (yellow) — circle.lefthalf.fill.
  - Team Splitter (green) — person.3.fill.
- Tap → fullScreenCover with the tool.

---

## 16. Cards Tab (Decks library)
- Header "Cards" + segmented control "All / Saved / Shared / Locked".
- Carousel: 5 deck cards (Act, Talk, Challenges, Penalty, Couple), horizontal scroll, snap.
- Each deck card 1:1 + accent gradient + count caption + lock badge if premium.
- Tap → Deck detail with swipeable card stack.

---

## 17. Card Stack screen
- Top: deck title + close X.
- Center: stack of 3 cards (top fully visible, mid scaled 0.95, bottom 0.9). 320 wide × 480 high (mobile), centered.
- Card content: category chip top-left + prompt centered `gameTitle` + footer caption.
- Below stack: row of 3 buttons — Skip (light), Save (heart), Share (share.sheet).
- Swipe left = next, right = save, up = share.

---

## 18. Factory Tab
- Header "Factory" + caption "AI-powered game ideas".
- Two big SurfaceCards (mobile) / 2-column (md+):
  - **Game Idea Generator** — wand.and.stars icon, body, "Generate" PrimaryButton, quota chip "3 left today".
  - **Card Pack Generator** — square.stack.3d.up.fill icon, prompt input field, category picker, "Generate" PrimaryButton.
- Section "Your generations" — list of recent items with date and "Open" chevron.
- Quota enforced server-side (Cloud Functions); client shows toast error if exceeded.

---

## 19. Notifications Center (sheet)
- Header "Notifications" + Mark all read.
- Tabs: All / Friends / Rooms / System.
- Rows: icon + title + body + relative time + chevron.
- Empty state per tab.

---

## 20. Settings (full screen, accessed from Profile)
- Sectioned List style.
- Sections: Account, Notifications, App, Legal, Danger Zone.
- Same content as Profile sheet but expanded; each row may push to a sub-screen.

---

## 21. Universal Empty / Error / Loading templates
Used everywhere; centralize as `EmptyStateView`, `ErrorStateView`, `LoadingStateView`.
- Empty: SF Symbol 64pt secondary + title `gameTitle` + body secondary + optional PrimaryButton.
- Error: exclamationmark.triangle.fill 64pt destructive + title + body + "Retry" button.
- Loading: ProgressView 32 + caption secondary.

All three are vertically centered with 24pt internal stack spacing and `space-8` outer padding.

---

## 22. Web-only — Marketing Site (desktop ≥ lg)
- Top nav (sticky): logo (left) + "Games / Pricing / Download / Sign in" links (center) + "Get the app" CTA (right). Height 72.
- Hero section: 80vh, gradient bg, 64pt headline + 18pt body + CTA row (App Store / Play / "Play in browser") + product mock 3D-tilted on the right.
- Section "11 Games" — 4-column grid of game cards (reuse mobile component, larger).
- Section "How it works" — 3-step row.
- Section "Pricing" — 2 tier cards (same as paywall).
- Footer — links + socials + small print.

---

## 23. Done Checklist
For every new screen built:
- [ ] Header + safe-area handling matches the spec above.
- [ ] All four states implemented (default / empty / loading / error) — see `02C_STATE_MATRIX_PROMPT.md`.
- [ ] All interactive elements ≥ 44pt.
- [ ] Padding tokens used (no magic numbers).
- [ ] Reuses existing `SurfaceCard`, `PrimaryButtonStyle`, `StatusPillView` etc.
- [ ] Verified at xs / md / lg breakpoints.
