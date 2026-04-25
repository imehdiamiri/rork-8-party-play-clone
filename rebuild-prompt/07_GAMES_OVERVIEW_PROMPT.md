# 8PartyPlay — Games Build Prompt (Summary)

> **This is a summary.** For the full exhaustive spec of every game (every screen, button, timer, phase, animation, scoring rule) use `GAMES_DETAILED_PROMPT.md`.

This document gives an overview of all 11 games. The app also has tools, cards, an AI generator, friends, wallet, and a multi-device system — covered in the other prompt files. **Stack: Swift + SwiftUI, Firebase backend.**

## Global Game Rules

- All games are offline-first for single-device mode. Each game follows: setup → play → result → optional rematch.
- **NO XP system.** Do not implement XP, levels, or level-up animations. Track only `matchesPlayed`, `wins`, and `stars`.
- Three possible modes (per game, see below):
  - **Single Device (1 Phone):** everyone plays on one phone, passing it around.
  - **Multi Device (Multi Phone):** each player uses their own phone, synced via Firestore realtime.
  - **Team Mode:** players split into 2 teams that compete.
- Setup screens share common building blocks: player count stepper, player name list (fillable from friends), duplicate-name validation, How-To-Play button, and a Start button disabled until valid.
- Every game shows a results screen with a leaderboard, plays a short celebration, and offers "Play Again" / "Back to Home".
- Dark mode only. Big tappable controls, native iOS feel, spring animations, haptics, and short SFX.
- Some games are free forever, some are premium (locked behind subscription/paywall). Locked games still appear in the home grid with a transparent lock badge.

## Game 1 — Reverse Singing (Free, Single Device, 2 players, Quick Play)

- Pass-the-phone game for **exactly 2 players**. Tapping the card skips setup entirely and launches the session immediately.
- Player 1 records a short voice clip (hum, sing, say a word). The app reverses it. Player 2 listens to the reversed clip and tries to mimic it out loud — the app then reverses Player 2's recording back, revealing whether it sounds like the original.
- Buttons: Record / Play / Play Reverse / Slow (0.5×) for Player 1; Record Mimic / Play / Result / Share for Player 2.
- Recording cap is **60 seconds**. No rounds, no voting, no scoring, no leaderboard, no rematch screen.
- A persistent History card stores the last **20 sessions** in `UserDefaults` (`reverse_singing_history`) so players can replay or share any past mimic/result.

## Game 2 — Guess the Seconds (Free, Single Device, 2–30 players)

- Pick a target time (e.g. 7s, 12s, 30s — configurable). Hide the clock. The active player taps START, counts in their head, taps STOP as close to the target as possible.
- Score = absolute difference from target in hundredths of a second. Lower is better.
- Multiple rounds per player; targets can rotate.
- Result screen: per-round table with target / actual / delta, and overall leaderboard sorted by total delta.

## Game 3 — Ten Tangle (Premium, Single Device, 3–11 players)

- Pass-the-phone bluffing game. Each round one player sees a secret number 1–10 and a scenario (e.g. "How spicy is your food?", "How clean is your room?").
- They must act / answer **at the intensity of that number** without saying it. Others rank the performance 1–10.
- Guesser(s) try to land on the exact number. Points for being close. Bluffer scores when others guess wrong.

## Game 4 — Imposter (Free, Single Device, 4–30 players)

- Classic hidden-role game. Everyone sees a secret word except the Imposter, who only knows the category.
- Two sub-styles (pick before start):
  - **Discussion Mode:** timed free-form discussion (default 60s), then everyone votes who the Imposter is.
  - **Clue Mode:** turn-based — each player gives one short clue in order. No free discussion. Then vote.
- Phases per round: Role Reveal (tap to reveal, each player privately) → Ready Check → Discussion/Clues → Voting → Result.
- Categories: Animals, Food & Drinks, Places, Jobs, Movies, Random. 3 default rounds, configurable 1–10.
- Imposter wins if not voted out or if they guess the word after being caught.

## Game 5 — Memory Grid (Free, 1–30 players, Single / Multi / Team)

