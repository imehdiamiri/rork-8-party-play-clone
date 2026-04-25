# 11 — Game: Reverse Singing

**Premium:** No (free).  **Modes:** Single-device only.  **Players:** exactly 2 roles ("Player 1" / "Player 2") — there is no players list, no rounds.

## Concept
Single-screen pass-the-phone audio toy. Player 1 records anything. The phone plays it reversed. Player 2 listens to the reversed audio and tries to mimic it. The mimic is then itself reversed and played as the "result" — so a successful mimic of reversed audio sounds like the original phrase when reversed back.

There is **no scoring, no similarity score, no rounds, no leaderboard, no badges, no rematch flow, no "Play Again", no win/lose state**. The screen is two cards (Player 1, Player 2) plus a History card.

## Entry
Game Detail → "Start Game" pushes `ReverseSingingSessionView` directly. There is **no setup view** for this game, no players editor, no round count, no recording-duration slider.

## Session view — `ReverseSingingSessionView.swift`
`ZStack { AppBackgroundView() ScrollView { VStack { playerOneCard; playerTwoCard; historyCard } } }`. Uses standard `navigationTitle("Reverse Singing")` + `toolbar(.hidden, for: .tabBar)`. No custom top bar, no exit confirmation.

### State machine
`enum ActiveStep: String { case playerOne, playerTwo }` only. Starts at `.playerOne`. After Player 1 finishes recording, moves to `.playerTwo`. Stays there until Player 1 records again (which clears Player 2's data and returns to `.playerOne`).

### Player 1 card (`ReverseSingingPassCard` layout `.playerOne`)
Header: title "Player 1", subtitle "record anything you want", green "Active" pill when current step. Status fades to 0.76 opacity when inactive.

Waveform strip: 10 capsule bars (`width: 2.5pt`, height = `value * 16pt`, min 5pt) with the duration text `String(format: "%.1fs", duration)` on the right. Heights are derived from a deterministic sine of duration — this is **not a live mic meter**, just a visual placeholder.

Controls (2x2 grid of `ReverseSingingSquareButton` + `ReverseSingingSmallCircleButton`):
- **Record** (red, `record.circle.fill` → `stop.fill` while recording, with `.symbolEffect(.pulse, isActive:)`); button label flips to live timer text "Ns / 60s" while recording.
- **Play** (small circle, `play.fill`) — plays the original recording.
- **Play Reverse** (blue, `backward.fill`) — plays the reversed copy.
- **Slow** (small circle, `tortoise.fill`) — plays the reversed copy at `rate = 0.5`.

### Player 2 card (`ReverseSingingPassCard` layout `.playerTwo`)
Header: title "Player 2", subtitle "try to copy reversed", helper text "Listen and record the mimic." while step is active and no mimic recorded yet. Status pill: green "Active" when current, orange "Waiting" otherwise.

Controls:
- **Record Mimic** (red, same UI as Player 1's record button). Enabled only after Player 1 has a recording. Recording auto-stops at 60s.
- **Play** — plays Player 2's raw mimic.
- **Result** (green, `sparkles`) — plays Player 2's reversed mimic if available, otherwise falls back to Player 1's reversed copy.
- **Share** (circle, `square.and.arrow.up`) — opens the share confirmationDialog.

There is **no auto-play of the reversed Player 1 audio**; Player 2 taps "Play Reverse" on the Player 1 card to listen, then taps "Record Mimic" when ready.

### History card
`SurfaceCard` titled "History" with caption "Last 20 only" and a right-aligned bordered "Open" button. When at least one item exists, the latest is rendered inline as a `ReverseSingingHistoryRow` — date pill, plus three buttons:
- **Mimic** (`mic.fill`, pink) — replays the saved Player 2 raw recording.
- **Result** (`sparkles`, blue) — replays the saved reversed mimic (or raw mimic fallback).
- **Share** menu — share Mimic / share Result.

Tapping "Open" opens `ReverseSingingHistorySheet` as a sheet with `.presentationDetents([.medium, .large])`, drag indicator, and `.presentationContentInteraction(.scrolls)`.

History is persisted in `UserDefaults` under the key `"reverse_singing_history"` (Codable JSON), capped at 20 items. When the cap is exceeded, the oldest items' files are deleted from `URL.cachesDirectory`. On load, items whose Player 1 file no longer exists on disk are filtered out.

## Audio implementation — `ReverseSingingAudioService`
- `AVAudioSession.playAndRecord, .default, [.defaultToSpeaker, .allowBluetooth]`.
- Recording: `AVAudioRecorder` with settings `[AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: .high]`. `isMeteringEnabled = true` (but never read — the waveform strip is decorative).
- Reversal: load with `AVAudioFile`, copy into an `AVAudioPCMBuffer`, walk the float / int16 / int32 channel data and write samples in reverse order into a second buffer, then `AVAudioFile(forWriting:)` to a `.caf` file.
- Playback: `AVAudioPlayer` with `enableRate = true` (Slow uses `rate = 0.5`). Output forced to `.speaker`.
- File store: `URL.cachesDirectory.appending(path: "reverse-singing-{sessionUUID}-player1.m4a")` etc. Reversed copies are `.caf`. History copies are `"history-{UUID}-{originalName}"`.

### Permissions & error handling
- On `.task`, `requestPermissionIfNeeded()` calls `AVAudioSession.sharedInstance().requestRecordPermission`. If denied, an alert "Microphone Access Needed" appears with a single "OK" button. **No deep link to Settings.**
- A separate "Audio Error" alert surfaces any thrown error from recording / reversal / playback.
- `AVAudioSession.interruptionNotification` (`.began`): stops both recordings and any playback; if a recording was active, sets `errorMessage = "Recording interrupted — tap Record to resume when ready."`. On `.ended`, reconfigures the session.
- `AVAudioSession.routeChangeNotification` with reason `.oldDeviceUnavailable`: stops in-flight recording.
- `UIApplication.willResignActiveNotification`: stops in-flight recording.

## Sounds & haptics
- System sounds only: `AudioServicesPlaySystemSound(1113)` on record start, `1114` on record stop. (No `SoundManager` calls in this view.)
- `.symbolEffect(.pulse, isActive: isRecording)` on the record button icon. **No `.sensoryFeedback` modifiers.**

## Sharing
`.confirmationDialog("Share", isPresented:)` with two enabled-conditional buttons: "Share Player 2 Raw" (requires raw mimic) and "Share Result" (requires reversed mimic OR raw mimic OR reversed Player 1). Picking either sets `sharePayload: SharePayload?`, which presents a `.sheet(item:)` showing `ReverseSingingShareSheet` (UIKit `UIActivityViewController` wrapper).

## What this view does NOT have
- ❌ no players list / pass-the-phone names
- ❌ no rounds, no round counter, no Round 1 of N UI
- ❌ no recording-duration slider (max is hard-coded 60s)
- ❌ no FFT, no similarity score, no `PerformanceBadge`
- ❌ no leaderboard, no rematch, no "Play Again"
- ❌ no `MatchPhase` (`.intro / .reveal / .finished` etc.)
- ❌ no auto-played reveal sequence
- ❌ no live mic meter waveform (decorative bars only)
- ❌ no tutorial overlay / "How to play" block
- ❌ no `gameTopBarMenu` / exit-confirmation
- ❌ no `SoundManager.playGameStart/playReveal/playRoundComplete` calls
