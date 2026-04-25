# 13 — Game: Imposter

**Premium:** No.  **Modes:** Single-device only (`GameType.imposter.supportedModes = [.singleDevice]`).  **Players:** 4+.

There is **no multi-device, no team mode, no realtime sync** for Imposter. The `ImposterGameDetailView` only renders the single-device card.

## Routing
1. `ImposterStyleSelectionView` — pick **Discussion Mode** or **Clue Mode** (two large cards, full-width, with a `chevron.right` and `LinearGradient` overlay — not a 12% bg + tint border SurfaceCard).
2. `ImposterGameDetailView` — hero card + single-device setup card + category picker + rounds + (Discussion mode only) discussion timer + players list.
3. `ImposterSingleDeviceSetupView` → `ImposterSessionView`.

## Style cards (`ImposterStyleSelectionView`)
- **Discussion Mode** — `bubble.left.and.bubble.right.fill` orange.
- **Clue Mode** — `magnifyingglass.circle.fill` purple.

Subtitle and 1-line "details" are rendered as a single `·`-separated horizontal strip, not three stacked bullets.

## Game Detail (`ImposterGameDetailView`)
- Hero card.
- **Category** picker — a **horizontal `ScrollView` of pill chips** (not a 3-col grid, no emoji icons). Categories: "Animals", "Food & Drinks", "Places", "Jobs", "Movies", "Random". Selected chip uses `gameStyle.accentColor` (orange for Discussion, purple for Clue), not blue.
- Rounds via `SetupRoundsSection`.
- **Discussion duration** (Discussion mode only) via `SetupTimerSection(range: 10...300, step: 10)` with icon `bubble.left.and.bubble.right.fill`. Not 30/60/90/120 chips.
- Players list (min 4).
- `HowToPlayButton` and Start.

## Session — `ImposterSessionView`

### Roles
At round start one random player is the Imposter; everyone else sees the same secret word from the chosen category. The imposter sees a "?" placeholder.

### Phases (`ImposterPhase`)
1. **`.roleReveal`** — single-device pass-the-phone. Each player taps "I'm Ready", reveals their card, taps "Hide", passes.
2. **`.ready`** — confirmation that all players have seen their card. Start button.
3. **`.discussion`** (Discussion mode) — countdown driven by `startDiscussionTimer` which **rebuilds the entire `ImposterRoundState` every second** to decrement `discussionTimeRemaining`. Has a "Skip to Voting" button.
4. **`.clueGiving`** (Clue mode) — current player types a clue (single-line `TextField`, **hard-capped at 30 chars** via `String(trimmed.prefix(30))`). Submits, cycles.
5. **`.voting`** — pass-the-phone hidden votes. Tally shown only after all submitted.
6. **`.result`** — Reveal imposter, show a **Scoring SurfaceCard** stating the rules in plain text, "Play Again" button.

There is **no imposter-word-guess mechanic, no "3 chances", no confetti, no particle simulation, no red dim animation.** The result view is a static green/red icon + text + score card.

### Scoring (actual code)
- Crew wins (correct vote): each correct voter +**100**.
- Imposter survives (incorrect vote): imposter +**150**.
- Otherwise: 0.

There is **no `RewardPolicy` invocation, no star granting on game end, no +75 "guesses the word" rule.**

### Sounds
`FeedbackService.shared.playRoundStart()`, `playPhaseTransition()`, `playClick()`, `playVote()`, `playResultReveal()`, `playGameEnd()`.
