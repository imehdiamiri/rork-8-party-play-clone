# 13 — Game: Imposter

**Premium:** No.  **Modes:** Single-device, Multi-device, Team.  **Players:** 4–30.

## Routing (special)
Imposter does **not** use the shared `GameDetailView`. The home grid pushes:
1. `ImposterStyleSelectionView` — pick **Discussion Mode** or **Clue Mode**.
2. `ImposterGameDetailView` — pick mode (single/multi/team), category pack, rounds, discussion duration.
3. Active session: `ImposterSessionView`.

## Style selection (`ImposterStyleSelectionView`)
Two tappable cards stacked vertically:
- **Discussion Mode** — `bubble.left.and.bubble.right.fill` orange. "Talk together and find the Imposter." 3 bullets: Free discussion, Timed conversation, Then voting.
- **Clue Mode** — `magnifyingglass.circle.fill` purple. "Give clues one by one." 3 bullets: Turn-based clues, No discussion, Then voting.

Each card: SurfaceCard with accentColor 12% bg + tint border.

## Game Detail (`ImposterGameDetailView`)
- Hero card identical to the shared style.
- Mode picker (single/multi/team). Multi & team route to `CasualCreateRoomView(game: .imposter, mode:)`.
- **Category pack** picker — segmented 3-cols grid: Animals 🐯, Food 🍕, Places 🌍, Jobs 👮, Movies 🎬, Random 🎲. Selected card has 2pt blue stroke and 18% blue bg.
- Rounds: 1 / 3 / 5.
- Discussion duration (only for Discussion mode): 30 / 60 / 90 / 120s.
- Players list (single/team) min 4.
- Start button.

## Session — `ImposterSessionView`

### Roles
At round start the engine secretly picks one player as the Imposter. Everyone else sees the same secret word from the chosen pack. The imposter sees a placeholder "?" and knows they are the imposter.

### Phases (`ImposterPhase`)
1. **`.roleReveal`** — pass-the-phone in single-device. Each player taps "I'm Ready" → sees their card (eye icon, secret word in big bold or "You are the Imposter") → "Hide" → next player. Multi-device: each player sees their own card on their own phone simultaneously.
2. **`.ready`** — confirmation that all `revealedPlayerIDs == players`. "Start Discussion" / "Start Clues" button.
3. **`.discussion`** — Discussion mode only. Big countdown (mm:ss). Free talk. Auto-advances when timer hits 0 or host taps "End Early".
4. **`.clueGiving`** — Clue mode only. Show current player name + 1-line text input "Your clue (one phrase)". Submit → next player. Cycles through `players.indices`.
5. **`.voting`** — Each player votes for who they think the imposter is. In single-device, pass-the-phone with hidden votes. In multi/team, simultaneous tap on phones. Vote tallies displayed only after all submitted.
6. **`.result`** — Reveal imposter. If majority correct → crew wins. Imposter still wins if they correctly **guess the secret word** when given a chance ("As the imposter, what was the word?" 3 chances). Animations: confetti for crew win (use `LinearGradient` particle simulation or `.symbolEffect(.bounce)` on multiple icons), red dim for imposter win.

### State
`ImposterRoundState` (file 04). Stored inside `GameSession.passGuessState? || imposterRoundState?` — actually a dedicated field; see `AppViewModel.swift` for the precise property. Realtime channels broadcast `state_changed` with `ImposterRoundState` snapshots.

### Team mode
Two teams. The imposter is randomly assigned to either team. Team scores tracked. After each round, the role rotates: a new imposter from the **opposite** team is picked.

### Scoring
- Crew wins: each non-imposter +50 points.
- Imposter wins: imposter +100 points.
- Imposter survives but loses (correct vote) but still guesses the word: imposter +75 points.
- Stars awarded per `RewardPolicy(gameKey: "imposter", starsForWin: 5, starsForParticipation: 1)`.
