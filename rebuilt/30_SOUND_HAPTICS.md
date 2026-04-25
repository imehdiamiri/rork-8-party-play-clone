# 30 — Sound & Haptics

Files: `Services/SoundManager.swift`, `Services/FeedbackService.swift`, `Views/ToastOverlay.swift`.

## SoundManager
- `@Observable` singleton with `isEnabled: Bool` (persisted in `UserDefaults`).
- Uses `AVAudioPlayer` instances pre-loaded on `init()` for low-latency playback.
- All sound files are short MP3/AAC bundled in the Asset Catalog as data assets.

### Method roster (call from views)
- `playTabSwitch()` — tiny click ~30ms.
- `playNavigation()` — softer click, used when pushing nav stacks.
- `playGameStart()` — chime+rise, used at the start of a session.
- `playRoundComplete()` — bell.
- `playMatch()` / `playMismatch()` — for Memory Grid.
- `playRecordStart()` / `playRecordStop()` — for Reverse Singing.
- `playReveal()` — used at reveal phases (Pass & Guess, Imposter, Reverse Singing).
- `playCoinFlip()` — for Coin Flip tool.
- `playDiceRoll()` — for Dice tool.
- `playBottleSpin()` — looping while bottle spins, stop on settle.
- `playTapCorrect()` / `playTapWrong()` — Tap in Order, Color Trap.
- `playWinFanfare()` / `playLoseSting()` — final round screens.
- `playToast()` — small ping when a toast appears.

Audio session category set to `.ambient` with `.mixWithOthers` so background music keeps playing.

## FeedbackService (haptics)
- `@Observable` singleton with `isEnabled: Bool`.
- Uses `UIImpactFeedbackGenerator(.light/.medium/.rigid)`, `UINotificationFeedbackGenerator`, and `UISelectionFeedbackGenerator`.
- For richer effects (Reverse Singing record-start, Color Trap forbidden tap), use `CHHapticEngine` with custom `CHHapticPattern` files in `Resources/`.

### Method roster
- `tap()` — light impact.
- `select()` — selection.
- `success()` — notification success.
- `warning()` / `error()` — notification.
- `recordStart()` — heavy impact + rising rumble pattern.
- `bigWin()` — multi-step pattern (rumble + sparkle).

## SwiftUI integration
Prefer `.sensoryFeedback(.impact(.medium), trigger: stateValue)` for view-level haptics. Use `FeedbackService` only when CHHaptics patterns are needed.

## Toast overlay
`ToastOverlay.swift` is attached via `.toastOverlay(appModel:)` modifier on `MainTabView`. It listens to `appModel.toastQueue: [Toast]` and renders the head item near the top safe area. Toast struct: `id, title, subtitle?, systemImage, tint, duration (default 3s)`. Auto-dismisses with spring animation. Tap to dismiss early. `appModel.showToast(...)` enqueues. `playToast()` sound plays on appearance.
