# 17 — Game: Pass & Guess

**Premium:** Yes.  **Modes:** Single-device.  **Players:** 2–30.

## Concept
A question is shown ("What's your guilty pleasure song?"). Players pass the phone, each types a private answer, the device shuffles them, then players take turns guessing **who wrote which answer**. The bigger the social group, the more chaos. After all guesses, reveal scoring.

## Setup — `PassGuessSetupView`
Settings (`PassGuessSettings`):
- **Question mode**: predefined (pick from a curated list grouped by category) or custom (enter your own).
- **Selected question** OR custom text.
- **Answer time limit** (seconds): 30 / 45 (default) / 60.
- **Guess time limit**: 20 / 30 (default) / 45.
- **Rounds**: 1–5.

## Session — `PassGuessSessionView`

### Phases (`PassGuessRoundPhase`)
1. **`.intro`** — Round N of M, big question card, "Tap to start answering" with a "Pass to {first player}" prompt.
2. **`.answering`** — Each player in turn:
   - "Pass to {name}" → tap-to-continue.
   - Question shown again at the top.
   - Answer TextField (multiline, max ~140 chars) with `Done` button. Countdown timer top-right.
   - On submit, store `PassGuessAnswer(playerID, text)` and advance.
   - Auto-skip if timer hits 0 with empty text.
3. **`.guessing`** — answers shuffled. For each answer (sequentially):
   - Card shows the answer text in big.
   - Below, an avatar grid of all players. Each player **whose turn it is** taps the player they think wrote it. In single-device, voting is sequential (pass the phone for each guesser).
   - Stores `PassGuessVote(answerID, voterID, guessedPlayerID)`.
4. **`.reveal`** — Card-by-card flip animation reveals the actual writer + how many people guessed correctly. Scoring: +1 to each correct guesser, +2 to writer per **wrong** guess (people who got fooled).
5. **`.leaderboard`** — sorted total scores across all rounds completed so far. "Next Round" or "Finish".

### Archived rounds
Each completed round is added to `archivedRounds: [PassGuessArchivedRound]` so a history sheet can show all questions/answers/guesses from earlier rounds.

### View model
`PassGuessRoundState` lives inside `GameSession.passGuessState`. Updated via `AppViewModel.updateSession(...)`.

### Stars
Win (highest total) = 5★, participation = 2★.
