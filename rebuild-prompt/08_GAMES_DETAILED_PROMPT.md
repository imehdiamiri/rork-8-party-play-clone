# 8PartyPlay — Complete Games Build Prompt (Exhaustive UI/UX Spec)

This document describes **every game** in 8PartyPlay in full. For each game it lists every screen, every button, every field, every timer, every phase, every animation, every haptic, and every scoring rule. Nothing is skipped.

Use this alongside the other prompts:
- `PROMPT.md` — the whole app overview.
- `MULTI_DEVICE_PROMPT.md` — realtime rooms & multi-device sync.
- `APP_EVERYTHING_ELSE_PROMPT.md` — tools, wallet, friends, AI generator, etc.
- `DESIGN_SYSTEM_PROMPT.md` — full design system.
- `FIREBASE_SETUP_PROMPT.md` — Firebase config and Cloud Functions.

**Stack:** Swift + SwiftUI (iOS 18+), Firebase backend (Firestore, Auth, Functions, Storage, FCM).

**NO XP system.** Do not implement XP, levels, level curves, or level-up animations anywhere in the app. Track only: `matchesPlayed`, `wins`, `stars`.

---

## 0. Global Rules That Apply to Every Game

### 0.1 Game list & order (home grid)

The home grid shows games in this exact order:

1. Reverse Singing (Free)
2. Guess the Seconds (Free)
3. Imposter (Free)
4. Memory Grid (Free)
5. Ten Tangle (Premium)
6. Memory Path (Premium)
7. Pass & Guess (Premium)
8. Tap in Order (Premium)
9. Color Trap (Premium)
10. Draw & Rush (Premium)
11. Truth & Dare / Spin the Bottle (Free)

Free games show at the top. Premium games appear with a **transparent lock badge overlaid on their card** so the user clearly sees they are locked until subscription.

### 0.2 Modes per game

Three possible modes:
- **Single Device (1 Phone)** — pass the phone around.
- **Multi Device (Multi Phone)** — each player on their own phone, realtime synced rooms.
- **Team Mode** — two teams, shared board/answers.

Each game supports only the modes listed in its section. Everything else is forbidden.

### 0.3 Shared setup building blocks

Every setup screen is built from reusable cards:

- **How-To-Play button** (blue filled card). Opens a bottom sheet with detents `medium` + `large`, drag indicator visible, content scrolls (not resizes). Inside: numbered blue circle list of localized rules for that game.
- **Players card** (green theme, icon `person.2.fill`). Plus/minus circle buttons, animated number (numericText transition). Text field per player (`Player 1`, `Player 2`, …) with a colored avatar bubble. Horizontal chip row of offline friends — tap a friend to insert them into the first empty slot (else appended up to max). Each player index maps to a fixed color from a 12-color palette `[blue, green, orange, purple, pink, cyan, mint, yellow, red, indigo, teal, brown]`.
- **Rounds card** (orange, icon `repeat`). Plus/minus stepper, default range `1...10`.
- **Timer card** (cyan). Plus/minus stepper with configurable step (sec). Suffix `s`.
- **Mode / Difficulty / Variant cards** — horizontal chip rows or tile grids, single-select, selected state shows accent-tinted background + checkmark.
- **Start button** (blue filled). Full-width rounded. Optional one-line subtitle under label like `{rounds} rounds · {playerCount} players`. Plays a round-start sound on tap. Disabled until input is valid.

### 0.4 Name validation (every setup)

- Trim every name. Blank names become `Player N`.
- If two non-blank names compare equal case-insensitively → alert:
  - Title: **Duplicate Names**
  - Body: **Two or more players have the same name. Please use unique names for each player.**

### 0.5 Shared gameplay components

- **Pass-the-phone view** — `hand.raised.fill` 48pt icon, "Pass the phone to" label, the next player's name highlighted in their color (scale 1.2 with spring), optional subtitle, one big button. Soft haptic when name changes.
- **Current-turn pill** — a green capsule with a pulsing dot + player name. Used as a header throughout all games.
- **First-time hint overlay** — one-time dismissible banner per game keyed by `UserDefaults` (`hint_seen_{gameId}`). Contains an SF icon, a title, a short tip, and an accent color.
- **Result actions bar** (multi-device) — `Rematch` (vote-based, disabled if any opponent has exited the room) + `Exit`. Shows each player's status (online / reconnecting / exited). Host prompts rematch; other players get an auto-prompt.
- **Background** — dark mode only, `AppBackgroundView` (soft vertical gradient).
- **Feedback** — every tap does a light haptic; every phase transition does a medium haptic; every correct answer plays a success sound + success haptic; every wrong answer plays an error buzz; winners get a victory fanfare + confetti.

### 0.6 Every game supports

- A How-To-Play sheet reachable from setup **and** during play.
- A Rematch (Play Again) button on the results screen that restarts with the same players.
- VoiceOver labels on every control, Dynamic Type, reduce-motion alternatives.
- A final leaderboard screen with confetti + `Play Again` / `Exit` buttons.
- Unfinished multi-device sessions recoverable if the app is killed mid-game.

**Exception:** Reverse Singing has no setup, no rounds, no scoring, and no final leaderboard — it is a free-form 2-player audio toy with a persistent history list instead. None of the rules above apply to it except How-To-Play.

---

## 1. Reverse Singing — Free · Single Device · 2 players

SF symbol `backward.fill`. Accents: pink (Player 1), blue (Player 2), green (result).

This game skips the standard setup — tapping the card goes straight into a 2-player session. The rest of the app calls this a "Quick Play" flow.

### Session screen

A scrollable screen with two cards and a history card.

#### Player 1 card (the "original" singer)

- Header: "Player 1" · subtitle "record anything you want".
- Status pill (right): **Active** (green) when it's Player 1's turn, otherwise not shown.
- Waveform strip (10 capsules animating on input level) + duration text `0.0s`.
- Buttons:
  - **Record** (pink, `mic.fill`) → starts `AVAudioRecorder`, AAC 44.1kHz mono high quality, cached `.m4a`. While recording the button becomes red, pulsing `stop.fill`, and shows `{Xs} / 60s`. Auto-stops at 60s.
  - **Play** (circle, `play.fill`) → plays the original recording.
  - **Play Reverse** (blue square, `backward.fill`) → plays the reversed copy.
  - **Slow** (circle, `tortoise.fill`) → plays reversed at 0.5× rate.
