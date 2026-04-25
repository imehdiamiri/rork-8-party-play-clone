# 20 — Game: Truth & Dare (Spin the Bottle)

**Premium:** No.  **Modes:** Single-device only.  **Players:** 3–12.

## Concept
Classic spin-the-bottle. The bottle spins, lands on a player; that player picks Truth or Dare and is shown a prompt from the active difficulty pack.

## Setup — `SpinBottleSetupView`
- Players list 3–12.
- **Difficulty** (`SpinBottleDifficulty`): `.mild / .classic / .bold`. Default `.classic`. The difficulty card has a "Vibe" label with a red `flame.fill`.
- There is **no Truth-on/off and Dare-on/off toggle.** Both Truth and Dare are always available.
- There is **no Spicy / Couple / Adult pack and no 18+ gate.**

## Session — `SpinBottleSessionView`

### Phases
`SpinBottleSessionViewModel`'s state machine: `.idle → .spinning → .landed → .choosing → .prompt → .done`.

### Layout
- Players arranged on a circle around the screen centre using polar coordinates.
- A bottle image at the centre, rotated by `bottleAngle: Double`.
- Restart button in the top-right of the circle screen.

### Spin
Tap "Spin" → animate `bottleAngle` to a target via spring/ease-out. The selected player is computed from the final angle.

### Choosing
Two big buttons: **Truth** (`bubble.left.and.text.bubble.right.fill`) and **Dare** (`flame.fill`). The chosen `SpinBottleChoice` then drives the prompt.

### Prompt
Drawn from `SpinBottleContent.truths(for: difficulty)` / `dares(for: difficulty)` (both return `[String]` — there is no `Card { id, text, category }` model). `usedTruths` / `usedDares` Sets prevent duplicates within a session.

### Re-rolls
Each player gets `rerollsLeft: Int = 2` re-rolls per prompt.

### Win condition
None — this is a hangout game. Session ends when user exits.
