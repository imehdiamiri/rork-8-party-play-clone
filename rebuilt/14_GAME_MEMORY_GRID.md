# 14 — Game: Memory Grid

**Premium:** No.  **Modes:** Single, Multi, Team.  **Players:** 1–30.

## Concept
Classic pair-matching memory game. Same shuffled board for everyone (deterministic seed) so it's a true race. Lower time + fewer moves wins.

## Setup — `MemoryGridSetupView`
- Grid size picker (segmented): 3×4 (6 pairs), 4×4 (8), 4×5 (10), 5×6 (15), 6×6 (18). Default `small4x4`. Team mode default `large5x6`.
- Players list (single + team) or room create/join (multi).

## Session — `MemoryGridSessionView`
View model: `MemoryGridViewModel`.

### Per-player state
`MemoryTile[]` array of `tileCount` items shuffled with the seeded RNG. `flipped`, `matched`, `pairId`, `symbol`, `colorIndex`. Symbols come from a fixed pool of SF Symbols (12 distinct: heart.fill, star.fill, bolt.fill, leaf.fill, drop.fill, flame.fill, moon.fill, sun.max.fill, cloud.fill, sparkles, hare.fill, tortoise.fill, etc.). Colors cycle through 8 accents.

### Tile interaction
- Tap an unmatched tile → flip face-up.
- If exactly two are flipped:
  - Match: both stay face-up, mark `isMatched = true`, +1 to `matchedPairs`. Play `playMatch()` sound.
  - Mismatch: after 0.8s, flip both back. Play `playMismatch()`.
- Increment `moveCount` once per flip.

### Phases
1. **Countdown** — "3… 2… 1… Go!" 3 seconds.
2. **Live** — running clock (mm:ss), move counter, % matched bar.
3. **Spectator** (multi/team only) — when current player finishes, others see snapshot of the finishers' boards. `MGSpectatorSnapshot` is broadcast via realtime.
4. **Finished** — leaderboard sorted by elapsed time ascending; ties broken by fewer moves.

### Single device
Players take turns one at a time. Each gets the same shuffled board (seed = roomCode hash or session UUID). After all players finish, leaderboard shows.

### Multi device
All players play **simultaneously** on their own phones. Host broadcasts the seed at session start. Each phone runs its own clock.

### Team mode
Two boards, one per team. Each team picks one phone or all members on different phones (host's call). Only the team's collective best time counts.

### Scoring + stars
RewardPolicy: starsForWin = 5, starsForParticipation = 2. Win = first place by elapsed time.
