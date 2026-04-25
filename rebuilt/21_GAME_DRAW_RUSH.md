# 21 — Game: Draw & Rush

**Premium:** Yes.  **Modes:** Single, Multi.  **Players:** 2–12.  **Round:** 100s default.

## Concept
One player gets a secret concept (e.g. "Rocket"). They draw it on the screen. Everyone else races to guess. First correct guess wins the round. Drawer earns points based on how fast someone guessed.

## Setup — `DrawRushSetupView`
- **Concept pack** picker: Easy / Normal / Hard / Random.
- **Drawing time**: 30 / 60 (default) / 100s.
- **Judge mode** toggle (single-device only): If on, the drawer types whether each guess is correct (since everyone yells answers). If off, the drawer taps "End round" when they hear the right answer.
- Players list (single) or room (multi).

## Single-device session — `DrawRushSessionView`

### Flow
1. **Pass to drawer** — "Hand the phone to {name}".
2. **Concept reveal** — only drawer sees: "Draw: ROCKET" centered. "I'm Ready" → starts.
3. **Live drawing** — full-screen Canvas with finger drawing. Toolbar at top: undo, clear, color (5 colors), brush size (3 sizes), eraser. Timer at top right. The drawer's canvas is **hidden from the others initially**, then revealed after a 3-second "Get ready guessers!" intro.
4. **Guess** — others shout. Drawer (or anyone, judge-mode off) taps "Someone got it" → input the guesser name from a list of players → +points.
5. **Result** — show winning guesser, drawing thumbnail, points earned.

### Multi-device session — `DrawRushMultiDeviceSessionView`
- Drawer's canvas is **streamed** to other phones via realtime broadcast. Strokes are encoded as compressed `[CGPoint]` arrays sent in batches every ~150ms.
- Guessers tap a "Guess" button → text input → submitted via realtime. Drawer sees a live list of guesses; first correct match (case-insensitive) ends the round.
- Drawer cannot see guesses live in single-device mode; only in multi-device.

### Scoring
- Drawer: `100 - (timeUsed seconds)` (clamped 10–100). Bonus +20 if guessed in <20s.
- Guesser: 50 (1st correct), 25 (2nd correct), 10 (3rd correct).
- Stars: 5 win / 2 participation.

### Drawing model — `Models/DrawRushModels.swift`
- `Stroke { id, color (hex), width, points: [CGPoint] }`.
- `DrawingSnapshot { strokes: [Stroke], canvasSize: CGSize }`.
- Realtime envelope: `DrawingDelta { newStrokes: [Stroke], removedStrokeIDs: [UUID] }` (for undo).

### View model — `DrawRushViewModel`
Owns `currentDrawing: DrawingSnapshot`, `currentStroke: Stroke?`, `concept: String`, `phase`, `secondsRemaining`, `winner: PlayerProfile?`.
