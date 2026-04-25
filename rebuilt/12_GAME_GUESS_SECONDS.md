# 12 — Game: Guess the Seconds

**Premium:** No.  **Modes:** Single-device only (`GameType.guessTheSeconds.supportedModes = [.singleDevice]`).  **Players:** 2+.

## Concept
Pick a target time (e.g. 15s). Hide the clock. Player taps Start, counts in their head, taps Stop when they think the time elapsed. The closer to target, the better. Lowest cumulative diff wins.

## Setup
- Players list ≥ 2.
- Target time: a hold-to-repeat **+/− stepper** (`GuessStepperButton`) clamped 1…60 seconds. Initial repeat delay 350ms then 90ms while held. **Not segmented**, no preset chips.
- Round count picked through `SetupRoundsSection`.
- Top bar: `HowToPlayButton`.

## Session view — `GuessTheSecondsSessionView.swift`

State lives directly on `GuessTheSecondsSessionViewModel` (there is **no `GuessTheSecondsGameState` struct**). Key properties: `activeTurnIndex`, `roundTargets: [Int: Double]`, `results: [TurnResult]`, computed `totalTurns = session.rounds.count`, `currentRoundNumber`, `isFirstPlayerOfCurrentRound`.

### Round-locking rule
The first player of each round picks/edits the target time. Subsequent players in the same round are **locked into that target** via `roundTargets[currentRoundNumber]`. `canEditTargetTime = isFirstPlayerOfCurrentRound && !currentRoundTargetLocked`.

### Flow (single-device, no dedicated pass-the-phone screen)
1. **Setup row** — "Now" pill showing the active player's name, target stepper (locked once first player starts), `StatusPillView` icons (figure.mind.and.body / timer / checkmark.seal.fill).
2. **Live round** — large Start → Stop button. While running, the target/timer area shows `"•••••"` (the elapsed value is hidden). Elapsed is derived from `Date().timeIntervalSince(startedAt)` deltas (no `Timer`). On Stop, append a `TurnResult` and play `FeedbackService.playTimerStop()` then `playSuccess()` / `playError()` based on accuracy.
3. **Score table** — per-round cells coloured by `AccuracyBand`: `perfect` (== 0) green, `close` (< 1s) green, `okay` (≤ 2s) yellow, `far` (> 2s) red. Plus per-player totals and a current-player highlight.
4. **Finished** — final leaderboard inside the same scroll view + `MultiplayerResultActionsBar`.

There is **no rounds-per-player cap of 6, no segmented preset picker, no pass-the-phone privacy screen, no orange tint, no `RewardPolicy` invocation, no scenePhase background handling.**

### First-time hint
`FirstTimeHintOverlay` keyed `"hint_seen_guess_seconds"`.

### Sounds
`FeedbackService.shared.playTimerStart()` on Start, `playTimerStop()` on Stop, `playSuccess()` / `playError()` based on accuracy band, `playGameEnd()` on finish.
