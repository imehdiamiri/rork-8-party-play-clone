# 18 — Game: Tap in Order

**Premium:** Yes.  **Modes:** Single, Multi.  **Players:** 1–30.

## Concept
A grid of numbered tiles in random positions. Tap them in order 1, 2, 3, …, N as fast as possible. Wrong tap = small time penalty (no game-over). Same board for every player.

## Setup — `TapInOrderSetupView`
- **Board size**: small (4×4 = 16 tiles), medium (5×5 = 25), large (6×6 = 36).
- **Memory variant** (sub-mode):
  - **Classic** — numbers stay visible the whole round.
  - **Hide-after-3** — first 3 tiles stay visible; rest hide once you tap them and you must remember positions.
  - **All-hidden** — only the next tile glows briefly when you tap correctly.
- **Rounds**: 1–5.
- **Time limit**: 60 / 90 / 120 / unlimited.

## Session — `TapInOrderSessionView`
View model: `TapInOrderViewModel`.

### State (`TapInOrderGameState`)
- `boardTiles: [Int]` — flattened positions of numbers 1..N.
- `currentTarget: Int` — next number expected.
- `playerProgress: [UUID: Int]` — current target per player (multi).
- `playerCompletionTime: [UUID: Double]`.
- `wrongTaps: [UUID: Int]`.

### Live UI
- LazyVGrid with N × N tiles. Each tile shows its number (.title2 .black) on a card with accent gradient.
- On correct tap: tile dims to white-10% with a checkmark, plays `playTapCorrect()`, +1 progress.
- On wrong tap: tile shakes red, plays `playTapWrong()`, +0.5s penalty added to elapsed clock.
- Timer top-right (mm:ss.s). Progress dots row showing `current/total`.

### Multi-device
Host broadcasts the same `boardTiles` array. Each player races independently. When everyone finishes (or time runs out), leaderboard appears.

### Result
Sorted by `effectiveTime = completionTime + 0.5 * wrongTaps` ascending. If a player didn't finish, sort by farthest reached, then time.
