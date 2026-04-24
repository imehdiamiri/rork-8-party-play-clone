# 8PartyPlay — Design System Prompt

This document specifies every reusable component, color, typography rule, animation, and layout pattern in the 8PartyPlay design system. Implement all of these in `DesignSystem.swift` and companion files before building any screen.

> **Companion files (read together):**
> - `02A_RESPONSIVE_AND_FONTS_PROMPT.md` — cross-platform font families, type scale in pt/sp/rem, breakpoints (xs–2xl), spacing & motion tokens.
> - `02B_SCREEN_WIREFRAMES_PROMPT.md` — exact wireframe (anchor + size + behavior) for every screen.
> - `02C_STATE_MATRIX_PROMPT.md` — loading / empty / error / offline state for every screen + skeleton recipes.

---

## 1. Core Principles

- **Dark mode only.** `preferredColorScheme(.dark)` at the root. Never show a light variant.
- **Apple-native feel.** Use SwiftUI native controls. No web-like layouts.
- **Bold & viral.** Big display titles, heavy weights, saturated accents.
- **Motion-rich.** Spring animations on every state change. Haptics on every primary action.
- **Offline-resilient.** UI must look complete even before data loads (use skeleton shimmer placeholders).

---

## 2. Color Palette

### Background layers
```swift
// Base — deepest layer
static let backgroundBase = Color(red: 0.05, green: 0.05, blue: 0.10)
// Card surface — ultraThinMaterial at 72% opacity over base
// Stroke — white at 5% opacity (1pt hairline on cards)
static let cardStroke = Color.white.opacity(0.05)
```

### Semantic colors (use SwiftUI semantic names where possible)
- `.primary` — white
- `.secondary` — white 60%
- `.tertiary` — white 35%
- Destructive: `Color(red: 1.0, green: 0.27, blue: 0.27)`
- Success: `Color(red: 0.20, green: 0.78, blue: 0.35)`
- Warning: `Color(red: 1.0, green: 0.80, blue: 0.0)`

### Per-game accent colors (each game has a gradient pair)
```swift
enum GameAccent {
    case reverseSinging    // pink  → red
    case guessSeconds      // blue  → indigo
    case imposter          // orange → red  (Discussion) / purple → indigo (Clue)
    case memoryGrid        // cyan  → mint
    case truthDare         // red   → pink
    case tenTangle         // purple → indigo
    case memoryPath        // teal  → cyan
    case passGuess         // yellow → orange
    case tapInOrder        // orange → red
    case colorTrap         // pink  → purple
    case drawRush          // cyan  → blue
}
```

### Player palette (12 colors, cycled by player index)
```swift
static let playerPalette: [Color] = [
    .blue, .green, .orange, .purple, .pink, .cyan,
    .mint, .yellow, .red, .indigo, .teal, Color(red: 0.6, green: 0.4, blue: 0.2)
]
```

### Tool accent colors
- Dice: `Color.orange`
- Bottle Spinner: `Color.pink`
- Hourglass: `Color.cyan`
- Coin Flip: `Color.yellow`
- Team Splitter: `Color.green`

### Card category accent colors
- Act: `Color.purple`
- Talk: `Color.blue`
- Challenges: `Color.orange`
- Penalty: `Color.red`
- Couple: `Color.pink`

---

## 3. Typography

### Font scale
```swift
// viralTitleStyle — app headers, game names, tab headers
.font(.system(size: 34, weight: .black, design: .default))
.tracking(-0.5)

// gameTitleStyle — game card names
.font(.system(size: 22, weight: .heavy, design: .default))
.tracking(-0.3)

// sectionHeader — section titles
.font(.system(size: 18, weight: .bold, design: .default))

// body — standard body text
.font(.system(size: 16, weight: .regular, design: .default))

// caption — metadata, subtitles
.font(.system(size: 13, weight: .medium, design: .default))
```

### Rules
- Game titles and screen headers use `.black` or `.heavy` weight.
- Body text uses `.regular` or `.medium`.
- Always support Dynamic Type: use `.font(.headline)` / `.font(.body)` for user-facing text; only use fixed sizes for decorative game UI elements where layout would break.
- Monospaced digits for timers: `.monospacedDigit()`.
- `.rounded` design only for playful in-game numerics (score displays, big countdown numbers).

---

## 4. Background

