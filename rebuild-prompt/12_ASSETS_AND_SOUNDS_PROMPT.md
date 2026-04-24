# 12 — Assets, Sounds & Haptics

Complete inventory of every asset, sound, and haptic the app uses. Bundle all of these before shipping.

---

## 1. Image Assets (bundled in `Assets.xcassets`)

| Asset name | File ID | Size / format | Used in |
|---|---|---|---|
| App Logo | `h03kekxe8ymunf0mls4b3.png` | 1024×1024 PNG, no alpha | App icon, splash, About sheet, Profile header fallback |
| Coin Heads | `5bi465cwzmc67jtcmnxco.png` | Square PNG, transparent | Coin Flip tool |
| Coin Tails | `sq46dl6bh1k6olsges2hi.png` | Square PNG, transparent | Coin Flip tool |
| Bottle | Transparent PNG (vertical beer bottle, cap up) | 512×1024 | Truth & Dare + Bottle Spinner |
| Onboarding slide 1 | Illustration / SF Symbol composition | — | Onboarding |
| Onboarding slide 2 | Illustration / SF Symbol composition | — | Onboarding |
| Onboarding slide 3 | Illustration / SF Symbol composition | — | Onboarding |
| Empty state — Friends | SF Symbol `person.2.slash` | — | Friends tab |
| Empty state — Rooms | SF Symbol `house.slash` | — | Public rooms browser |
| Default avatar | SF Symbol `person.crop.circle.fill` tinted | — | Guest + fallback profile |

Rules:
- All custom PNGs go into `Assets.xcassets` as **Image Sets** with 1×/2×/3× variants.
- Never hard-code file names inside views — expose them through an `AppAssets` namespace.
- SF Symbols preferred for every icon that is not a branded asset.

---

## 2. App Icon & Launch Screen

- **App Icon:** generated from `h03kekxe8ymunf0mls4b3.png`. Use `app-config` skill (`generateImage` type `icon`) to produce every required size.
- **Launch Screen:** SwiftUI launch view showing centered logo on black (`.black`) background, no text, no spinner. Implemented as `LaunchView.swift` and referenced via `UILaunchScreen` in `project.pbxproj`.
- **AppIcon alternative (Pro users):** optional gold variant — same logo with `#FFCC33` tint. Requires `CFBundleAlternateIcons` entry and `setAlternateIconName` call from Settings.

---

## 3. Sound Effects

All SFX live in `Audio/SFX/` as 44.1 kHz mono AAC, ≤ 1 second, ≤ 40 KB each.

| Key | File | When it plays |
|---|---|---|
| `tap` | `tap.caf` | Every primary button tap |
| `soft_tap` | `soft_tap.caf` | Secondary / toggle taps |
| `success` | `success.caf` | Game won, reward claimed, purchase success |
| `fail` | `fail.caf` | Wrong answer, timeout, purchase failed |
| `star` | `star.caf` | Any ⭐ balance change |
| `countdown` | `countdown.caf` | 3-2-1 before game start |
| `timer_tick` | `timer_tick.caf` | Final 5 seconds of any timer |
| `timer_end` | `timer_end.caf` | Hourglass / game timer hits 0 |
| `dice_roll` | `dice_roll.caf` | Dice Roller animation |
| `coin_flip` | `coin_flip.caf` | Coin Flip animation |
| `bottle_spin` | `bottle_spin.caf` | Bottle Spinner animation |
| `card_swipe` | `card_swipe.caf` | Card deck swipe |
| `notification` | `notification.caf` | In-app toast for push / friend request |
| `draw_stroke` | `draw_stroke.caf` | Draw & Rush pencil stroke start |

All SFX are played through a single `SoundPlayer` actor that:
- Respects a global "Sound On/Off" toggle in Profile.
- Ducks background music (if any) using `AVAudioSession.setCategory(.ambient, options: .mixWithOthers)`.
- Preloads every SFX on app launch.

---

## 4. Background Music (optional, Pro-gated)

- One 30–60 s loop per game that has a long phase (Imposter discussion, Draw & Rush round). Stored as `.m4a`.
- Controlled by same master "Sound" toggle + independent "Music" toggle.
- Fades in/out over 0.5 s using `AVAudioPlayer.setVolume(_:fadeDuration:)`.

---

## 5. Haptics

Use `UINotificationFeedbackGenerator`, `UIImpactFeedbackGenerator`, and `.sensoryFeedback` (iOS 17+). Respect a "Haptics On/Off" toggle in Profile.

| Trigger | Haptic |
|---|---|
| Primary button tap | `.impact(.light)` |
| Destructive action confirmed | `.impact(.heavy)` |
| Success (win, claim, purchase) | `.notification(.success)` |
| Failure (timeout, wrong) | `.notification(.error)` |
| Warning (leaving room, delete) | `.notification(.warning)` |
| Selection change (picker, chip) | `.selection` |
| Timer final tick | `.impact(.rigid)` each second |
| Bottle / coin / dice settle | `.impact(.medium)` on settle frame |
| Card swipe committed | `.impact(.soft)` |
| Draw & Rush stroke start | `.impact(.light)` |

---

## 6. Asset Generation Checklist

- [ ] App icon rendered at every required size via `generateImage` type `icon`.
- [ ] Launch screen verified on all iPhone sizes (SE → Pro Max).
- [ ] All PNGs in `Assets.xcassets` with proper @2x/@3x.
- [ ] All SFX bundled in `Audio/SFX/` and referenced via `AppAudio` namespace.
- [ ] Sound + Haptics toggles wired to Profile settings and persisted via `@AppStorage`.
- [ ] No asset referenced by string literal outside `AppAssets` / `AppAudio`.
