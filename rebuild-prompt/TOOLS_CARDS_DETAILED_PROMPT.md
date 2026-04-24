# 8PartyPlay — Party Tools & Card Decks Detailed Prompt

This document specifies every screen, interaction, animation, and content for the Tools tab: the 5 party tools and the card deck library.

---

## 1. Tools Tab Layout

```
ToolsView (NavigationStack)
├── Header: "Tools" viralTitle + ProfileToolbarButton
├── ScrollView
│   ├── Section "Party Tools"
│   │   └── LazyVGrid(3 columns, spacing 12)
│   │       └── ToolCard × 5
│   ├── Section "Card Decks"
│   │   └── VStack of CategoryRow × 5
│   └── Section "AI Card Generator"
│       └── AICardGeneratorEntryCard → Factory tab / inline
```

### ToolCard
- Square card (flexible width, aspect 1:1)
- Background: tool's accent color at 20% opacity + tool accent gradient border (1.5pt)
- Center: tool SF Symbol 32pt in 60×60 accent-tinted rounded square
- Below: tool name 14pt semibold, tool tagline 11pt secondary
- Press: `CardPressStyle`, haptic `.selection`
- Tap: open tool as `fullScreenCover` with `preferredColorScheme(.dark)`

---

## 2. Tool 1 — Dice Roller

**AccentColor:** orange. **SF Symbol:** `die.face.5.fill`

### Sheet layout
- Done button top-right (dismisses sheet).
- Title "Dice Roller" + subtitle "Roll 1 to 4 dice".
- **Dice count selector:** horizontal row of 4 circle buttons labeled "1", "2", "3", "4". Selected = orange filled circle. Tap changes count, haptic `.selection`.
- **Dice area:** `ZStack` with `AppBackgroundView`. Shows 1–4 dice arranged in a 2×2 grid or row depending on count.
- **Each die face (`DiceFaceView`):**
  - 88×88pt rounded rect (corner 18), orange.opacity(0.15) background, orange 1.5pt border.
  - Dot layout for faces 1–6 (standard die pip positions).
  - Dots: 14×14pt white circles.
  - Roll animation: rapid random face cycling (18 fps) for 0.8s, then spring snap to result.
  - 3D tilt illusion: apply `rotation3DEffect` alternating between ±15° on X and Y axes during roll.
- **Roll button:** big full-width orange PrimaryButton labeled "Roll" + `die.face.5.fill` icon.
  - On tap: generate N random values 1–6, animate, play `SoundEffect.diceRoll`, haptic `.heavyImpact`.
  - After roll settles: show "Total: {sum}" if N > 1 in a green pill below the dice.
- **Result history:** last 5 rolls shown as tiny pills below the roll button (e.g. "5, 3 → 8"). Fades in after first roll.

### Edge cases
- Dice animate independently with random delay offsets (0–0.1s each) so they don't all stop at the same time.
- Shake gesture (`DeviceShakeModifier`) also triggers a roll.

---

## 3. Tool 2 — Bottle Spinner

**AccentColor:** pink. **SF Symbol:** `arrow.trianglehead.2.clockwise`

### Sheet layout
- Done button top-right.
- Title "Bottle Spinner".
- **Player setup card:**
  - "Add Players" header.
  - TextField list (up to 12 players). Add button (`plus.circle.fill`). Delete by swipe or tap minus.
  - Pre-filled default: "Player 1", "Player 2", "Player 3".
  - Minimum 2 players required to spin; otherwise Spin button shows "Add at least 2 players" disabled.
- **Spin area (below setup):**
  - Player names arranged in a circle (same algorithm as Truth & Dare game).
  - **Bottle image** — `bottle_spinner` asset: a transparent-background vertical beer bottle, cap pointing UP. Size 20% × 56% of the spin area's height. Rotates via `bottleAngle` state.
  - Selected player highlight: their name capsule scales to 1.15, pink glow.
  - **Spin button:** full-width pink PrimaryButton "Spin".
    - On tap: pick random target player, animate bottle with `.timingCurve(0.15, 0.45, 0.2, 1.0, duration: 6.0)` + `Int.random(8...12) * 360` base + jitter `±anglePerPlayer * 0.3`.
    - After 6.05s: play `SoundEffect.bottleLand` + `SoundEffect.playerPicked`, haptic `.rigid`.
    - Show selected player banner: pink card with `sparkles` icon + "SELECTED" caption + player name 24pt heavy.
  - **Restart button** (circle, `arrow.counterclockwise`): resets angle to 0, clears selection.

