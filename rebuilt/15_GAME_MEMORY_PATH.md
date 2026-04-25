# 15 — Game: Memory Path

**Premium:** Yes.  **Modes:** Single, Multi, Team.  **Players:** 2–30.

## Concept
A path is hidden on a 5×5 / 6×6 / 7×7 grid. You start at the bottom-left and tap your way step by step to the top-right. A correct tile lights up green; a wrong tile flashes red and the game punishes you (depending on game mode).

## Setup — `MemoryPathSetupView`
- **Difficulty** picker:
  - Easy → 5×5 grid, 5 steps
  - Medium → 6×6, 6 steps (default)
  - Hard → 6×6, 8 steps
  - Expert → 7×7, 10 steps
- **Game mode** picker:
  - **Time Race** (default) — wrong tap costs 3s; finish fastest wins.
  - **Limited Attempts** — 5 wrong taps total; if exceeded you're out.
  - **Only One Try** — first wrong tap ends your run; lowest reach wins, ties by time.
- Players list (single/team) or room (multi).

## Path generation — `Services/MemoryPathGenerator.swift`
Deterministic, seeded by session UUID. Generates a valid orthogonal path from `(0, gridSize-1)` (bottom-left) to `(gridSize-1, 0)` (top-right) using a randomized DFS that biases toward the goal. `targetSteps` includes start + end. Outputs `pathIndices: [Int]` (row-major flattened).

## Session — `MemoryPathSessionView`

### Phases
1. **Show path** — path tiles flash blue in sequence for ~1.5s total, then disappear. Single device: shows once at the start of each player's turn. Multi/team: shown simultaneously to everyone, then everyone races.
2. **Live** — grid of 25/36/49 tiles; current player taps. Correct tile = green pulse + check. Wrong = red shake (use `.modifier(ShakeEffect(amount: 6))` or rotation jiggle), penalty applied.
3. **Result** — per-player completion time + attempts + reach. Sort.

### Hint button
A small `lightbulb.fill` button appears after 3 wrong taps in **Time Race** mode (other modes never show it). One use per round; reveals the next correct tile for 1s. Costs no stars.

### View model — `MemoryPathViewModel`
Tracks `currentStep`, `attempts`, `wrongTapsThisRound`, `startTime`, `isFinished`.

### Scoring
- Time Race winner = lowest elapsed.
- Limited Attempts winner = farthest progress; ties by time.
- Only One Try winner = farthest; ties by time.
RewardPolicy: starsForWin 8, participation 2.
