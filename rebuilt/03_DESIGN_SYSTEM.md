# 03 — Design System

Dark-only, mesh-gradient party-app aesthetic. Apple-quality polish, no cookie-cutter look.

## Background — `AppBackgroundView` (use behind every full screen)
```swift
struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0,0],[0.5,0],[1,0],
                    [0,0.5],[0.45,0.45],[1,0.5],
                    [0,1],[0.5,1],[1,1]
                ],
                colors: [
                    .black, .indigo.opacity(0.68), .black,
                    .purple.opacity(0.42), .blue.opacity(0.28), .mint.opacity(0.18),
                    .black, .black, .teal.opacity(0.12)
                ]
            )
            .opacity(0.82)
            .blur(radius: 52)
            LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
        }
    }
}
```

## Typography
- System fonts only (SF Pro). No custom fonts.
- Titles use a "viral" rounded SF style:
```swift
extension Font {
    static func viralTitle(size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
extension View {
    func viralTitleStyle(size: CGFloat, weight: Font.Weight = .black) -> some View {
        self.font(.viralTitle(size: size, weight: weight))
    }
}
```
- Body: `.subheadline` / `.body` system fonts. Captions: `.caption` / `.caption2`.
- Title weights: prefer `.black` for hero titles (e.g. "8PartyPlay" 36pt, page titles 20pt).
- Use `.minimumScaleFactor(0.7–0.9)` and `.lineLimit(1–2)` on titles inside cards.
- App language is English; `AppLanguageFontModifier` exists but is a no-op that forces `.layoutDirection = .leftToRight`.

## Color & tint
- Primary tint: `.blue` (set on `ContentView` root). Avoid custom brand color.
- Secondary text: `.secondary` / `.tertiary`.
- Semantic accent map for game cards (`accentName` → palette):
  - pink → `[.pink, .red, .purple]`
  - cyan → `[.cyan, .mint, .blue]`
  - teal → `[.teal, .green, .mint]`
  - orange → `[.orange, .red, .yellow]`
  - red → `[.red, .pink, .orange]`
  - yellow → `[.yellow, .orange, .red]`
  - purple → `[.purple, .indigo, .pink]`
  - default → `[.blue, .indigo, .purple]`
- All gradient colors use `.opacity(0.95 / 0.7 / 0.45)` cascade.

## Core components (file: `Views/DesignSystem.swift`)

### `SurfaceCard { content }`
12pt padding, max-width, `ultraThinMaterial.opacity(0.72)` 18pt rounded background, white-5% strokeBorder.

### `SectionHeaderView(title:, subtitle:)`
Title = `viralTitleStyle(size: 20, weight: .black)`, subtitle = `.caption .secondary`.

### `MetricChipView(title:, systemImage:)` — small tertiary chip.
### `StatusPillView(title:, systemImage:, tint:)` — capsule with tint @ 12% bg.
### `InlineActionRow` — 30pt icon tile + 2-line title/subtitle.

### Buttons
- `PrimaryActionButtonStyle` — `.blue.opacity(0.88)` rounded-14 fill, white text, 12pt vertical padding.
- `SecondaryActionButtonStyle` — `white.opacity(0.065)` fill + 5% stroke.
- `CardPressStyle` — slight scale-down on press (in `Utilities/AnimationModifiers.swift`).

### `ProfileToolbarButton`
34pt circle with `.white.opacity(0.08)` fill. Shows uploaded `imageData` if present, else `systemImage`. Used in every tab header trailing.

### `GameTopBarMenu` / `gameTopBarMenu` modifier
Ellipsis-circle in toolbar with optional primary action and a destructive Exit button. Used inside every game session view.

### `PlayerBadgeView(player: PlayerProfile)` — 34pt avatar with online dot, host crown pill, ready/waiting pill.

## Animations
- `.smooth` for state changes.
- `.spring(duration: 0.28, bounce: 0.16)` for tab/segment selection.
- `.spring(response: 0.5, dampingFraction: 0.7)` for splash entry.
- `slideUpOnAppear(delay:)` — staggered card entry (0.06s per index).
- Symbol effects (`.symbolEffect(.bounce, value: …)`) for icon emphasis on onboarding pages.

## Overlays
- Toast overlay (`ToastOverlay.swift`) — top-of-screen, auto-dismiss, used via `.toastOverlay(appModel:)` modifier on `MainTabView`.
- `ConnectionBannerView` — orange "Reconnecting…" with spinner, or red "Connection lost" with `wifi.slash`. Driven by `appModel.connectionState`.
- `FirstTimeHintOverlay` — dimmed full-screen tutorial overlay used the first time a user opens a game (state stored in `UserDefaults`).

## iOS 26 capabilities
- Where used (only on home library segmented control), wrap `glassEffect(.regular.tint(.blue).interactive(), in: .capsule)` inside `if #available(iOS 26, *)` and fall back to `Capsule().fill(.blue.opacity(0.88))`. Never assume iOS 26.