---

## 4. Tool 3 — Hourglass Timer

**AccentColor:** cyan. **SF Symbol:** `hourglass`

### Sheet layout
- Done button top-right.
- Title "Hourglass" + subtitle "Set your time".
- **Duration picker:**
  - Large time display: "{M}:{SS}" in 64pt rounded monospaced bold, cyan.
  - Minus / Plus buttons (60×60 circles) with press-and-hold auto-repeat (delay 300ms, cadence 100ms).
  - Presets chips row: "30s", "1m", "2m", "5m", "10m" — tap to set.
  - Range: 5 seconds to 60 minutes.
- **Hourglass visual (80×160pt animated):**
  - Top half: `Rectangle` shrinks height as time depletes (sand falling).
  - Bottom half: `Rectangle` grows correspondingly.
  - Both tinted cyan at 30% opacity, inside a capsule-shaped border.
  - Sand color: cyan → orange when ≤ 20% remaining.
  - "Sand particles": 3 tiny white dots animate from top to bottom during countdown (offset spring + repeat).
- **State buttons:**
  - Idle: "Start" (cyan PrimaryButton).
  - Running: "Pause" (secondary style) side by side with "Reset".
  - Paused: "Resume" + "Reset".
  - Finished: "Restart".
- **Running behavior:**
  - Timer ticks every 1s. Use `Timer.publish(every: 1, on: .main, in: .common)`.
  - Hourglass fills proportionally: `progress = elapsed / totalSeconds`.
  - `SoundEffect.countdownTick` plays every second when ≤ 5s remaining.
  - At zero: `SoundEffect.timerEnd`, haptic `.success`, hourglass flips 180° animation (spring 0.6/bounce 0.2), shows "Time's Up!" title in red.
  - Optional sound toggle: small speaker icon top-right of the timer area (`speaker.wave.2.fill` / `speaker.slash.fill`).

---

## 5. Tool 4 — Coin Flip

**AccentColor:** yellow. **SF Symbol:** `circle.and.line.horizontal.fill`

### Sheet layout
- Done button top-right.
- Title "Coin Flip".
- **Coin visual (160×160pt):**
  - Uses SwiftUI `rotation3DEffect(angle, axis: (x: 0, y: 1, z: 0))` to simulate a flip.
  - Front face (`coin_heads` asset) shown when `faceAngle` is in 0...90° and 270...360°.
  - Back face (`coin_tails` asset) shown when `faceAngle` is in 90...270°.
  - Both images: `.resizable()` `.scaledToFit()` inside a 160×160 `ZStack`. Apply `.rotation3DEffect` on each with conditional visibility.
  - Shadow: yellow soft glow (`.shadow(color: .yellow.opacity(0.3), radius: 20)`).
- **Flip button:** full-width yellow PrimaryButton "Flip" + coin icon.
  - On tap: generate random Bool for heads/tails.
  - Animation sequence: quick rotations (3–5 full 360° rotations in 0.8s using `.interpolatingSpring`), then land on the correct face.
  - Play `SoundEffect.coinFlip`, haptic `.mediumImpact`.
  - After landing: show result banner: "HEADS" (green) or "TAILS" (pink) in a large pill, scale-in spring.
- **Score tracker (optional, below result):**
  - "Heads: {h}  Tails: {t}" in two pills. Resets on Done.
- **History:** tiny log of last 5 flips as H/T character pills.

**CRITICAL:** The coin must actually show `coin_tails` on tails. Never show the same face twice in a row regardless of the random result.

---

## 6. Tool 5 — Team Splitter