- On stop, the app creates a reversed `.caf` copy (PCM reversed per channel) and advances the active step to Player 2.

#### Player 2 card (the "mimic" singer)

- Header: "Player 2" · subtitle "try to copy reversed".
- Status pill: **Active** (green) when it's P2's turn, otherwise **Waiting** (orange).
- Helper: "Listen and record the mimic." (hidden once a result exists).
- Buttons:
  - **Record Mimic** (pink) — same recording rules as above; appends a result entry to history.
  - **Play** — plays P2's raw recording.
  - **Result** (green, `sparkles`) — plays P2's reversed audio (falls back to P1 reversed if P2 is missing).
  - **Share** (circle, `square.and.arrow.up`) — opens a confirmation dialog:
    - **Share Player 2 Raw** (disabled if no P2 recording).
    - **Share Result** (disabled if no result file).
    - **Cancel.**
    Selecting one presents a share sheet with that audio URL.

#### History card

- Header: "History" · "Last 20 only" · `Open` button (bordered blue).
- Shows the latest entry inline with `Mimic` (pink), `Result` (blue), and share buttons.
- `Open` presents a bottom sheet with detents `medium` + `large` listing all history entries (capped at 20). Older files are deleted from caches. History persists in `UserDefaults` under key `reverse_singing_history`.

### Errors & edge cases

- Microphone permission denied / undetermined → alert "Microphone Access Needed".
- App backgrounded → auto stops any active recording.
- Audio session interruption `began` → stops recording and sets an inline error: "Recording interrupted — tap Record to resume when ready."
- Route change (headphones unplugged) → stops recording.
- Any audio error → alert "Audio Error".

No scoring, no leaderboard.

---

## 2. Guess the Seconds — Free · Single Device · 2–30 players

SF symbol `stopwatch.fill`. Accent blue (primary), red (stop), plus green/yellow/red accuracy bands.

### Setup

Uses the generic single-device setup:
- How-To-Play.
- Players card (2–30, initial 4).
- **Rounds card, range `1...3`** (special — smaller than the default).
- Start button (subtitle `{rounds} rounds · {n} players`).

### Session

First-time hint: **"Guess the Seconds / Pick a target time, hit Start, then Stop as close to it as you can — no peeking at the clock."**

Layout (scrollable):

#### Header card
- Current-turn pill: `Now {player}`.
- Round progress: `Round N / roundsPerPlayer`.
- Status pill on the right:
  - `Running` (blue, `timer`)
  - `Finished` (green, `checkmark.circle.fill`)
  - `Ready` (secondary)

#### Last-result banner (after the first completed turn)
- Flag icon tinted to the band below.
- `{player} • Round N`
- Status pill:
  - diff == 0 → **Perfect!** (green, `target`)
  - < 1s → **Close** (blue, `scope`)
  - ≤ 2s → **Okay** (yellow)
  - > 2s → **Far** (red)
- Three metrics: `Target`, `Stopped`, `Diff` — all formatted `%.2f`.

#### Control card
- Section title "Target Time" — "Choose the target for this round." / "This round target is locked for all players."
- Stepper: 60×60 blue `minus` / `plus` circles, huge digital display (shows `•••••` while running), press-and-hold auto-repeat (350ms delay, 90ms cadence).
- Range **1…60 seconds**, integer step. Only the **first player of each round** sets the target — after that it locks for all other players in that round.
- Buttons:
  - **Start** (blue, `play.fill`) — disabled while running or finished. Locks target. Plays timer-start sound.
  - **Stop** (red, `stop.fill`) — disabled unless running. Records a `TurnResult(target, actual, diff)`. Plays timer-stop + success/error based on band. After the final turn, plays game-end after 400ms.
- Haptics: success on every completed turn, selection when running toggles.

#### Score table card
- Header row: `Time` column + `R1`, `R2`, …, `Total`.
- One row per player. Current player highlighted blue. Each cell tinted to its accuracy band. Total column = sum of `|target − actual|` across rounds.

