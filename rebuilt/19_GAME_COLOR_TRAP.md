# 19 — Game: Color Trap

**Premium:** Yes.  **Modes:** Single, Multi.  **Players:** 1–30.

## Concept
A forbidden color is announced. Colored tiles flash one at a time. Tap every tile **except** the forbidden color. Three wrong taps and you're out. Last player standing or longest survivor wins.

## Setup — `ColorTrapSetupView`
- **Speed**: slow (1.4s/tile) / normal (1.0s) / fast (0.7s) / extreme (0.5s, ramps faster).
- **Strikes allowed**: 3 (default), 5, unlimited (high score).
- **Players list** (single) or **Room create/join** (multi).

## Session — `ColorTrapSessionView`
View model: `ColorTrapViewModel`.

### Round flow
1. **Announce** — full-screen card "Don't tap RED" with the forbidden color filling the bg, 1.5s.
2. **Live** — center of screen shows a single big colored circle that swaps every `tickInterval`. Player taps it if it's any color **other** than the forbidden one. If forbidden, **don't tap**.
   - Correct tap (non-forbidden + tapped within window): +1 score, glow + haptic.
   - Wrong tap (forbidden tapped, OR non-forbidden missed and timer expired): −1 strike, red flash + error haptic.
   - Continues until strikes exhausted or 60s elapsed.
3. **Result** — score (correct taps) + strikes used. Multi-device leaderboard combines.

### State (`ColorTrapGameState`)
- `forbiddenColor: String` ("red"/"blue"/"green"/"yellow"/"purple"/"orange").
- `currentColor: String`.
- `tickInterval: Double`.
- `playerScores: [UUID: Int]`.
- `playerStrikes: [UUID: Int]`.
- `gameOver: Bool`.

### Visual
- Background pulses with the current color at 6% opacity.
- Big tappable circle 220pt with linear gradient of that color.
- Bottom strip: 3 hearts, dim as strikes accumulate.
