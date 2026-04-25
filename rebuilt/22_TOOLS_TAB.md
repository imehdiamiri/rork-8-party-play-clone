# 22 — Tools Tab (Cards root + party tools)

The second tab. SF symbol `wrench.and.screwdriver.fill`, label "Tools". Hosts a `CardsRootView` that contains:
1. The **Cards** library at the top (deck swiper).
2. A **Party Tools** section below with 5 utilities.

## Cards (top half)
See file 23 for full deck spec. Tools tab embeds it as the primary content with deck filters.

## Party Tools section — `Views/PartyToolsViews.swift`
A 2-column grid of large tappable tool cards under header "Party Tools":

| Tool | SF Symbol | Tint | Destination |
|---|---|---|---|
| Coin Flip | `dollarsign.circle.fill` | yellow | `CoinFlipToolView` |
| Dice Roller | `dice.fill` | red | `DiceRollerToolView` |
| Hourglass | `hourglass` | orange | `HourglassToolView` |
| Bottle Spinner | `arrow.triangle.2.circlepath` | pink | `BottleSpinnerToolView` |
| Team Splitter | `person.line.dotted.person.fill` | green | `TeamSplitterToolView` |

### Coin Flip — `CoinFlipToolView` (in `CoinFlipAndTeamsToolViews.swift`)
- Center: a 200pt coin image. Two faces drawn with `Image("coin_heads")` / `Image("coin_tails")` or SF symbol fallback.
- Tap "Flip" → animate `rotation3DEffect(.degrees(rotation), axis: (1,0,0))` from 0 → 360 * (4..<7) + finalSide over 1.6s with `.easeOut`. Plays `playCoinFlip()`. Final result label "Heads" or "Tails" appears with `.symbolEffect(.bounce)` and haptic `.success`.
- History row: last 10 results as small coins.

### Dice Roller — `DiceRollerToolView` (in `PartyToolsViews.swift`)
- 1–6 dice picker (segmented).
- Tap "Roll" → each die animates a 3D tumble (rotateX/Y) for ~1.0s and lands on a face. Plays `playDiceRoll()`. Sum + per-die values displayed below. Long-press a die to re-roll just that one.

### Hourglass — `HourglassToolView`
- A 240pt hourglass with two glass bulbs and animated falling sand (`Canvas` with thin rectangles dropping). Top-right button to start/stop, picker for 30s / 60s / 2m / 5m / 10m / custom.
- Plays a final chime + haptic when time elapses.

### Bottle Spinner — `BottleSpinnerToolView`
- Same as Truth & Dare but **without** truth/dare cards. Just a name picker.
- Players list at top (add/remove names). Tap "Spin" — the bottle spins and points at someone. Their name appears in a big card.

### Team Splitter — `TeamSplitterToolView`
- Players list (add/remove).
- "Number of teams" stepper 2–6.
- Optional team names (Team A / Team B / …).
- Tap "Split" — players are randomly assigned. Output shown as a colored grid of teams. Tap "Re-shuffle" to redo.
- Persisted last result for the session only (not across launches).

## Header
"Tools" title with `viralTitleStyle(20, .black)` + `ProfileToolbarButton` trailing. SocialRootView-style custom header (toolbar hidden).

## Sounds & haptics
Every tool plays a tap and a result sound (see file 30) plus an `.impact` haptic at the start and `.success`/`.warning` at the end where appropriate.
