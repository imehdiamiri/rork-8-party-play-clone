# 16 — Game: Ten Tangle

**Premium:** Yes.  **Modes:** Single-device only.  **Players:** 3–11.

## Concept
Each player secretly draws a number 1–10. A scenario is shown ("How much do you love pineapple on pizza?", "How clean is your room?"). Each player acts/answers in a way that **expresses** their number. Then everyone (in turn) guesses what number each other player had. Closer guesses score more.

## Setup
- Players list 3–11.
- Rounds (1–5).
- Scenario pack picker (general / spicy / family / random).

## Session — `TenTangleSessionView` + `TenTangleViewModel`

### Phases
1. **Number reveal** — pass the phone, each player taps "Show my number" → big number 1–10 with subtitle "Don't tell anyone!" → "Hide" → next.
2. **Scenario** — full-screen scenario card with `theatermasks.fill` icon and title + body.
3. **Acting** — each player in turn presses "I'm Done" after they've expressed their number to the group. No timing; freeform.
4. **Guess matrix** — each player, on their turn, taps a number (1–10) for every **other** player (everyone they think). Use a horizontal selection of avatars + 10-button row. Shows "Skip" if they prefer not to guess one.
5. **Reveal & score** — all guesses revealed simultaneously. Score per guess = `max(0, 10 − |guess − actual|)`. Total per player.
6. **Round result** — sorted leaderboard. "Next Round" or "Finish".

### Settings model
Internal struct (in `TenTangleViewModel`): `numberOfRounds`, `scenarioPackID`, `playerCount`. No persistence; new game each session.

### UI notes
- Big-number reveal uses `viralTitleStyle(120, .black)` with mesh accent.
- Guess matrix is a `LazyVGrid` with 5×2 number buttons inside a SurfaceCard per player target.
