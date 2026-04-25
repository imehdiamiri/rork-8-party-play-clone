# 22 — Tools Tab (Cards root + party tools)

The second tab. SF symbol `wrench.and.screwdriver.fill`, label "Tools". Hosts a `CardsRootView`.

Layout order inside `CardsRootView.body`:
1. Custom header with a tiny 10pt heavy `"TOOLS"` label (1.4 letter tracking) — **not** a `viralTitleStyle` "Party Tools" header.
2. `PartyToolsSection(showsHeader: false)` — the 5 utility cards.
3. Cards library section (deck swiper) — see file 23.

Tools come **first**, cards come second.

## Party Tools section — `Views/PartyToolsViews.swift`
A **3-column** `LazyVGrid` (`count: 3`) of tool cards. Each card opens its tool as a `.sheet(item: $activeTool)` with `.preferredColorScheme(.dark)` forced and a "Done" toolbar button. Tap plays `SoundManager.shared.playNavigation()`.

| Tool | enum case | SF Symbol | Tint | Sheet view |
|---|---|---|---|---|
| Coin Flip | `.coin` | `circle.circle.fill` | yellow | `CoinFlipToolView` |
| Dice | `.dice` | `die.face.5.fill` | orange | `DiceToolView` |
| Hourglass | `.hourglass` | `hourglass` | cyan | `HourglassToolView` |
| Bottle | `.bottle` | `waterbottle.fill` | pink | `BottleToolView` |
| Team Splitter | `.teams` | `person.2.badge.gearshape.fill` | green | `TeamSetupView` |

### Coin Flip — `CoinFlipToolView` (in `CoinFlipAndTeamsToolViews.swift`)
- Picker for **1 or 2 coins** (`ForEach(1...2)`). Plays `SoundManager.shared.playButtonTap()` on flip.
- Each coin animates a flip and lands on Heads/Tails.

### Dice — `DiceToolView`
- Subtitle "Roll 1–4 dice".
- Tap "Roll" → animated tumble per die, sum + values displayed.

### Hourglass — `HourglassToolView`
- Configurable duration; plays a chime when time elapses.

### Bottle — `BottleToolView`
- Spin-the-bottle with a name picker only (no truth/dare).

### Team Splitter — `TeamSetupView`
- Players list + team count; randomly assigns; re-shuffle button.

## Other Fun list — `OtherFunView.swift`
A separate "Party Game Ideas" list rendered through `OtherFunListView`, driven by `PartyGameTutorial`. Expandable ideas cards with step-by-step instructions. This is reachable from the Tools / Cards root area but is a distinct view.
