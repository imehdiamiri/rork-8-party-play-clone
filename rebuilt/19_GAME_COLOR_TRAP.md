# 19 — Game: Color Trap

**Premium:** Yes.  **Modes:** Single-device, Multi-device.  **Players:** 1+.

## Concept
A forbidden colour is announced. Coloured tiles fall from the top of the screen through 4 columns. Tap every tile **except** the forbidden colour before it reaches the bottom.

It is **not** a single swapping centre circle — it is a falling-tiles arena.

## Setup — `ColorTrapSetupView`
- **Difficulty** (`ColorTrapDifficulty`): `.easy / .medium / .hard`.
  - Easy: `spawnInterval 0.9`, `tileLifetime 1.9s`, total duration `20s`.
  - Medium: `0.65 / 1.5 / 30s`.
  - Hard: `0.45 / 1.15 / 45s`.
  - There is **no `slow / normal / fast / extreme` setting**.
- **No strikes setting.** `maxFails` is a fixed constant in `ColorTrapViewModel`.
- Players list (single) or room (multi).

## Session — `ColorTrapSessionView` + `ColorTrapViewModel`

### Layout
- 4-column falling-tile arena (`ColorTrapGenerator.columnCount = 4`).
- Tiles drift from top to bottom over `tileLifetime` seconds with progress `t = (elapsed - spawnedAt) / lifetime`.
- Tile size: `min(colWidth * 0.78, 72) * spawn.size` with a **`RadialGradient`** fill (not LinearGradient, not 220pt).
- Static `Color.black.opacity(0.15)` arena background. **No pulsing background.**
- Header strip at the **top** of the screen: forbidden-colour banner + 3 hearts that dim as fails accumulate.

### Spawns
`ColorTrapGenerator.generateSpawns(...)` uses a seeded RNG to pre-generate the entire spawn schedule up front. Multi-device: same seed → identical schedule across devices.

### Palette
`ColorTrapViewModel.palette` has **5 entries** (`paletteSize = 5`). State stores `forbiddenColorIndex: Int`, not a colour name string.

### State (`ColorTrapGameState`)
`difficulty, seed, forbiddenColorIndex, currentPlayerIndex, playerResults, isFinished`.

### Scoring
`score = hits * 10 + Int(survivalTime * 5) - fails * 15`.

### Multi-device spectator
Shows the first 8 spawns frozen at their schedule positions in `.saturation(0)` greyscale.

### First-time hint
`FirstTimeHintOverlay` keyed `"hint_seen_color_trap"`.
