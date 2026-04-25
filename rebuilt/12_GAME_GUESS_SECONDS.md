# 12 — Game: Guess the Seconds

**Premium:** No.  **Modes:** Single-device.  **Players:** 2–30.

## Concept
Pick a target time (e.g. 15s). Hide the clock. Player taps Start, counts in their head, taps Stop when they think the time elapsed. The closer to target, the better. Lowest cumulative `|actual − target|` wins.

## Setup
- Players list ≥ 2 (no max enforced visually beyond room cap).
- Target time picker (segmented): 5 / 10 / 15 / 20 / 30 / 45 / 60 seconds.
- Rounds per player: 1 / 2 / 3 / 4 / 5 (default 3).
- Total turns capped at 6 (rounds × players ≤ 6 in single device, otherwise scrolls).

## Session view — `GuessTheSecondsSessionView.swift`
Drives `GuessTheSecondsGameState` inside `GameSession`. Phases reuse `MatchPhase`.

### Flow
1. **Pass to next** — "{Player N}, your turn. Target: 15.0s. Tap when ready."
2. **Live round** — fullscreen huge button "Start" → "Stop". When Start is tapped, the timer is **hidden** (no number shown). On Stop, record `actualTime`. `RoundLiveState.hasStartedTiming` controls UI; `measuredElapsedTime` is the player's reading (visible only after Stop).
3. **Round result** — show target vs actual + diff (color-coded: green ≤ 0.5s, blue ≤ 1.5s, orange ≤ 3s, red > 3s). "Next" advances `activeTurnIndex`.
4. **Finished** — leaderboard sorted by total `|diff|` ascending. Tie-breaker: smaller individual best. Top player gets a +stars award based on `RewardPolicy`.

### State storage
`GuessTheSecondsGameState`:
- `activeTurnIndex` 0..<totalTurns
- `roundTargets[Int:Double]` — target time per global round number
- `turnResults: [GTSTurnResult]`
- `selectedTime`, `roundsPerPlayer`, `totalTurns`

`isFirstPlayerOfRound(playerCount:)` is used to decide when to show "Round N" header.

### Edge cases
- Player can press Stop instantly (diff = target). That's fine, it counts.
- If user backgrounds the app mid-round, the timer continues using `Date()` deltas (not `Timer`).