### `AppBackgroundView`
```swift
// Implementation sketch:
// 1. ZStack
// 2. Bottom layer: Color(backgroundBase) filling the screen
// 3. Mid layer: MeshGradient (iOS 18+) or RadialGradient fallback
//    — 4 blurred blob highlights in blue/indigo/purple/pink
//    — very low opacity (~0.15–0.25), large radius
//    — animates slowly (TimelineView, 8-second cycle, easeInOut)
// 4. Top layer: a very subtle noise texture overlay (0.03 opacity)
//    — generate via CIFilter("CIRandomGenerator") or a bundled noise asset
// Result: feels like a deep space / neon night aesthetic
```

Apply `AppBackgroundView()` as the background of every `NavigationStack` root view and every `fullScreenCover`. Never use a plain `Color.black`.

---

## 5. Component Library

### `SurfaceCard`
A rounded rectangle card used for all content groupings.
```swift
// Properties:
// - padding: EdgeInsets (default .init(top: 16, leading: 16, bottom: 16, trailing: 16))
// - cornerRadius: CGFloat (default 18)
// Background: .ultraThinMaterial, opacity 0.72
// Overlay: RoundedRectangle(cornerRadius: 18).stroke(cardStroke, lineWidth: 1)
// No shadow (material provides depth)
```

### `GameCard`
Used in the 2-column home grid.
```swift
// - 1:1 aspect ratio
// - Background: LinearGradient(game.accentColors, startPoint: .topLeading, endPoint: .bottomTrailing)
// - Corner radius: 20
// - Content: VStack — game symbol (36pt, white) in a 64×64 white.opacity(0.15) rounded square
//            + game name (gameTitleStyle, white)
//            + mode chips row (small 20pt capsules)
//            + player count (caption, white.opacity(0.7))
// - Lock badge (top-right): if locked → 28×28 dark glass circle + lock.fill 14pt white
//   positioned .overlay(alignment: .topTrailing).padding(8)
// Press animation: CardPressStyle (scale 0.95, spring response 0.3)
```

### `StatusPillView`
Small capsule tag used everywhere.
```swift
// Init: (icon: String?, label: String, color: Color, style: PillStyle)
// PillStyle: .filled (colored bg 18% opacity + colored text)
//            .outlined (colored stroke 1pt + colored text)
//            .tinted  (colored bg 10% + white text)
// Height: 26pt, horizontal padding 10pt, corner radius 13pt
// Icon: 11pt SF Symbol, label: 12pt medium
```

### `SectionHeaderView`
```swift
// HStack: title (sectionHeader style, white) + Spacer + optional trailing button
// Subtitle: caption style, .secondary, below title with 2pt spacing
// Left edge aligned, 16pt horizontal padding
```

### `ViralTitleStyle` (ViewModifier)
```swift
// .font(.system(size: 34, weight: .black)) + .tracking(-0.5) + .foregroundStyle(.white)
// Apply as: Text("8PartyPlay").viralTitle()
```

### `ProfileToolbarButton`
```swift
// Circular button, 36×36
// Content: user's avatar image (AsyncImage) or SF Symbol "person.crop.circle.fill"
// Background: white.opacity(0.1) circle
// Border: white.opacity(0.15) circle stroke 1pt
// Tap → open Profile sheet
```

### `CardPressStyle` (ButtonStyle)
```swift
// scaleEffect: isPressed ? 0.93 : 1.0
// animation: .spring(response: 0.3, dampingFraction: 0.6)
// No other visual change — background handles appearance
```

### `SecondaryActionButtonStyle` (ButtonStyle)
```swift
// Background: white.opacity(0.08) rounded rect, corner 12
// Foreground: white.opacity(0.85)
// Press: scale 0.96, spring 0.25
// Border: white.opacity(0.1) 1pt
```

### `PrimaryButtonStyle` (ButtonStyle)
```swift
// Background: LinearGradient(accent color pair) rounded rect, corner 14
// Foreground: white, semibold 17pt
// Press: scale 0.96
// Shadow: accent.opacity(0.4), radius 8, y 4
// Haptic: .impact(.medium) on press
```

### `ToastOverlay`
Global toast system anchored to the root `ZStack`.
```swift
// Toast types: .success(message), .error(message), .info(message), .warning(message)
// Each type has: icon (SF Symbol), text, accent color
// Appearance: SurfaceCard, bottom-anchored, slide-up + fade-in, auto-dismiss after 3s
// Dismiss: swipe down or tap
// Multiple toasts stack (max 3 visible)
// Exposed via: Environment key `\.toastManager` or via AppViewModel.showToast(...)
```