#### Final results card (when all turns done)
- Title "Final Results" · "Lowest total difference wins."
- Winner crown pill yellow.
- Ranked list with `#1`, `Avg {diff}`, total-difference (green for #1).

### Scoring
- `difference = |target − actualStopTime|`, rounded to 2 decimals.
- **Total = sum of per-round differences. Lowest wins.**
- Tie-break: `playerName.localizedCaseInsensitiveCompare`.

---

## 3. Imposter — Free · Single Device · 4–30 players

SF symbol `eye.fill`. Two sub-styles: **Discussion** (orange, `bubble.left.and.bubble.right.fill`) or **Clue** (purple, `magnifyingglass.circle.fill`).

### Style selection screen
Shown first after tapping the game card. Title "Imposter" · "Select Mode". Two big tiles (staggered entrance 0.12s):
- **Discussion Mode** — "Talk together and find the Imposter" — "Free discussion · Timed conversation · Then voting".
- **Clue Mode** — "Give clues one by one" — "Turn-based clues · No discussion · Then voting".
Tap → spring select (0.3 / bounce 0.15), 0.35s delay, then push to the game detail.

### Game detail screen
Hero gradient card (accent → indigo) with the game symbol. "Choose mode" section (Imposter only has Single Device, so one tile). "Instructions" — a 4-step numbered list that depends on style:
- **Discussion:** (1) Each player secretly sees their role — one is the Imposter. (2) A secret word is revealed to everyone except the Imposter. (3) Discuss freely within the time limit to find the Imposter. (4) Vote on who you think the Imposter is. Majority wins!
- **Clue:** (1) Each player secretly sees their role — one is the Imposter. (2) A secret word is revealed to everyone except the Imposter. (3) Take turns giving a one-word clue about the secret word. (4) After all clues, vote on who you think the Imposter is.

### Setup screen

- How-To-Play.
- Players card: min 4, max 30, initial 4.
- Rounds card: default **3**, range `1...10`.
- **Discussion Time timer** (shown only if Discussion mode): icon `bubble.left.and.bubble.right.fill`, default **60s**, range **10…300s**, step 10.
- **Mode card** — two tiles side-by-side, Discussion (orange) / Clue (purple). Re-selectable here too.
- **Category card** — horizontal chips (default **Random**):
  - `Animals`, `Food & Drinks`, `Places`, `Jobs`, `Movies`, `Random`.
  - Each pack has 12 words. Lists:
    - **Animals:** Lion, Eagle, Dolphin, Elephant, Penguin, Tiger, Shark, Owl, Wolf, Panda, Giraffe, Crocodile.
    - **Food & Drinks:** Pizza, Sushi, Burger, Pasta, Taco, Ice Cream, Steak, Chocolate, Pancake, Salad, Soup, Sandwich.
    - **Places:** Paris, Tokyo, New York, Beach, Mountain, Desert, Library, Hospital, Airport, Museum, Stadium, Castle.
    - **Jobs:** Doctor, Pilot, Chef, Teacher, Firefighter, Astronaut, Detective, Artist, Engineer, Nurse, Lawyer, Farmer.
    - **Movies:** Titanic, Avatar, Batman, Frozen, Inception, Jaws, Matrix, Shrek, Gladiator, Alien, Rocky, Joker.
    - **Random:** Rainbow, Guitar, Volcano, Diamond, Tornado, Rocket, Camera, Mirror, Compass, Candle, Treasure, Shadow.
- Start button subtitle: `{rounds} rounds · {n} players`.

### Session

Each round header shows "Round N of {rounds}", mode title, and a status pill per phase:
- **Roles** (`eye.fill`) / **Ready** (`checkmark.circle.fill`) / **Discuss** (`bubble.left.and.bubble.right.fill`) / **Clues** (`magnifyingglass`) / **Vote** (`hand.raised.fill`) / **Result** (`trophy.fill`).

#### Phase — Role Reveal (per player, sequentially)
- `eye.slash.fill` 44pt, "Pass the phone to {name}".
- Button **Reveal My Role** (soft haptic).
- After reveal:
  - **Imposter** — red `theatermasks.fill` 48pt, "You are the Imposter!", "Blend in. Don't get caught."
  - **Others** — green `checkmark.shield.fill` 48pt, "The secret word is:" + the word in a style-accent pill.
- Button **Got it** → next player. When all done → Ready phase.

#### Phase — Ready
- `person.3.fill` 40pt accent.
- "Everyone has seen their role."
- Subtitle:
  - Discussion: "Get ready for {seconds} seconds of discussion!"
  - Clue: "Get ready to give clues one by one!"
- Button **Start** — rigid haptic. Discussion starts a 1s countdown from `discussionDuration`. Clue mode skips to clue phase.

#### Phase — Discussion (Discussion mode only)
- Big countdown `{seconds}` (64pt rounded bold monospaced). Red when ≤ 10s, white otherwise. Subtitle "seconds remaining".
- Progress bar, tinted red ≤ 10s else accent.
- Player list card with avatar bubbles.
- Button **Skip to Voting** (secondary) — cancels timer, goes to voting.
- Auto-transitions to voting at 0.

#### Phase — Clue Giving (Clue mode only)
- Turn label "Turn N of {players}". `text.bubble.fill` 36pt accent. Current-turn pill `Now {player}`.
- Instruction: **Give a ONE-WORD clue about the secret word**.
- TextField (multiline centered), placeholder "Your clue…".
- Button **Submit Clue** — disabled if blank. Trims + truncates to 30 chars. Adds a clue, advances to next player.
- "Clues Given" card below accumulates avatar+name+clue rows.

#### Phase — Voting
- Per voter (round-robin): `hand.raised.fill` 36pt red, "{voter}'s Vote — Who do you think is the Imposter?".
- Suspect list (excludes self): avatar + name. Selected row highlights with accent (0.12 opacity) + `checkmark.circle.fill`.
- Button **Confirm Vote** — disabled until selected. On vote, appends to votes. When `votes.count == players.count` → Result.
- "Clues Recap" card visible during voting in Clue mode.

#### Phase — Round Result
- Big outcome icon:
  - Imposter caught (most-voted == imposter) → green `checkmark.circle.fill`, "Imposter Caught!"
  - Otherwise → red `xmark.circle.fill`, "Imposter Wins!"
- "The Imposter was {name}" + "The secret word was {word}".
- **Vote Results card** — each player with avatar, name (red if imposter), "{n} votes", pill "Imposter" red for the imposter.
- **Scoring card** — three rows:
  - Green `checkmark.circle.fill` — "Voted for the Imposter correctly: +100 pts"
  - Red `xmark.circle.fill` — "Imposter survives the vote: +150 pts to Imposter"
  - Gray `minus.circle.fill` — "Wrong vote: 0 pts"
- Button **Next Round** or **See Final Results** (final plays game-end).

#### Final results
- `trophy.fill` 48pt yellow. "Game Over!"
- Ranked list `#N` + avatar + name (player color) + `{score} pts` (yellow for #1).
- Button **Play Again** — resets scores/round.

### Scoring
- Imposter caught → every non-imposter who voted correctly gets **+100**.
- Imposter survives → imposter gets **+150**; others 0.
- Wrong vote → 0.

---

## 4. Memory Grid — Free · Single / Multi / Team · 1–30 players

SF `square.grid.3x3.fill`. Accent cyan.

### Setup
- How-To-Play.
- Players card (1–30, initial 2).
- **Board Size card** (cyan chips):
  - `3×4` — 6 pairs (**default**)
  - `4×4` — 8 pairs
  - `4×5` — 10 pairs
  - `5×6` — 15 pairs
  - `6×6` — 18 pairs
- Start button subtitle: `{size} · {pairCount} pairs · {n} players`.

### Session (single device)

First-time hint: **"Flip two tiles at a time. Match every pair as fast as you can."**

Phases: `ready → playing → playerComplete → results`.

#### Ready
- 52pt cyan `square.grid.3x3.fill` in a 100×100 cyan.14 bg square.
- Multi-player: current-turn pill + "Your turn! Get ready to memorize."
- Solo: title "Memory Grid" + "Find all matching pairs!"
- Stat bubbles: Grid, Pairs, `Player i/total`.
- **Start** — round-start sound, → playing.

#### Playing
- Header: current player pill + "{matched}/{total} pairs". Right: orange `hand.tap.fill` + move count, cyan `timer` + elapsed.
- Progress bar: cyan → blue gradient, spring animated.
- Grid: `LazyVGrid` of square tiles (GeometryReader for exact square sizing), spacing 8.
- Tile (`MemoryTileView`):
  - Front: colored by a 10-color palette cycled by index `[cyan, pink, orange, green, purple, yellow, mint, red, indigo, teal]`, with an SF symbol.
  - Back: dark blue gradient with a glowing cyan `?`.
  - Flip: 180° Y-axis rotation, spring 0.45/bounce 0.15, soft haptic.
  - Matched tiles shrink to scale 0.94, opacity 0.55.
- On all matched: records time, plays victory + success.

#### Player Complete
- Pass-the-phone view, accent cyan, subtitle "Make sure no one else is looking at the tiles!", button "I'm Ready" → next ready.

#### Results
- Yellow bouncing `trophy.fill` 44pt. Title "Final Rankings" (multi) / "Complete!" (solo).
- Rows sorted by **time ascending**: rank circle (yellow #1), name (player color), "{seconds} seconds", crown for #1.
- **Play Again** primary.

### Multi Device
- Extra "Your Turn! Start" card with `gridSize.title / Grid`, `pairCount / Pairs`, `Player n`.
- While other players are playing, show a **spectator view** of their board in black-and-white (`saturation(0)`), updated from a broadcast snapshot every 0.7s (tiles, matchedPairs, moveCount, elapsedSeconds).
- On complete, submit `(elapsedSeconds, moveCount)` to the room. Final ranked list + multiplayer result actions bar.

### Team Mode
- Two teams alternate picks on a shared board. Each match = 1 point for the current team. Final: highest team score wins.

### Scoring
- Sort ascending by time. Ties by move count.

---

## 5. Ten Tangle — Premium · Single Device · 3–11 players

SF `theatermasks.fill`. Accent purple.

### Setup
Generic single-device setup. `totalRounds = players.count` (everyone is the guesser exactly once). No custom fields beyond the generic (players + how-to-play + start).

### Session

Phases: `guesserAnnounce → passToPlayer(i) → showNumber(i) → scenarioReveal → acting → guesserGuessing → roundReveal → scoreboard → finalResults`.

`maxNumber = players.count − 1` (every non-guesser gets a unique number 1…max).

#### Guesser Announce
- "Round N / total" badge.
- 🎯 64pt emoji. "Guesser This Round".
- Current-turn pill (scale 1.2) for guesser.
- Instruction "Look away while others get their secret numbers!"
- Button **Ready — Start Passing** (blue) → first pass.

#### Pass To Player (i)
- Pass-the-phone view colored by that player's palette color.
- Subtitle "Make sure the guesser isn't looking!"
- Button **"I'm {name} — Show My Number"**.

#### Show Number (i)
- Tertiary "Your Number", huge 96pt rounded heavy number with reveal scale animation (0.3 → 1.0).
- Color by value: bottom third red, middle third yellow, top third green.
- Legend underneath: `1` (red) "Disaster 😬" · divider · `max` (green) "Perfect 😍".
- Button **Got it!** (green) → next pass, or Scenario Reveal when done.

#### Scenario Reveal
- Round badge. 📢 56pt. "The Scenario".
- Scenario text (24pt rounded bold) fades in with offset after 300ms.
- Instruction "Everyone react based on your number!\n1 = Disaster 😬 → {max} = Perfect 😍".
- Button **Start Acting!** (purple) → Acting.

Scenarios pool: 30 preset lines (flight cancelled, ex at party, spicy food, etc.), picked without repeats via a `usedScenarioIndices` set.

#### Acting
- 🎭 emoji. "Act It Out!" (28pt rounded bold).
- Scenario card (with the full text, 22pt).
- "Each player acts their reaction. The guesser watches and observes!"
- Scale pills: `1 = 😬` red, (middle = 😐 yellow if max ≥ 3), `{max} = 😍` green.
- Button **Done Acting — Time to Guess** (indigo) → Guessing.

#### Guesser Guessing
- Round badge + 🔮 + current-turn pill (guesser).
- Scroll list — one row per non-guesser:
  - Avatar (player color) + name (player color).
  - Large `?` placeholder, becomes the chosen number.
  - Horizontal row of buttons `1…maxNumber` (colored by number), tap to set guess (plays tap sound).
- Button **Submit Guesses** (blue) — disabled until all guesses set.

#### Round Reveal
- Title "Results". For each player:
  - Avatar + name (player color) + "Real: {n}" / "Guess: {n}" (colored by value) + green check or red xmark.
- Summary: "{guesser} scored +{correctCount}" (green, singular "point" / plural "points").
- Button **Scoreboard** (purple).

#### Scoreboard
- Ordered list: 🥇🥈🥉, then "N.", avatar, name, score (orange for #1), "pt"/"pts".
- Button label = **Final Results** (orange, last round) or **Next Round** (blue).

#### Final Results
- 🏆 64pt. "Game Over!" (28pt heavy rounded).
- Winner name (32pt heavy, player color) + "wins with X points!"
- Full scoreboard.
- Button **Play Again** (green).

### Scoring
- Guesser gets **+1 per correct guess** per round (`guessed == actual`).
- Non-guessers don't score.

---

## 6. Memory Path — Premium · Single / Multi / Team · 2–30 players

SF `map.fill`. Accent teal.

### Setup
- How-To-Play.
- Players card (min 2).
- **Game Mode card** (teal):
  - `Time Race` (`timer`) "Race to complete the path fastest" — **default**.
  - `Turn-Based` (`arrow.trianglehead.2.clockwise`) "Take turns, wrong move passes control".
- **Grid Size card** chips:
  - `easy 5×5` green
  - `medium 6×6` orange — **default**
  - `hard 7×7` red
  - `expert 8×8` purple
- **Path Length card**:
  - Three segmented buttons Easy/Medium/Hard (green/orange/red) pre-filling the stepper to 6 / 10 / 14 / 18 (per difficulty).
  - Below, minus/plus circles + large teal count ("{n} steps" subtitle), numericText transition.
  - Range: `max(3, gridSize−1) … gridSize²/2`.
- Start button subtitle: `{size}×{size} · {steps} steps · {mode}`.

### Session

First-time hint: **"Find the hidden path from Start to End. One wrong tap and you restart."**

Phases: `setup/countdown → playing (+hintActive) → passDevice → turnSwitch → finished`.

#### Countdown / Setup
- 56pt teal `road.lanes` pulsing. "Memory Path" title. "{grid}×{grid} · {mode}" subtitle. "Get Ready…" teal title with scale/opacity transition.

#### Playing
- Top bar:
  - Active player (player color) + mode label (icon + title) + "{stepsFound}/{stepsToFind}" teal.
  - Right: timer `{m:ss}`, hint countdown `{X}s` (orange when hint active).
- Grid — spacing 6 / 5 / 4 depending on size. Each tile `MemoryPathTileView` state:
  - `.hidden` — white 6% bg.
  - `.correct` — teal gradient, checkmark, intensifies with progress.
  - `.wrong` — red 50% + shake (−4 offset) + repeat spring.
  - `.hintRevealed` — orange dot.
  - `.start` — green + "Start" label.
  - `.end` — cyan + "End" label.
  - Correct tiles are disabled; shadow teal when correct.
- Progress bar teal → cyan, "Step X of Y".
- Button **Hint** (orange capsule, `eye.fill`) — disabled when already used, during a hint, or when the user hasn't unlocked hints. Reveals the next step as a short orange dot.
- Haptics: error on wrong, success on correct. Wrong tap resets path from step 0.

#### Pass Device
- Pass-the-phone view (teal), subtitle "Get ready for your turn!", button "I'm Ready".

#### Turn Switch
- 48pt rotating cyan `arrow.trianglehead.2.clockwise.rotate.90`. Multi-line status message.
- Button **Continue**.

#### Finished (results)
- Confetti (30 circles in yellow/teal/cyan/green/orange/pink/purple).
- Header card: `trophy.fill` 36pt yellow, winner name (player color), "Winner · Rank #N".
- Subtitle:
  - Time Race winner: "Completed in {time} · Score {score}".
  - Turn-Based winner: "Furthest: {p−1}/{length−2} steps · Score {score}".
- Leaderboard card with subtitle — "Sorted by rank, then fastest completion" (time race) or "Sorted by rank, progress, tries, and time" (turn-based).
- Stats card: Grid / Path / Mode. Team mode adds per-team hint usage.
- Buttons **Play Again** / **Exit**.

### Multi Device
- "Your Turn! Start" card, turn runs locally, broadcasts progress live.
- On complete, submit `(progress, attempts, completionTime, isFinished, score)` to the room. Final ranked list + multiplayer result actions bar.

### Scoring (multi)
```
completionBonus = finished ? 10000 : 0
progressScore   = progress * 100
efficiencyBonus = max(0, 40 − attempts*10)
timeBonus       = Int(max(0, 600 − completionTime*10))
score           = completionBonus + progressScore + efficiencyBonus + timeBonus
```
Sort by score desc; then by isFinished, progress, time, attempts.

---

## 7. Tap in Order — Premium · Single / Multi · 1–30 players

SF `number.square.fill`. Accent orange.

### Setup
- How-To-Play.
- Players card (initial 2).
- **Mode card** (orange) — two tiles (default Number Memory):
  - `Number Memory` — `number.square.fill` — "Memorize the numbers, then tap 1 → N in order".
  - `Pattern Memory` — `square.grid.3x3.fill` — "Memorize the pattern, then tap the correct tiles".
  - Each tile has a green "Fewest mistakes wins" badge.
- **Grid Size card** chips `4 / 5 / 6 / 7`. Default 4. Subtitle "{n*n} cells".
- **Tile Count card** (label "Numbers" or "Pattern Tiles") chips depending on grid size:
  - Grid 4 → `[4, 6, 8, 10]` (num) / `[3, 5, 7, 9]` (pattern). Defaults 6 / 5.
  - Grid 5 → `[6, 8, 10, 14]` / `[4, 7, 10, 13]`. Defaults 8 / 7.
  - Grid 6 → `[8, 12, 16, 22]` / `[6, 10, 14, 20]`. Defaults 12 / 10.
  - Grid 7 → `[10, 14, 20, 28]` / `[8, 14, 20, 28]`. Defaults 14 / 14.
  - Switching variant/grid clamps to the new default if the old choice isn't offered.
- Start button subtitle: `{variant} · {size}×{size} · {count} tiles`.

### Session

First-time hint: **"Memorize. Tap. — You have a few seconds to memorize. Fewer mistakes win — time is just for reference."**

Phases: `ready → playing (preview → active) → outcome → playerComplete → results`.

#### Ready
- 52pt orange variant icon. Current-turn pill or title.
- Green "Fewest mistakes wins" pill.
- Stat bubbles Grid / Tiles / Player.
- **Start** → random seed, begins preview.

#### Preview (inside Playing)
- Duration `max(4.0, 3.5 + tileCount * 0.35)` seconds.
- Number Memory: chosen cells show `1…N` in orange gradient. Others dim.
- Pattern Memory: chosen cells glow orange. Others dim.

#### Active (inside Playing)
- Header: player name (player color) + subtitle:
  - Number: "Next: {n} · {miss} mistakes".
  - Pattern: "Tap the correct tiles · {miss} mistakes".
- Stats row: red `xmark.circle.fill` + mistake count, green `checkmark.seal.fill` "{correct}/{total}", orange `eye.fill` preview-remaining or `timer` elapsed.
- Progress bar orange→pink.
- Board: `LazyVGrid` size×size, spacing 6. Tiles gradient-filled; correct → green checkmark / number; wrong pattern persists red xmark; wrong flash: red border 2.5, scale 0.92, spring.
- Disabled: during preview; already-tapped cells.
- Bottom **Give Up** (red bordered) — confirmation dialog "Give up your turn?" — Actions "Give Up" destructive / "Keep Playing" cancel. Message: "Your progress will be kept. Next player will continue." (multi) or "Your progress will be saved." (solo).

Number Memory caps mistakes at **3**; Pattern Memory has no hard cap.

#### Outcome (overlay, 1.8s)
- Full-screen blur material + bouncing 72pt icon:
  - Done → green `checkmark.seal.fill`.
  - Gave up → orange `flag.fill`.
- 40pt black title, subtitle "{miss} mistakes · {time}s".
- Auto advances.

#### Player Complete
- Pass-the-phone view (orange), subtitle "Pass the phone. Don't peek at the board!", button "I'm Ready".

#### Results
- `trophy.fill` yellow. Title "Final Rankings" or "Complete!".
- Sort: fewest mistakes, then fastest time.
- Rows: rank circle + name + "{correct}/{total} correct · {miss} miss · {time}s" + crown for #1 if finished.
- **Play Again**.

### Multi Device
- Spectator board preview desaturated (black-and-white) with the chosen cells still visible (plus numbers for Number Memory).
- On complete submit `(variant, elapsedSeconds, correct, total, miss, didFinish)`.

### Scoring
- Sort by `missTaps` asc, then `elapsedSeconds` asc. `didFinish` = all correct + not given up + not over max miss.

---

## 8. Color Trap — Premium · Single / Multi · 1–30 players

SF `paintpalette.fill`. Accent pink.

### Setup
- How-To-Play.
- Players card (initial 2).
- **Difficulty card** (pink) chips:
  - `Easy` — "Slower tiles · 20s" (duration 20, spawn 0.9s, tile life 1.9s).
  - `Medium` — "Faster tiles · 30s" (30 / 0.65 / 1.5) — **default**.
  - `Hard` — "Chaos · 45s" (45 / 0.45 / 1.15).
- Start button subtitle: `{difficulty} · {duration}s · {n} players`.

### Session

First-time hint: **"Tap every color EXCEPT the forbidden one. Three wrong taps and you're out."**

Phases: `ready → playing → playerComplete → results`.

Palette: `[red, blue, green, yellow, purple]`. `maxFails = 3`. 4 columns.

#### Ready
- 52pt pink `paintpalette.fill` in 100×100 bg. Current-turn pill or title.
- Forbidden color preview: 120×56 rounded rect with the color (+ shadow).
- Stat bubbles: Difficulty / Mode `{duration}s` / Lives `3`.
- **Start** → random seed, begins play.

Forbidden color for single device = `pickForbiddenColor(seed: session.id hash)`. Multi device uses the shared seed from the room.

#### Playing
- Header: player pill + hearts (`heart.fill` red, `heart.slash.fill` dimmed for used lives). Right: green hits badge, pink remaining time `{s.x}s`.
- Forbidden banner: yellow `exclamationmark.triangle.fill` + "Avoid" + 28×20 color swatch.
- Arena: black 15% rounded rect. Tiles fall from top (y = `timeAlive/lifetime * maxY`). Tap removes with scale-out/opacity fade.
  - Tap forbidden → `fails++`, lives−1.
  - Tap correct → `hits++`.
- Ends when duration elapses or fails ≥ 3 (eliminated).

#### Player Complete
- Pass-the-phone view (pink), subtitle "Pass the phone. Ready to dodge the forbidden color?", button "I'm Ready".

#### Results
- Sort by **score desc**.
- Rows: rank circle + name + "{hits} hits · {fails} miss[ · eliminated]" + score pink + crown for #1.
- **Play Again**.

### Multi Device
- Spectator arena desaturated with the first 8 spawns visible + forbidden banner.
- Submit `(hits, fails, survivalTime, eliminated)`.

### Scoring
```
score = hits * 10 + Int(survivalTime * 5) − fails * 15
(clamped to max(0, ...) in single device tally)
```

---

## 9. Pass & Guess — Premium · Single Device · 2–30 players

SF `text.bubble.fill`. Accents yellow + blue.

### Setup
- How-To-Play.
- Players card (initial 4).
- Rounds card — default **1**.
- **Answer Time** timer (`pencil.circle.fill`, cyan) — range **15…120s**, step 10.
- **Guess Time** timer (`eye.circle.fill`, cyan) — range **15…90s**, step 10.
- Start button subtitle: `{rounds} rounds · {n} players`.

### Session (dark mode forced)

A pass-phone privacy overlay presents itself automatically before **every** answering/guessing transition in single-device: big pass-phone card, subtitle "They'll write their answer privately." or "They'll guess who wrote this answer.", button "I'm Ready". After tap, focuses the input 100ms later.

Phases per round: `intro → answering → guessing → reveal → leaderboard`. Session phase `finished` shows final results.

#### Intro
- 48pt yellow `person.text.rectangle.fill`. "Round N / total". Subtitle: "Everyone writes a private answer first. No reveals until the end." (solo).
- **Choose a Question card**:
  - Two chips: `Predefined` / `Custom` (blue 18%).
  - Predefined: scrollable list (max 260pt high) of 22 questions (full list below) with radio circles. First item selected by default.
  - Custom: 4-line TextField "Write your custom question".
- Button **Start Round** — disabled until a question exists. Plays round-start.

**22 predefined questions** — use these exactly:
1. What is your most irrational fear?
2. What is the weirdest snack combo you would actually eat?
3. What would be your secret superpower in real life?
4. What is the most embarrassing song you know all the words to?
5. If you had to get a useless tattoo right now, what would it be?
6. What is one lie you would be terrible at keeping?
7. What is your fake luxury brand name?
8. What would your wrestling entrance name be?
9. What would you rename Monday to?
10. What is the pettiest reason you'd cancel plans?
11. What is your villain origin story?
12. If your laugh had a flavor, what would it be?
13. What is a fake excuse for being late that sounds real?
14. What would your autobiography be called?
15. What is the dumbest thing you'd fight a goose over?
16. What is your cursed startup idea?
17. What is your signature move in a pillow fight?
18. What is the most suspicious thing in your fridge right now?
19. If aliens landed today, what job would you pretend to have?
20. What is your most chaotic road trip role?
21. What tiny thing makes you feel powerful?
22. What would your signature perfume or cologne be named?

#### Answering
- Round badge `flag.fill` "Round N / total" + `person.2.fill` "{n} players".
- Question card: current-turn pill + "{answered}/{total} answered" caption. Question text title3 bold.
- Private Answer card: "No previous answers are shown." TextField (4 lines, multiline). Max **120 chars** (truncates). "{count}/120" counter.
- Button **Done & Pass** (solo) / **Submit Answer** (multi).

#### Guessing
- Round badge "Answer {i+1} of {total}" (solo) or "Votes {count}/{total}" (multi).
- Anonymous Answer card: caption "Anonymous Answer" + the text.
- Voter card: current voter's name (player color) + "Who wrote this?" + "Vote N/total".
- Candidate list — avatar + name. Tap in solo submits vote immediately + next privacy screen. Multi selects then tap **Submit Vote**.

#### Reveal
- Round badge + the question.
- "Reveal — Now everyone sees who wrote each answer."
- Per item: answer (title3 bold) + `person.fill` + author (yellow) + "{n} correct".
- Button **See Round Scores**.

#### Leaderboard
- Round badge "Round complete".
- "Leaderboard — Scores after round N of total" with ranked rows (gold/silver/bronze/blue rank circle), player-color names, bold score.
- Button **Next Round** or **Finish Game**.

#### Final Results
- 48pt yellow `trophy.fill` in 92×92 bg. "Final Results — Everything stays hidden until this screen."
- Leaderboard.
- **Accuracy card** — "Correct guesses per player" with "{correct}/{total}" and "{percent}%".
- **Hardest to Guess card** — purple `eye.slash.fill`, player with fewest correct guesses.
- **Full Reveal section** — per round: number, question, each answer + author (yellow) + "{correct} correct".
- **Play Again** → new session with same players.

### Scoring
- Correct guesser gets points; author scores when they fool others. Exact numbers are tracked in the view model and displayed as `player.score`. Highest total wins.

---

## 10. Draw & Rush — Premium · Single / Multi · 2–12 players

SF `pencil.and.scribble`. Accent cyan.

### Setup
- How-To-Play.
- **Concept Source card** (default Free Draw):
  - `Preset Concepts` (`text.book.closed.fill`) — "Drawer gets a secret word".
  - `Free Draw` (`sparkles`) — "Drawer picks their own idea".
- Players card (initial 3).
- Start button subtitle "Each player draws once · 60s per turn".

### Session (single device)

Phases: `turnIntro → drawerReveal → drawing → passForGuesses → guessing → drawerJudging → roundResults → finalLeaderboard`.

#### Turn Intro
- 56pt cyan `paintbrush.pointed.fill`. "Turn N of {players}" caption. Current-turn pill `Drawer {name}`.
- "Pass the phone to {name}." Button **{name} is Ready** (cyan).

#### Drawer Reveal
- Caption "Your secret concept" (preset) / "Free draw" (free).
- Big 42pt heavy concept word, or 28pt "Draw anything you want!".
- Free draw extra: "Only you know what it is. After guessing, you decide who got it right."
- Info row: orange `clock.fill` "60 seconds to draw" + "No words, no numbers, no letters."
- Button **Start Drawing** (cyan).

#### Drawing
- Header: timer `{X}s` pill (red ≤ 10s). Right: "Drawing" + concept / "Free draw" cyan.
- **DRCanvasView** — SwiftUI `Canvas`, white bg, 1:1 aspect, rounded 16. DragGesture captures `DRStroke(color, width, points)` with points normalized to 0…1.
- **DRBrushBar** — horizontal color strip of 10 swatches: white, red, orange, yellow, green, blue, purple, pink, brown, black (selected has cyan 3pt border). Width slider 2…18 (default 4).
- Bottom row — **Clear** (trash), **Undo** (`arrow.uturn.backward`), **Finish** (checkmark, cyan filled). All full-width.
- Preset concepts pool: 78 words (Pizza, Elephant, Guitar, Rainbow, Rocket, … Piano, Drum). Pick avoids recent reuse.
- Timer = 60s. Timeout or Finish advances to `passForGuesses`.

#### Pass For Guesses
- 56pt yellow `hand.raised.fill`. "Drawing complete!" — "Pass the phone around — each guesser types one answer."
- "First up: {name}".
- Button **Start Guessing** (yellow).

#### Guessing (one device)
- "Guess {i+1} of {total}". Current-turn pill `Now guessing {name}`.
- Read-only canvas preview.
- TextField "Type your guess" (word autocapitalize, no autocorrect).
- Button **Submit (locked after)** (yellow) — disabled if empty. Next guesser.

#### Drawer Judging
- 40pt cyan `hand.thumbsup.fill`. "{drawer}, judge the guesses".
- Preset: "Concept: {word}". "Tap ✓ for correct guesses and ✗ for wrong ones."
- Per answer (sorted by submittedAt): name + text + `DRJudgeRow` with ✗ red (40×40) and ✓ green. Selected fills solid.
- Button **Show Results** (cyan) — disabled until all judged.

#### Round Results
- Header: "The concept was {word}" (preset) / "Round complete — Judged by {drawer}" (free).
- Read-only canvas.
- **Answers card** ranked by submit time:
  - "#N" + player name + optional `Early` pill (yellow `bolt.fill`) if submitted during the drawing phase.
  - Answer text (green if correct, red if wrong).
  - Trailing: `+{points}` green or red `xmark.circle.fill`.
  - Border green/red, 2pt + higher opacity when early.
- **Standings card** — "{rank}. {name} {score}".
- Button **Next Drawer** or **Show Final Leaderboard** (cyan).

#### Final Leaderboard
- 48pt yellow `trophy.fill`. "Final Leaderboard".
- Rows with 🥇🥈🥉 / `#N`, name, score (yellow for #1, cyan rest).
- Buttons: **Restart** (orange) / **Continue** (cyan).
- Plain secondary **Exit** dismisses.

### Multi Device (`DrawRushMultiDeviceSessionView`)
- Drawer device: canvas + brush + Clear/Undo (**no Finish** — purely time-gated). Strokes broadcast live.
- Non-drawer devices: read-only canvas + text input. Submit ends their turn. After submitting: "Answer locked — waiting for round to end…" card.
- Submissions strip: one pill per guesser, checkmark when submitted.
- Only the drawer sees `drawerJudging`; others see a progress indicator "Waiting for {drawer} to judge…"
- Only the host advances in `roundResults` / `finalLeaderboard` (Next Drawer / Restart / Continue).
- Concept mode forced to `Preset` in multi.

### Scoring (`DrawRushScoring`)
- **Multi** — Correct guess during drawing, fastest correct → **+15**. Other correct answers → **+12**.
- **Single** — Any correct guess → **+10** (no early bonus since drawer judges after).
- Incorrect or un-judged → 0.
- Drawer always gets 0 per round.

---

## 11. Truth & Dare (Spin the Bottle) — Free · Single Device · 3–12 players

SF `arrow.triangle.2.circlepath`. Accent red.

### Setup
- How-To-Play.
- Players card (initial 4, range 3–12).
- **Vibe card** (red, `flame.fill`) — three tiles:
  - `Mild` — "Safe & friendly".
  - `Classic` — "Balanced fun" (**default**).
  - `Bold` — "Spicy & risky".
- Start button subtitle `{vibe} · {n} players`.

### Session

Phases: `idle → spinning → landed → choosing → prompt → done`.

#### Circle Screen (idle/spinning/landed/choosing)
- Header varies by phase:
  - idle: "Truth or Dare" / "Tap Spin to start the round".
  - spinning: "Spinning..." / "Where will it land?".
  - landed: "It's {name}!" / "Get ready to choose".
  - choosing: "{name}'s turn" / "Pick your fate".
  - Right pill: `flame.fill` + vibe title (red capsule).
- Selected-player banner (landed/choosing): ultraThinMaterial card, gradient avatar with initials, "SELECTED PLAYER" caption, player name (title3 heavy), `sparkles` icon.
- Player ring: players laid out on a circle at angle `anglePerPlayer * i − 90`. Selected player shows current-turn pill scale 1.05; others just name capsules.
- **Bottle image** — a real **vertical water-bottle PNG** (transparent background), cap on top, not a generic SF symbol. Sized 22% × 58% of the area. It rotates by `bottleAngle`. The bottle must show **two faces**: heads and tails — i.e. the image must look correct regardless of rotation. (The previous generic `waterbottle.fill` is wrong — always replace it with the uploaded transparent bottle asset.)
- Restart button (top right): circle material + `arrow.counterclockwise` — resets phase to idle and angle to 0.
- Tapping the circle when idle → spin.

#### Action area per phase
- idle: "Tap the bottle to spin".
- spinning: ProgressView + "Spinning..."
- landed: **Continue** (blue) → choosing.
- choosing: two choice buttons side by side:
  - **Truth** — blue gradient, `bubble.left.and.text.bubble.right.fill`.
  - **Dare** — red gradient, `flame.fill`.
  - Either → generate prompt, → prompt phase, round-start sound.

#### Spin logic
- Pick a random target player.
- Base rotations: `Int.random(10…14) * 360`.
- Jitter: `±anglePerPlayer * 0.25`.
- Animation: `.timingCurve(0.15, 0.45, 0.2, 1.0, duration: 8.0)`.
- After 8.05s → land on target, play bottle-land + player-picked sounds, phase → landed.

#### Prompt Screen
- Choice pill (icon + TITLE uppercase tracking 2) in the choice color.
- Player name title3.
- Huge 28pt rounded-bold prompt, line spacing 6, minimum scale 0.7.
- `Reroll · {n} left` pill — **2 rerolls per round**, picks a non-repeat prompt.
- Big green rounded background.
- Bottom **Done · Next Spin** (green) → completes round (resets prompt, rerolls=2, phase=idle), plays success.

#### Prompts
- Three decks × two categories × 20 each (`SpinBottleContent`): 20 truths/20 dares for Mild, 20/20 Classic, 20/20 Bold. Tracked per-session via `usedTruths` / `usedDares` sets; refilled when exhausted.

No scoring — freeform.

---

## 12. Coin — Head & Tail (part of Party Tools, not a standalone game)

This belongs to Party Tools but is described here for completeness:

- The coin flip tool flips between **Heads** and **Tails** with a true 50/50 random result.
- Heads and Tails use the two uploaded Rosh-8 PNGs (transparent backgrounds). Both sides render on their own rotations, and the final visible face matches the random result.

---

## 13. Cross-Cutting Edge Cases (apply to every game)

- Back button: standard `NavigationStack` pop. Team Setup additionally has a **Leave** confirmation.
- Active audio sessions and timers cleaned in `onDisappear`.
- Mid-game disconnect (multi-device): the multiplayer result actions bar reports "Exited" for that user; rematch disabled if anyone has exited.
- Duplicate names alert blocks Start.
- Scene `active` re-broadcasts spectator state.
- Each game writes settings into `AppViewModel.current{Game}Settings` before starting single-device mode.
- First-time hints keyed by `hint_seen_{gameId}` in UserDefaults.
- Haptics: `.selection` on turn changes, `.impact(.soft)` on taps, `.success` on complete, `.error` on wrong, `.rigid` on big confirmations.

---

## 14. Home Grid Cards

- Ordered by the list in §0.1.
- Each card shows the SF symbol + game name + short description.
- Free games appear first (Reverse Singing, Guess the Seconds, Imposter, Memory Grid, Truth & Dare).
- Premium games appear in a separate section below, each with a **transparent lock badge** overlayed on top-right so the user can clearly see which games are locked.
- Tapping a premium game while subscription is locked pushes to a `GameDetailView` that replaces the mode selection with an "Unlock with 8PartyPlay+" gradient card (bulletpoints: Unlock all premium / AI cards cost 1★ / Bonus Stars) that opens the paywall.
- Reverse Singing skips setup entirely and starts a 2-player session immediately.
- Imposter goes through its style-selection screen first, then the game detail, then the setup.