- Classic memory match. Grid of face-down tiles with pairs of symbols/colors. Players flip two at a time, keep matches, fastest solve wins.
- Grid sizes: 4x4 small, 4x5 medium, 6x6 large.
- **Single Device:** each player takes a turn solving the same deck, time + move count tracked per player.
- **Multi Device:** everyone solves the same board at the same time, live spectator view shows opponent progress.
- **Team Mode:** two teams alternate picks on one shared board, match = team point.
- Result: sorted by time then by moves. Confetti for winner.

## Game 6 — Memory Path (Premium, 2–30 players, Single / Multi / Team)

- A grid has a hidden path from start to end. Players tap tiles one at a time. Correct = stays lit. Wrong = buzz, reset to start.
- Difficulty (easy/medium/hard) controls grid size (5x5 / 6x6 / 7x7) and path length (4–10 steps).
- Modes:
  - **Time Race:** fastest to reach the end wins.
  - **Fewest Attempts:** lowest number of wrong taps wins.
- Multi-device and team variants sync the same path and track per-player progress live.

## Game 7 — Tap in Order (Premium, 1–30 players, Single / Multi)

- A grid shows numbered tiles (1…N) shuffled. Tap them in ascending order as fast as possible.
- Same board is shared across all players so scores are comparable.
- Difficulty = grid size / number count (e.g. 9 / 16 / 25 / 36).
- Single Device: pass phone, each player takes a turn on the same shuffled board.
- Multi Device: everyone races on their own phone with an identical board, live progress bars for opponents.
- Result sorted by completion time; penalty added for wrong taps.

## Game 8 — Color Trap (Premium, 1–30 players, Single / Multi)

- Grid of colored tiles. A banner shows the **forbidden color** (e.g. "Don't tap RED").
- Tap every tile **except** the forbidden one as fast as possible. Three wrong taps = you're out for the round.
- Forbidden color changes between rounds. Multi-device races everyone simultaneously.
- Score = tiles cleared − wrong tap penalties. Leaderboard after N rounds.

## Game 9 — Pass & Guess (Premium, Single Device, 2–30 players)

- One phone is passed around. Each player privately types an answer to a shared question (predefined pack or custom).
- After all answers are in, the phone shows all answers anonymously. Players take turns guessing who wrote each answer.
- Points: correct guesses + bonus for fooling others. Multi-round support with archived rounds.
- Timer per phase configurable (answer time, guess time).

## Game 10 — Truth & Dare (Free, Single Device, 3–12 players)

- Spin-the-bottle classic. A **beer-bottle image** (vertical glass bottle, cap on top) spins on screen and lands on a player.
- Chosen player picks **Truth** or **Dare** — app shows a prompt from the selected deck.
- Difficulty / deck modes: Classic, Spicy, Couple, Party.
- After prompt, a "Complete / Skip" button advances to the next spin. Players can cycle until they want to stop.

## Game 11 — Draw & Rush (Premium, 2–12 players, Single / Multi)

- One player is the drawer, others are guessers. Drawer gets a secret concept (from a pack) or picks their own.
- Drawer has ~100s to draw on a canvas (pen colors, sizes, undo, clear). Others watch live and shout/type guesses.
- Concept modes:
  - **Free Draw:** anyone can pick their own word and whisper it to the app.
  - **Prompted:** the app picks the concept from a themed pack.
- Multi Device: realtime canvas sync — others see strokes as they appear and submit typed guesses. First correct guess wins the round and earns points with the drawer.
- Rotate drawer each round. Final leaderboard after all rotations.

## Shared Feature Requirements

- **How-To-Play overlay** for every game, accessible from setup and during play.
- **Rematch** button at end of game that restarts with same players.
- **Pause / Leave** confirmation when backing out of a live game.
- **Sound & Haptics:** button taps, round-start stingers, winner fanfare, wrong-answer buzzes, soft background loop per game.
- **Accessibility:** Dynamic Type, VoiceOver labels on every interactive element, reduce motion support.
- **Persistence:** unfinished sessions should be recoverable if the app is killed mid-match (at least in multi-device rooms).

Use the multi-device prompt to wire any game marked Multi / Team to the realtime room system.