### `ConnectionBannerView`
Thin top banner (below the safe area, above content).
```swift
// States:
//   .connecting → yellow "Reconnecting..." + ProgressView
//   .disconnected → red "No connection" + wifi.slash icon
//   .reconnected → green "Back online" (auto-hides after 2s)
// Height: 36pt
// Material: .thinMaterial tinted with state color at 20%
// Slide-down animation when shown, slide-up when hidden
// Managed by SessionResilienceService → AppViewModel.connectionState
```

### `FirstTimeHintOverlay`
One-time contextual tutorial tip.
```swift
// Keyed by: UserDefaults bool "hint_seen_{key}"
// Layout: HStack — colored SF Symbol icon (32pt) + VStack(title, subtitle) + X dismiss
// Background: SurfaceCard with accent color tint (10%)
// Animation: slide-up + fade on appear, fade-out on dismiss
// Auto-dismiss after 6s (or on tap anywhere)
```

### `CurrentTurnPill`
Shows whose turn it is during games.
```swift
// Capsule: player's palette color at 20% bg + player name + pulsing dot
// Pulse: scale 1.0→1.15→1.0 repeating, 1.2s, easeInOut
// Name: 14pt semibold, player palette color
```

### `PassThePhoneView`
Full-screen interstitial for passing the device.
```swift
// Background: AppBackgroundView
// Center: hand.raised.fill 56pt in accent-colored 100×100 rounded square
// Title: "Pass the phone to" (secondary, 17pt)
// Player name: 28pt heavy, player palette color, scale 1.2 spring on appear
// Optional subtitle
// One big PrimaryButton at bottom
// Soft haptic when name changes
```

### `HowToPlaySheet`
Reusable bottom sheet with game rules.
```swift
// presentationDetents: [.medium, .large]
// dragIndicator: .visible
// Content: ScrollView with numbered blue-circle list
// Each item: HStack — "N" in blue circle (28×28) + rule text (body style)
// Header: game symbol 32pt + game title + "How to Play" caption
```

### `CompactLibraryTabGlassEffect`
Tab bar enhancement (iOS 26+ glass, iOS 18–25 material fallback).
```swift
if #available(iOS 26.0, *) {
    tabView.glassEffect()
} else {
    tabView.background(.ultraThinMaterial)
}
```

---

## 6. Animation Presets

### Standard spring
```swift
.spring(response: 0.35, dampingFraction: 0.7)
```

### Bouncy spring (for game reveals, score pops)
```swift
.spring(response: 0.45, dampingFraction: 0.55)
```

### Quick press
```swift
.spring(response: 0.25, dampingFraction: 0.8)
```

### Slow float (for idle states, pulsing elements)
```swift
.easeInOut(duration: 1.4).repeatForever(autoreverses: true)
```

### numericText transition
Use `.contentTransition(.numericText())` on any Text that displays a changing number (scores, counters, timers).

### Staggered entrance
When a list of cards/rows appears, stagger `.offset(y: 20).opacity(0)` → default state with a 0.08s delay per index.

### confetti
30 colored circles (yellow/teal/cyan/green/orange/pink/purple), explode from center, physics-driven downward fall, 2s duration. Used on win screens.

---

## 7. Haptics

```swift
// FeedbackService wraps all haptics. Respects the user's Haptics toggle in Settings.
enum HapticType {
    case selection     // UISelectionFeedbackGenerator — tab changes, chips
    case lightImpact   // UIImpactFeedbackGenerator(.light) — tile taps
    case mediumImpact  // UIImpactFeedbackGenerator(.medium) — button taps, turn transitions
    case heavyImpact   // UIImpactFeedbackGenerator(.heavy) — game start, big confirms
    case success       // UINotificationFeedbackGenerator(.success) — correct answer, win
    case error         // UINotificationFeedbackGenerator(.error) — wrong answer, fail
    case warning       // UINotificationFeedbackGenerator(.warning) — timer low
    case rigid         // UIImpactFeedbackGenerator(.rigid) — spin starts
}

// Usage in SwiftUI:
.sensoryFeedback(.selection, trigger: selectedTab)
.sensoryFeedback(.success, trigger: gameWon)
.sensoryFeedback(.error, trigger: wrongAnswer)
```

