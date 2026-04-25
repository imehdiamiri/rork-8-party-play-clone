# 18 — Game: Tap in Order

**Premium:** Yes.  **Modes:** Single-device, Multi-device.  **Players:** 1+.

## Concept
A grid is shown with numbers / coloured pattern in random positions for a brief preview window, then hidden. Players tap the tiles in order 1…N from memory.

## Setup — `TapInOrderSetupView`
- **Grid size** picker: 4×4, 5×5, 6×6, 7×7 (`gridSizeOptions = [4, 5, 6, 7]`). Not labelled small/medium/large.
- **Variant** (`TapInOrderVariant`): **`.numberMemory`** (numbers shown then hidden) and **`.patternMemory`** (highlighted pattern shown then hidden). There is **no Classic / Hide-after-3 / All-hidden mode.**
- **Tile count** picker (depends on grid size + variant — `tileOptions(for:variant:)` returns different lists per combination, e.g. 4×4 numberMemory: `[4, 6, 8, 10]`).
- No rounds picker. No time-limit picker. `roundCount = 1` is hard-coded at start.
- Players list (single) or room (multi).

## Session — `TapInOrderSessionView` + `TapInOrderViewModel`

### Preview phase
After "Start", the board displays the numbers / pattern for `TapInOrderBoard.previewDuration(tileCount:) = max(4.0, 3.5 + tileCount * 0.35)` seconds, then hides them. This is the actual memory mechanic.

### State (`TapInOrderGameState`)
`variant, gridSize, tileCount, seed, selectedCells, currentPlayerIndex, playerResults, isFinished`. (There is no `boardTiles`/`currentTarget`/`playerProgress`/`playerCompletionTime`/`wrongTaps` shape.)

### Tap behaviour
- Correct tap → `selectedCells` advances. Sound: `playTapCorrect()`.
- Wrong tap → `missTaps` increments. Sound: `playTapWrong()`. **No time penalty added to the elapsed clock.**

### Mid-game UI
Live elapsed timer, miss count, "Give Up" destructive button with confirmation dialog.

### Outcome overlay
`Done!` (green checkmark) or `Gave Up` (orange `flag.fill`).

### Sort / leaderboard
`if lhs.missTaps != rhs.missTaps { return lhs.missTaps < rhs.missTaps } return lhs.elapsedSeconds < rhs.elapsedSeconds`. **No `effectiveTime = completionTime + 0.5 * wrongTaps` formula.**

### Multi-device
Spectator board preview rendered with `.saturation(0)` greyscale. Seed is broadcast so every device generates the same board.

### First-time hint
`FirstTimeHintOverlay` keyed `"hint_seen_tap_in_order"`.
