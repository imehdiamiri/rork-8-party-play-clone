# 16 — Game: Ten Tangle

**Premium:** Yes.  **Modes:** Single-device only.  **Players:** 3–11.

## Concept
Each round has one designated **guesser**. Every other player secretly receives a private number from `1` to `playerCount - 1` (so e.g. with 4 players, numbers 1–3; the "10" in the title is just branding). A scenario is shown. Each non-guesser acts/answers in a way that expresses their assigned number. After everyone has acted, the guesser tries to guess each non-guesser's number.

There is **no rounds picker** — `totalRounds = players.count`, so every player becomes the guesser exactly once across the game.

There is **no scenario pack picker.** A single fixed array of 30 scenarios is hard-coded inside the view model, and `usedScenarioIndices: Set<Int>` prevents repeats until exhausted.

## Setup
- Players list 3–11 (`GameType.tenTangle.minPlayers = 3, maxPlayers = 11`).
- No rounds picker, no scenario pack picker.

## Session — `TenTangleSessionView` + `TenTangleViewModel`

### Phases (full state machine)
`setup → guesserAnnounce → passToPlayer → showNumber → scenarioReveal → acting → guesserGuessing → roundReveal → scoreboard → finalResults`.

1. **Guesser announce** — name of this round's guesser.
2. **Pass-to-player loop** — each non-guesser in turn taps to reveal their secret number.
3. **Show number** — big number `Text("\(number)").font(.system(size: 96, weight: .heavy, design: .rounded))` (size **96**, not `viralTitleStyle`). Disaster/Perfect scale labels: `1 = "Disaster 😬"` (red), `max = "Perfect 😍"` (green); intermediate values colour-graded by `numberColor(_:)` (red <0.34, yellow <0.67, green ≥0.67 of max).
4. **Scenario reveal** — full-screen scenario card.
5. **Acting** — non-guessers act out their numbers freeform; guesser steps away.
6. **Guesser guessing** — for each non-guesser, the guesser picks a number from a `ScrollView(.horizontal) + HStack` of buttons (single row, **not a 5×2 LazyVGrid**).
7. **Round reveal** — actual numbers shown next to guesses.
8. **Scoreboard** — per-round.
9. **Final results** — full sorted scoreboard with rank emojis 🥇🥈🥉. Not a winner-only screen.

### Scoring
**Binary**: `if guess == actual { roundPoints += 1 }`. There is **no `max(0, 10 - |guess - actual|)` proximity formula.**

### Internal state
Lives directly on `TenTangleViewModel` properties (no separate `Settings` struct). Key fields: `players`, `currentRoundIndex`, `totalRounds (= players.count)`, `currentGuesserIndex`, `currentNumber`, `usedScenarioIndices`, `scores`.