Always apply `.sensoryFeedback` on the SwiftUI side. Use `FeedbackService` only in ViewModels or services where `.sensoryFeedback` is unavailable.

---

## 8. Sound

`SoundManager` is a singleton. All audio is off when the user toggles Sound off in Settings.

```swift
enum SoundEffect: String {
    case tabSwitch        // soft click
    case navForward       // whoosh in
    case navBack          // whoosh out
    case gameStart        // round-start stinger (~0.8s)
    case gameEnd          // victory fanfare (~2s)
    case correctAnswer    // bright ding
    case wrongAnswer      // low buzz
    case countdownTick    // tick
    case countdownEnd     // final-tick long beep
    case cardFlip         // paper flip
    case coinFlip         // whoosh + clink
    case diceRoll         // tumble
    case bottleSpin       // spinning top
    case bottleLand       // clink
    case playerPicked     // pop
    case timerEnd         // alarm bell (soft)
    case buttonTap        // micro-click
    case shareSheet       // swoosh
}
```

Sounds are short AAC/CAF files bundled in the app. Use `AVAudioPlayer` or `AVAudioEngine` depending on overlap needs. Pre-load all sounds at app launch.

---

## 9. Icon & Image Assets

All raster image assets are bundled in `Assets.xcassets`:

| Asset name | Usage |
|---|---|
| `app_logo` | `h03kekxe8ymunf0mls4b3.png` — app icon, splash, About |
| `coin_heads` | `5bi465cwzmc67jtcmnxco.png` — Coin Flip heads face |
| `coin_tails` | `sq46dl6bh1k6olsges2hi.png` — Coin Flip tails face |
| `bottle_spinner` | transparent PNG of a vertical beer bottle, cap on top |

SF Symbols are used for everything else. Always use filled variants (`.fill` suffix) unless the outline is meaningfully different. Apply gradient foregrounds on large hero icons:

```swift
Image(systemName: "gamecontroller.fill")
    .foregroundStyle(
        LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    )
```

---

## 10. Layout Rules

- **Safe area:** always use `.safeAreaInset` or `.ignoresSafeArea(.keyboard)` as appropriate; never hardcode insets.
- **Horizontal padding:** 16pt on all scrollable content containers.
- **Card spacing in grids:** 12pt.
- **Minimum touch target:** 44×44pt for every interactive element.
- **Sheet backgrounds:** do NOT add `.padding()`, `.background()`, or `.clipShape()` to the root of sheet content — the system sheet already provides this.
- **Images in cards:** use `Color(...).frame(height:).overlay { image.resizable().aspectRatio(.fill).allowsHitTesting(false) }.clipShape(...)` — never use a `.fill` image directly inside a frame (layout overflow bug).
- **LazyVGrid game grid:** 2 columns, `.adaptive(minimum: 160)` or fixed `[GridItem(.flexible()), GridItem(.flexible())]`, spacing 12.

---

## 11. iOS 26 Liquid Glass

```swift
// Use glassEffect on: tab bars, floating pills, hero buttons, segmented controls
if #available(iOS 26.0, *) {
    content
        .glassEffect(.regular.interactive())
} else {
    content
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 14))
}

// GlassEffectContainer for groups of glass elements that should share a backdrop
if #available(iOS 26.0, *) {
    GlassEffectContainer {
        HStack { pill1; pill2; pill3 }
    }
}
```

Apply glass to: the bottom tab bar, the Join pill in the Games header, mode filter chips, profile toolbar button, connection banner, and the paywall tier cards.

---

## 12. File Organization

```
8PartyPlay/
├── DesignSystem/
│   ├── DesignSystem.swift          // all tokens (colors, fonts, spacing)
│   ├── AppBackgroundView.swift
│   ├── SurfaceCard.swift
│   ├── GameCard.swift
│   ├── StatusPillView.swift
│   ├── PrimaryButtonStyle.swift
│   ├── CardPressStyle.swift
│   ├── SecondaryActionButtonStyle.swift
│   ├── ToastOverlay.swift
│   ├── ConnectionBannerView.swift
│   ├── FirstTimeHintOverlay.swift
│   ├── CurrentTurnPill.swift
│   ├── PassThePhoneView.swift
│   ├── HowToPlaySheet.swift
│   └── ConfettiView.swift
├── Managers/
│   ├── SoundManager.swift
│   └── FeedbackService.swift
```
