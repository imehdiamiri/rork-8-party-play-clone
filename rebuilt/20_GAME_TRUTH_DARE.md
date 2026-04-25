# 20 — Game: Truth & Dare (Spin the Bottle)

**Premium:** No.  **Modes:** Single-device only.  **Players:** 3–12.

## Concept
Classic spin-the-bottle. The bottle spins, lands on a player. That player picks **Truth** or **Dare**, and a card from the chosen pack is drawn.

## Setup — `SpinBottleSetupView`
- Players list 3–12 (avatars arranged around the circle visualization).
- Pack toggle: Truth on/off, Dare on/off (at least one required).
- Card-pack category: Mild / Spicy / Couple / Adult (Adult = locked behind 18+ confirmation toggle).

## Session — `SpinBottleSessionView`

### Layout
- Full-screen `AppBackgroundView`.
- Players arranged on a circle around the screen center using polar coordinates (`angle = 2π * index / count`). Each is a 64pt avatar circle (initial letter + colored ring).
- A bottle image (transparent PNG) at the center, rotated by `bottleAngle: Double` (degrees).

### Spin animation
- Tap "Spin" → bottle accelerates: animate `bottleAngle` by `spinTotalRotation = 360 * (4..<8) + targetAngle` over 3.0s with `.timingCurve(0.05, 0.5, 0.05, 1)` (long ease-out).
- During spin, play `playBottleSpin()` looped sound. Stops at end.
- Detect target player from final angle.

### Resolution
1. **Land** — selected player's avatar pulses; their name appears in big viralTitleStyle.
2. **Choice** — two big buttons: **Truth** (blue) and **Dare** (orange). The player chooses.
3. **Card** — a single `CardView` slides up from bottom showing the prompt. "Done" / "Skip" buttons. Skip = next player gets to spin.
4. **Next** — back to spin.

### Models
`SpinBottleModels.swift` — pack of truths and dares per category. Cards are simple `{id, text, category}`.

### Win condition
There's no winner; this is a hangout game. Session ends when user taps Exit.