**AccentColor:** green. **SF Symbol:** `person.3.fill`

### Sheet layout
- Done button top-right.
- Title "Team Splitter".
- **Players input card:**
  - TextEditor or List of TextFields, one per player. "+ Add Player" button.
  - Minimum 2 players. Maximum 30.
  - Pre-filled: "Player 1", "Player 2", "Player 3", "Player 4".
  - Delete by swipe.
  - Import from offline friends: "From Friends" button (small, secondary) — shows a picker of offline friends to add.
- **Team count picker:**
  - "Number of Teams" label.
  - Stepper: minus/plus circles, green accent, count display. Range: 2 to min(players.count/2, 8).
- **Shuffle button:** full-width green PrimaryButton "Shuffle Teams" + `shuffle` icon.
  - On tap: shuffle player list array, split into N roughly equal teams.
  - Animation: each player card "flies" to their team column using `matchedGeometryEffect` or offset animation. Duration 0.5s, staggered 0.04s per card.
  - Play `SoundEffect.gameStart`, haptic `.mediumImpact`.
- **Results view (after shuffle):**
  - One card per team: "Team N" header (green-tinted for even, teal for odd), player list with avatar bubbles.
  - A subtle rainbow border animates around each team card on appear (4 colors cycling, 0.1 opacity).
  - **Shuffle Again** button (secondary) re-runs the animation.
  - **Share** button: formats result as text "Team 1: Alice, Bob\nTeam 2: Carol, Dave" and opens `ShareLink` / share sheet.

---

## 7. Card Decks

### Overview

```
ToolsView → "Card Decks" section
├── CategoryRow: Act     → CategoryDetailView(Act)
├── CategoryRow: Talk    → CategoryDetailView(Talk)
├── CategoryRow: Challenges → CategoryDetailView(Challenges)
├── CategoryRow: Penalty → CategoryDetailView(Penalty)
└── CategoryRow: Couple  → CategoryDetailView(Couple)
```

### CategoryRow (in Tools tab)
- HStack: category icon (24pt in 44×44 rounded square, accent color) + VStack(category name bold 17pt, subtitle 13pt secondary) + Spacer + "N cards" caption + `chevron.right`.
- Background: accent color 8% opacity card, corner 14.
- Tap → push `CategoryDetailView`.

### Category Content

#### Act (purple, `theatermasks.fill`)
- Subtitle: "Physical challenges & fun actions"
- Subtypes:
  - **Pantomime** — act it out without speaking
  - **Dare** — do something bold
  - **Funny Action** — silly physical tasks

#### Talk (blue, `bubble.left.fill`)
- Subtitle: "Conversation starters & party questions"
- Subtypes:
  - **Starters** — easy conversation starters
  - **Personal** — get to know each other
  - **Discussion** — group debate topics
  - **Truth** — honest revelations
  - **Explain & Guess** — describe it, others guess
  - **Icebreaker** — first-meeting fun

#### Challenges (orange, `flag.fill`)
- Subtitle: "Skill tests & timed tasks"
- Subtypes:
  - **Speech** — verbal challenges
  - **Behavior** — act a certain way for N minutes
  - **Time Limit** — do it in under X seconds

#### Penalty (red, `xmark.octagon.fill`)
- Subtitle: "Funny forfeits & group choices"
- Subtypes:
  - **Funny** — harmless embarrassing tasks
  - **Embarrassing** — cringe-worthy moments
  - **Group Choice** — group decides the punishment

#### Couple (pink, `heart.fill`)
- Subtitle: "Questions & activities for couples"
- Subtypes:
  - **Questions** — couple check-in prompts
  - **Dynamics** — relationship challenges
  - **Playful** — fun couple games

---

### CategoryDetailView

**Layout:**
- Header: category icon + name + subtitle + saved-cards button (`bookmark.fill` toolbar button, badge if any saved).
- Horizontal subtype picker chips (scroll horizontally). Selected = accent-tinted filled, others = outlined.
- Swipeable card stack below.

### SwipeableCardStack

The main card interaction view.

