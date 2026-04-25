# 10 — Shared Game Detail Screen

`GameDetailView` (in `Views/GameViews.swift`) is the **shared** detail page for most games (Imposter has its own; see file 13). Used for: Reverse Singing, Guess the Seconds, Memory Grid, Memory Path, Pass & Guess, Tap in Order, Color Trap, Truth & Dare, Draw & Rush, Ten Tangle.

## Layout
NavigationStack child. Toolbar: `.topBarLeading` chevron back (default) and a trailing ellipsis menu (`ProfileToolbarButton` from the parent tab, not duplicated here). `AppBackgroundView` background. ScrollView with bottom padding ≥ 80.

Sections in order:
1. **Hero card** — image (if `heroImageURL != nil`) on top half, otherwise a tinted gradient rectangle. Use the `Color(...).frame(height: …).overlay { AsyncImage(...) {...}.allowsHitTesting(false) }.clipShape(.rect(cornerRadius: 22))` pattern. Overlay (alignment: bottomLeading) with title + short description.
2. **Tutorial block** — `PartyGameTutorial` from `Models/PartyGameTutorial.swift` for the game. Shows ordered numbered bullets (1. 2. 3.) with icon + title + body for each step. SurfaceCard styling.
3. **Mode picker** — appears only if `game.supportedModes.count > 1`. Three large cards (or two) with `mode.icon` + `mode.title` + `mode.subtitle` + `mode.accentColor` selection ring. Tapping sets local `@State selectedMode`. For Imposter, route into `imposterStyleSelection` instead.
4. **Player count stepper / list** — depends on the game's flow:
   - Single-device games: `UnifiedSetupComponents.PlayerListEditor` shows a list of named players with add/remove + offline-friend picker. Min/max enforced from `game.minPlayers/maxPlayers`.
   - Multi-device games: a "Create Room" / "Join Room" pair of buttons that route to `CasualCreateRoomView` / `CasualJoinRoomView`.
   - Team mode: button "Set Up Teams" → `TeamModeEntryView` then `TeamSetupView` for assignment.
5. **Game-specific settings** — varies per game. Each game's setup view (e.g. `ReverseSingingSetupBlock`, `GuessTheSecondsSetupBlock`, `MemoryGridSetupView`, etc.) is embedded here when the selected mode applies.
6. **Start button** — full-width `PrimaryActionButtonStyle`, label `"Start Game"` (or "Continue" for team mode going to setup). Disabled when constraints not met (player count, settings invalid, premium-locked-without-subscription). Plays `SoundManager.shared.playGameStart()` on tap. Calls `appModel.startSession(...)` which sets `appModel.activeSession` triggering the full-screen game cover.
7. **Lock CTA** — if game is premium and user is not a subscriber and trial unavailable, replace the Start button with a `"Unlock with Pro"` CTA → presents `PaywallView`.

## Per-game setup blocks (used inside the detail or as standalone setup views)
- `ReverseSingingSetupBlock` → recording duration slider 5–60s, # rounds, players list.
- `GuessTheSecondsSetupBlock` → target duration picker (5/10/15/20/30/45/60s), rounds per player (1–5), max 6 turns.
- `ImposterSingleDeviceSetupView` (own file) → category pack, rounds, discussion duration.
- `MemoryGridSetupView` → grid size picker, players list (single) or room (multi).
- `MemoryPathSetupView` → difficulty (easy/medium/hard/expert), gameMode (timeRace/limitedAttempts/onlyOneTry), players list.
- `PassGuessSetupView` → questionMode (predefined/custom), question selection, answerTimeLimit (30/45/60s), guessTimeLimit (20/30/45s), rounds (1–5).
- `TapInOrderSetupView` → board size (small/medium/large), rounds, time limit.
- `ColorTrapSetupView` → speed (slow/normal/fast), strikes (3 default).
- `SpinBottleSetupView` → players list 3–12, dare/truth pack toggle.
- `DrawRushSetupView` → concept pack, drawing time (30/60/100s), guesser-judge toggle.

## Cross-cutting toolbar
`gameTopBarMenu(primaryTitle:, primarySystemImage:, confirmationTitle: "Exit Game?", confirmationMessage: "Your progress will be lost.", confirmButtonTitle: "Exit", onPrimaryAction: …, onConfirmExit: …)` is **only** applied to the active session views (file 11–21), not the setup view.
