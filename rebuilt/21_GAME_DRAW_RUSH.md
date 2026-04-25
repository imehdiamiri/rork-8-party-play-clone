# 21 — Game: Draw & Rush

**Premium:** Yes.  **Modes:** Single-device, Multi-device.  **Players:** 2–12.

## Concept
One player is the drawer. They either get a secret concept (`DRConceptMode.preset`) or freely pick what to draw (`.freeDraw`). Everyone else guesses. Drawer earns points based on how fast someone guesses.

## Setup — `DrawRushSetupView`
- **Concept mode** (`DRConceptMode`): `.preset` (drawer is shown a secret word) or `.freeDraw` (drawer picks freely; the concept screen shows "Free draw"). There is **no Easy/Normal/Hard/Random pack picker.**
- Players list (single) or room (multi).
- Subtitle is hard-coded: "Each player draws once · 60s per turn." There is **no drawing-time picker, no judge-mode toggle.**

## Single-device session — `DrawRushSessionView`
## Multi-device session — `DrawRushMultiDeviceSessionView`
These are **two distinct files**, not just two flows in one view. The view model is constructed with `DrawRushViewModel(isMultiDevice: Bool, conceptMode: DRConceptMode, ...)`.

### Phases (`DrawRushPhase`)
`turnIntro / drawerReveal / drawing / passForGuesses / guessing / drawerJudging / roundResults / finalLeaderboard`.

### Drawing
Full-screen Canvas. Strokes are `DRStroke` values whose `color` property is a **string raw value of an enum** (not a hex string).

### Realtime
In multi-device, drawer streams strokes to other devices via realtime broadcast.

### Leaderboard
`DrawRushViewModel.leaderboard` is a computed sorted players array. **No `RewardPolicy` invocation.**