```
CardDeckView
├── Background: AppBackgroundView
├── ZStack (card stack)
│   ├── Back-2 card (scale 0.90, offset y +24, opacity 0.4)
│   ├── Back-1 card (scale 0.95, offset y +12, opacity 0.7)
│   └── Front card (full size, interactive)
├── Action bar (bottom)
│   ├── Skip button (`forward.fill`)
│   ├── Save button (`bookmark.fill` / `bookmark`)
│   └── Share button (`square.and.arrow.up`)
└── "N cards left" caption
```

**Card face:**
- 320×420pt rounded rect (corner 24).
- Background: accent category gradient.
- Category icon 48pt white at top.
- Card text: 22pt rounded bold, white, multiline, line spacing 6, vertically centered.
- Subtype badge (small pill) bottom-left.
- "Premium" lock badge top-right if locked.

**Swipe gestures:**
- Drag right → next card (spring back to center if drag < 80pt threshold).
- Drag left → skip card.
- `.offset(x: dragOffset).rotationEffect(.degrees(dragOffset / 20))`.
- At threshold: card flies off screen, next card springs to front (stacked cards animate up).
- Haptic `.selection` when card enters "will swipe" zone, `.mediumImpact` when released and committed.

**Save behavior:**
- `bookmark.fill` button: saves card text + category + subtype to `/users/{uid}/savedCards/{id}` (Firestore, requires sign-in) OR local `UserDefaults` (guest).
- Button toggles gold bookmark icon when saved.
- Toast: "Card saved ✓".

**Share:**
- Opens `ShareLink(item: cardText)` with title "Party card from 8PartyPlay".

**Locked cards:**
- Front card shows a blurred overlay + `lock.fill` 32pt + "Unlock with Pro" button.
- Tapping locked card's CTA opens paywall.

**Empty state:**
- When deck exhausted: `sparkles` icon 48pt + "That's all cards in this deck!" + "Shuffle & Restart" button.

### SavedCardsSheet

Toolbar bookmark button opens this sheet.
- `presentationDetents: [.medium, .large]`.
- List of saved cards grouped by category.
- Each row: category icon + card text (2 lines max) + share button.
- Swipe-to-delete.
- Empty state: `bookmark.slash.fill` 40pt + "No saved cards yet."

---

## 8. Deck Content — Sample Cards (20 per subtype minimum)

### Act — Pantomime (20 cards)
1. Act like you're trying to parallel park a very large truck.
2. Pretend you're a robot that's running low on battery.
3. Mime eating something that tastes absolutely disgusting.
4. Act like you just got an unexpected cold shower.
5. Pretend you're defusing a bomb with 10 seconds left.
6. Act like you're a cat seeing a cucumber for the first time.
7. Mime trying to swat a wasp while eating ice cream.
8. Pretend you're a DJ at a silent disco.
9. Act like you're walking a dog that keeps changing direction.
10. Mime assembling furniture with no instructions.
11. Pretend you're on a rollercoaster, but no one can hear your screams.
12. Act like your shoes are glued to the floor.
13. Mime typing an important email while sneezing uncontrollably.
14. Pretend you're conducting an invisible orchestra.
15. Act like you're trying to open a jar that absolutely will not open.
16. Mime holding back laughter during a serious meeting.
17. Pretend you're a statue that slowly comes to life.
18. Act like your hands are asleep and you need to answer a phone.
19. Mime catching a fish with your bare hands.
20. Pretend you're teaching a yoga class but you have zero flexibility.

### Talk — Truth (20 cards)
1. What is the most embarrassing thing you've googled?
2. Have you ever lied to get out of plans? What did you say?
3. What is the pettiest argument you've ever had?
4. What is a habit you have that you hope no one has noticed?
5. What is the weirdest thing you do when you're alone?
6. Have you ever blamed someone else for something you did?
7. What is something you believed as a child that turned out to be completely wrong?
8. Have you ever faked being sick to get out of something?
9. What is the most ridiculous thing you've ever cried about?
10. Have you ever sent a message to the wrong person? What did it say?
11. What is something you pretend to understand but actually have no clue about?
12. What is the longest you've gone without showering?
13. Have you ever walked into a wrong classroom or meeting and stayed anyway?
14. What is your most irrational fear?
15. What is a food you secretly hate but pretend to like?
16. Have you ever stalked an ex's social media? How recently?
17. What is the most childish thing you still do?
18. Have you ever laughed at the wrong moment? What happened?
19. What is something you bought impulsively and immediately regretted?
20. Have you ever lied on your resume or in a job interview?

