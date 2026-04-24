# 14 — Localization & Accessibility

The app ships English only at launch but must be fully translation-ready and accessible.

---

## 1. Localization Architecture

- All user-facing strings go through `String(localized:)` or `Text("…")` using a `.xcstrings` catalog at `Resources/Localizable.xcstrings`.
- Never concatenate localized fragments — use interpolation inside a single key:
  - ✅ `String(localized: "\(count) players")`
  - ❌ `"\(count) " + String(localized: "players")`
- Expose an `AppLanguage` enum (`case en, es, fr, de, pt, ar, fa`) with `.systemDefault` first. Only `en` is active at launch. Other cases are scaffolded but hidden behind a Remote Config flag `language_selector_enabled`.
- Store selection in `@AppStorage("app_language")`. Apply via `.environment(\.locale, ...)` at the root.
- Pluralization via `.xcstrings` variations (`one`, `other`). Use `%lld` for integers.
- Dates / numbers: always `Date.FormatStyle`, `.formatted()`, `Measurement` — never `DateFormatter` string literals.

### Strings organization

Group keys by screen/domain with dot prefixes:
- `onboarding.slide1.title`
- `auth.email.placeholder`
- `games.imposter.phase.discussion`
- `tools.dice.title`
- `paywall.yearly.cta`
- `error.network.offline`

### RTL readiness

- Use leading/trailing insets, never left/right.
- Test layout in Xcode with "Right-to-Left Pseudolanguage".

---

## 2. Dynamic Type

- Every text style uses a semantic font (`.title`, `.headline`, `.body`, `.callout`, `.footnote`) — no `.system(size:)` for body copy.
- Custom display fonts use `.custom("…", relativeTo: .largeTitle)` so they scale.
- Limit to `.xxxLarge` on game HUDs where layout breaks; never cap on normal reading screens.
- Test at accessibility sizes `AX1`…`AX5` — verify no truncation on Game Cards, Paywall, Profile.

---

## 3. VoiceOver

- Every interactive element has a meaningful `accessibilityLabel`. Decorative SF Symbols: `.accessibilityHidden(true)`.
- Group compound elements with `.accessibilityElement(children: .combine)` (e.g. game card = title + mode + players).
- Custom controls use `.accessibilityAddTraits(.isButton)` or `.isSelected`.
- Sliders / steppers expose `.accessibilityValue`.
- Live regions: use `.accessibilityAnnouncement` for countdowns, turn changes, winners.
- Game timers: announce remaining seconds at 10 / 5 / 3 / 2 / 1.

### Per-screen must-haves

| Screen | Requirement |
|---|---|
| Onboarding | Slide title + body are one grouped element, paging via swipe gestures labelled "Next slide" |
| Auth | Apple / Google / Email / Guest buttons labelled with provider name |
| Games grid | Each card: `"{Title}, {mode}, {player count}, {locked?}"` |
| Imposter reveal | Role read aloud only after user double-taps to reveal |
| Timers | Announce phase start, midpoint, last 5 seconds |
| Paywall | CTA button reads price and period |
| Draw & Rush | Canvas labelled "Drawing canvas", with action "Clear canvas" |
| Profile | Stats grouped, star balance announced as `"{N} stars"` |

---

## 4. Reduce Motion

- Respect `@Environment(\.accessibilityReduceMotion)`.
- Replace spring/bounce animations with `.linear(duration: 0.2)` or instant transitions.
- Disable: coin flip 3D rotation, bottle spin easing, card swipe parallax, mesh gradient animation, particle effects.
- Keep: crossfades, opacity transitions, progress bar fills.

---

## 5. Color & Contrast

- Never convey state by color alone — pair color with icon or text (e.g. error = red ring **and** `exclamationmark.triangle.fill`).
- Meet WCAG AA 4.5:1 for body, 3:1 for large text. Dark-mode palette already complies; verify brand accents on dark background with Xcode's Accessibility Inspector.
- Support `Increase Contrast` via `@Environment(\.accessibilityShowButtonShapes)` — when true, add visible borders to all button-styled text.
- Support `Differentiate Without Color`:
  - Timer warning state adds ⚠︎ icon in addition to red.
  - Ready/unready players show ✓ / ◌ icons in addition to green/gray.

---

## 6. Hit Targets & Gestures

- Every tappable element ≥ 44×44 pt.
- Provide alternatives to multi-finger gestures:
  - Pinch to zoom → also a double-tap.
  - Long-press menus → also a secondary button.
- Draw & Rush offers a "Show example stroke" helper for users with motor difficulties.

---

## 7. Audio Accessibility

- Every sound cue has a visual equivalent (flash, shake, color change).
- Countdown has on-screen numerals, not just audio beeps.
- Respect the system "Mono Audio" and "Reduce Loud Sounds" settings — routed automatically via `AVAudioSession`.

---

## 8. Checklist

- [ ] All strings in `Localizable.xcstrings`.
- [ ] No hard-coded UI text outside the catalog.
- [ ] Dynamic Type tested AX1–AX5 on every screen.
- [ ] VoiceOver path exercised for: onboarding → auth → game start → paywall → profile.
- [ ] Reduce Motion path exercised for all animations.
- [ ] Contrast checker clean on brand accents.
- [ ] RTL pseudolanguage clean.
