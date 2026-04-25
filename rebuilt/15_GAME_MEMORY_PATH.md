# 15 — Game: Memory Path

**Premium:** Yes.  **Modes:** Single, Multi, Team.  **Players:** 2+.

## Concept
A hidden orthogonal path is generated on a grid. Players tap their way along it step-by-step. Correct tap = green; wrong tap = red shake + reset progress.

## Setup — `MemoryPathSetupView`
- **Difficulty card** — picks the `MemoryPathDifficulty` (`.easy / .medium / .hard / .expert`) which controls grid size.
- **Path Length card** — separate +/− stepper using `MemoryPathSettings.stepsRange(for: difficulty)`. Grid size and step count are decoupled.
- **Game mode** — `MemoryPathGameMode` has only **two** cases: `.timeRace` and `.turnBased`. There is **no "Limited Attempts" mode and no "Only One Try" mode.**
- Play type — single / team rotation.
- Players list (single/team) or room (multi).

## Path generation — `MemoryPathGenerator`
Generates a valid path; outputs `pathTiles` (row/col tuples), `startTile` (rendered green), `endTile` (rendered cyan).

## Session — `MemoryPathSessionView` + `MemoryPathViewModel`

### Phases (`MemoryPathPhase`)
`setup / countdown / passDevice / turnSwitch / playing / hintActive / finished`.

### Tap behaviour
- Correct tap → tile pulses green, `progress` advances.
- Wrong tap → tile uses a custom red shake (`.offset(x: -4)` + `.scaleEffect(0.92)` with a spring `repeatCount: 3, autoreverses`) and `progress` resets to step 1. There is **no time penalty in time-race mode** (no 3s cost). There is **no `ShakeEffect` modifier in the codebase.**
- In `.turnBased` single-device, a wrong tap consumes a `turnAttempts` retry; in turn-based multi-player single-device it rotates to the next player via `passDevice`.

### Hint button
Icon: `eye.fill` (**not `lightbulb.fill`**). Eligibility: `hintEligible = settings.playType == .team && gridSize >= 7 && stepsToFind >= 15`. Unlocks once `progress >= 50% of stepsToFind`. Reveals the next correct tile for **2 seconds** (not 1s). It is a **team-mode** feature, not a time-race feature.

### Confetti
On finish, an in-view `ConfettiPiece` particle simulation (~30 pieces) is drawn — implemented inline, no external library.

### Scoring
Per-player ranking score = `completionBonus + progressScore + efficiencyBonus + timeBonus`. **No `RewardPolicy` invocation.**

### First-time hint
`FirstTimeHintOverlay` keyed `"hint_seen_memory_path"`.