### Challenges — Time Limit (20 cards)
1. Say the alphabet backwards in under 15 seconds.
2. Name 10 countries in under 10 seconds.
3. Do 20 jumping jacks in under 20 seconds.
4. Say a tongue twister perfectly 3 times in 10 seconds.
5. Mime an animal in 3 seconds — others must guess it in 5.
6. Stack 5 items from your pockets in a tower in under 10 seconds.
7. Name 5 brands that start with the letter B in under 5 seconds.
8. Clap your hands exactly 7 times in 3 seconds — any over or under and you fail.
9. Write your name in the air with your elbow in under 8 seconds.
10. Recite a 10-word sentence backwards in under 15 seconds.
11. Name 3 songs by Taylor Swift in under 4 seconds.
12. Do a convincing impression of someone in the room in under 5 seconds — group votes.
13. Name 5 things in the room that are blue in under 5 seconds.
14. Spell "onomatopoeia" out loud in under 6 seconds.
15. Say your phone number backwards in under 8 seconds.
16. Name 4 US states in under 3 seconds.
17. Do a wall sit for exactly 20 seconds — stop at 20, not before or after.
18. Name 5 emojis by description alone in under 10 seconds.
19. Hum 3 different songs in 3 seconds each — group must name them.
20. Recite a nursery rhyme in a posh accent in under 10 seconds.

### Penalty — Funny (20 cards)
1. You must end every sentence for the next round with "…and that's on science."
2. Do your best celebrity impression every time someone asks you a question.
3. Speak in only questions for the next 2 minutes.
4. Every time someone says your name this round, you must do a little spin.
5. You must refer to yourself in the third person for the rest of this game.
6. Announce everything you do for the next minute like a sports commentator.
7. You must say "allegedly" after every statement for the next 3 turns.
8. Every answer must be given in a different accent this round.
9. You must whisper intensely for the next 2 minutes.
10. Add "…in my opinion" to the end of every single sentence you say this round.
11. You must moonwalk every time you move from your current spot this round.
12. Speak in a dramatic movie-trailer voice for the next 2 minutes.
13. You must give a thumbs up to every person who speaks for the next round.
14. Act like you're being interviewed on a red carpet whenever someone talks to you.
15. Say "plot twist!" before everything you say this round.
16. You must incorporate a golf clap after every sentence this round.
17. Pretend to be a villain explaining your evil plan whenever you speak this round.
18. Dramatically pause for 3 seconds before saying anything for the next 2 minutes.
19. Add a fake French accent to your name only when someone addresses you.
20. You must yell "CLASSIC!" every time someone says anything remotely predictable.

### Couple — Questions (20 cards)
1. What is one thing about me that surprised you when we first met?
2. What's your favourite memory of us together?
3. Is there something you've wanted to tell me but haven't yet?
4. What is one small thing I do that makes your day better?
5. What do you think our biggest strength as a couple is?
6. If you could relive one day with me, which day would it be and why?
7. What's something you think we should do more of together?
8. When do you feel most loved by me?
9. What is something I do that you find unexpectedly adorable?
10. What's one thing you'd change about how we communicate?
11. What song do you think best describes us as a couple?
12. What was the moment you knew I was the right person for you?
13. If we could live anywhere in the world together, where would you choose?
14. What's something new you'd like us to try together?
15. What's one habit of yours you think I secretly find endearing?
16. If you had to describe our relationship in three words, what would they be?
17. What is one thing you've learned about yourself through being with me?
18. What does your ideal date night with me look like?
19. What's one goal you have for us in the next year?
20. What do you wish more people knew about our relationship?
