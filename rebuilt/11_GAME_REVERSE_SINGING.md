# 11 — Game: Reverse Singing

**Premium:** No (free).  **Modes:** Single-device only.  **Players:** 2–30.  **Round:** 75s default.

## Concept
Pass-the-phone audio game. Player A records something (a song lyric, a sentence, etc.). The phone plays it **reversed**. Player B listens, tries to mimic the reversed audio. Then both recordings are revealed forward, and the table laughs.

## Setup (in Game Detail)
- Players list (default = onboarding name + offline friends), min 2.
- Recording duration slider: 5–60s in 5s steps (default 10s).
- Number of rounds: 1–10 (default 3).
- "How to play" tutorial block (3 steps).

## Session view — `ReverseSingingSessionView.swift`
Full-screen `AppBackgroundView`. Top bar: `gameTopBarMenu` with destructive Exit confirmation.

### Phases (drives `MatchPhase`)
1. **`.intro`** — Big round number ("Round 1 of 3"), active player name, big mic button "Tap to Begin Recording", `Pass to {name}` instructions if not the first turn.
2. **Recording (player A)** — large red record button (circle, pulsing 1.0→1.08 scale + opacity 0.7→1.0 every 0.7s), countdown ring around it, live waveform of microphone level (`AVAudioRecorder.averagePower`), "Stop" button. After elapsed >= duration OR Stop tapped, file saves to a temp `.m4a` in app sandbox.
3. **Reversed playback prompt** — "Hand the phone to {next player}". After tap-to-continue, `passToNextPlayer` phase plays the **reversed audio** (precomputed by `AVAudioFile` rendering with reversed sample order; see implementation note).
4. **Mimic recording (player B)** — same recording UI, but plays reversed audio first, then records B mimicking it.
5. **Reveal** — auto-plays forward A, then forward B, with two waveform rows. Show similarity score 0–100 computed from FFT magnitude correlation (see `ReverseSingingViewModel`-equivalent logic in the session view).
6. **Round result** — `PerformanceBadge.badge(for: score)` (Perfect Echo / Reverse Master / Close Match / Funny Try / Chaos Legend). "Next Round" button advances to next pair.
7. **`.finished`** — leaderboard, share-sheet button "Share", "Play Again" (rematch with same players), "Exit".

### Audio implementation
- Use `AVAudioRecorder` with `AVAudioFormat(.aac, sampleRate: 44100, channels: 1)`, peak meter on.
- Reversal: load file with `AVAudioFile`, read all frames into `AVAudioPCMBuffer`, reverse the float channel data in place, write to a new file with `AVAudioFile(forWriting:)`.
- Playback uses `AVAudioPlayer`.
- Microphone permission requested on first record. Show inline alert if denied with `Settings` deep link.

### Sounds
- `SoundManager.shared.playGameStart()` on session start.
- `playRecordStart()`, `playRecordStop()`, `playReveal()`, `playRoundComplete()`.

### Haptics
- `.sensoryFeedback(.impact(.medium), trigger: phase)` on phase transitions.
- `.success` on round complete.
