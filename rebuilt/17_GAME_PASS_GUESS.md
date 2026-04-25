# 17 — Game: Pass & Guess

**Premium:** Yes.  **Modes:** Single-device only.  **Players:** 2+.

## Concept
A question is shown. Players pass the phone, each privately writes an answer. Answers are shuffled and revealed one by one — players take turns guessing **who wrote which answer**.

## Setup — `PassGuessSetupView`
The setup view does **not** include a question picker. It only configures:
- **Answer time** via `SetupTimerSection(range: 15...120, step: 10)` with icon `pencil.circle.fill`.
- **Guess time** via `SetupTimerSection(range: 15...90, step: 10)` with icon `eye.circle.fill`.
- **Round count** via `SetupRoundsSection`. Default `roundCount = 1`.
- Players list.

The question itself is chosen at session start, not in the setup view.

## Session intro screen — `PassGuessSessionView`
Before the first round begins, the host picks the question:
- `PassGuessQuestionMode` toggle: `.predefined` or `.custom`.
- If `.predefined`: pick from a flat list of 22 hand-written questions (no category grouping). Stored as `introSelectedQuestionID`.
- If `.custom`: free-text `introCustomQuestion`.

### Phases (`PassGuessRoundPhase`)
`.intro / .answering / .guessing / .reveal / .leaderboard`.

1. **`.intro`** — round number + question. "Tap to begin."
2. **`.answering`** — privacy screen ("They'll write their answer privately.") → next player taps to enter answer → `TextField` with countdown → submit. Auto-skip on timer expiry.
3. **`.guessing`** — privacy screen ("They'll guess who wrote this answer.") → next guesser sees the shuffled answer card and an avatar grid → taps the player they think wrote it.
4. **`.reveal`** — actual writer revealed; per-answer correct/wrong.
5. **`.leaderboard`** — sorted totals + "Next Round" / "Finish".

### Realtime sync
Settings are stored on `AppViewModel.currentPassGuessSettings` and broadcast every change via `appModel.updatePassGuessSettings(updated)`.

### Persistence
The 22-question bank is duplicated in two places: a private constant inside `PassGuessSessionView` and `AppViewModel.passGuessQuestionBank`.

### Stars / RewardPolicy
**Not invoked.** No stars are granted on game end.
