# 14 — Game: Memory Grid

**Premium:** No.  **Modes:** Single-device, Multi-device. (Team mode is declared in `supportedModes` but the setup view does not branch on team mode.)  **Players:** 1+.

## Concept
Classic pair-matching memory game. Single-device players take turns; multi-device plays simultaneously with snapshots streamed back to spectators.

## Setup — `MemoryGridSetupView`
- Grid size picker: `tiny3x4`, `small4x4`, `medium4x5`, `large5x6`, `huge6x6`. **Default `tiny3x4`.**
- Players list (single) or room create/join (multi).

## Session — `MemoryGridSessionView` + `MemoryGridViewModel`

### Board
`generateBoard` shuffles the symbol/colour pairs with a plain `.shuffled()` (**no seed**). In single-device every player gets a **freshly regenerated board** at their turn — boards are not shared.

Symbol pool (18 distinct SF Symbols): `star.fill, heart.fill, moon.fill, sun.max.fill, bolt.fill, flame.fill, leaf.fill, drop.fill, snowflake, cloud.fill, wind, tornado, sparkles, bell.fill, flag.fill, crown.fill, diamond.fill, globe.americas.fill`.

Tile colours cycle through **10** accents: cyan, pink, orange, green, purple, yellow, mint, red, indigo, teal.

### Tile interaction
- Tap → flip with a `rotation3DEffect` 3D animation.
- After **two** tiles are face-up, increment `moveCount` (one per pair, **not one per flip**).
- Match: stay face-up, increment `matchedPairs`, play `SoundManager.playMatch`.
- Mismatch: 0.8s delay (`Task.sleep(for: .milliseconds(800))`) then flip back, play `SoundManager.playMismatch`.

### Phases (`MemoryGridPhase`)
`ready / playing / playerComplete / results`. **No countdown phase.** Player taps Start and gameplay begins immediately.

### Multi-device
- Each player plays on their own phone with their own board.
- `MGSpectatorSnapshot` (and `MGSpectatorTile`) are broadcast every 0.7s by the active player's device via `spectatorBroadcastTimer`.
- On `scenePhase == .active`, the device re-broadcasts current state via `rebroadcastCurrentCasualSessionState`.
- Multi-device shows a "Your Turn! Start" preamble screen and a `multiWaitingView` with the spectator board rendered in `.saturation(0)` greyscale while waiting.

### First-time hint
`FirstTimeHintOverlay` keyed `"hint_seen_memory_grid"`.

### Finished
Leaderboard sorted by elapsed time. **No `RewardPolicy` invocation, no star granting, no team-mode branching, no countdown.**

### Sounds
`SoundManager.shared.playTileFlip / playMatch / playMismatch / playVictory`.
