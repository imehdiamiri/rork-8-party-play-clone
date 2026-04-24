# 8PartyPlay — Cross-Platform Responsive & Font Tokens

This file extends `02_DESIGN_SYSTEM_PROMPT.md` with **exact** responsive breakpoints, font families per platform, and spacing/sizing tokens shared across iOS, Android, and Web. Read this **before** building any screen on any platform. The numeric tokens in `02` are the source of truth; this file only maps them onto each platform.

---

## 1. Font Families (per platform)

The visual identity is a clean, geometric sans-serif with a heavy/black display weight. iOS uses the system font; Android and Web mirror it as closely as possible.

| Platform | Body / UI font | Display / Heavy font | Monospaced (timers, codes) |
|---|---|---|---|
| **iOS** | SF Pro Text (system, `.default`) | SF Pro Display (system, `.default`, weight `.black`/`.heavy`) | SF Mono (`.monospaced`) — used via `.monospacedDigit()` for timers |
| **Android** | `Inter` (Google Fonts, variable) — fallback `Roboto` | `Inter` weight 900 (Black) — fallback `Roboto Black` | `JetBrains Mono` — fallback `Roboto Mono` |
| **Web** | `Inter` via `next/font/google` (`subsets: ['latin']`, `display: 'swap'`) | `Inter` weight 900 | `JetBrains Mono` via `next/font/google` |

Rules:
- Never load custom fonts on iOS — system font is mandatory.
- On Android, declare Inter in `res/font/inter_variable.ttf` and reference via `Typography()` in Compose.
- On Web, load Inter once at the root `layout.tsx`. Use `font-variation-settings: "wght" 900` for the black weight.
- Letter-spacing (`tracking` on iOS, `letterSpacing` on Android, `letter-spacing` on Web): apply `-0.5` for `viralTitle` (34/42pt) and `-0.3` for `gameTitle` (22/28pt). Body and caption: 0.

---

## 2. Type Scale (cross-platform)

All sizes are in **pt on iOS**, **sp on Android**, and **rem on Web** (1rem = 16px). Mobile and desktop diverge only at lg+ breakpoints.

| Token | iOS pt | Android sp | Web rem (mobile) | Web rem (desktop ≥ lg) | Weight | Usage |
|---|---|---|---|---|---|---|
| `viralTitle` | 34 | 34 | 2.125rem (34px) | 3rem (48px) | 900 / Black | App headers, game names, splash |
| `gameTitle` | 22 | 22 | 1.375rem (22px) | 1.75rem (28px) | 800 / Heavy | Game card titles, sheet headers |
| `sectionHeader` | 18 | 18 | 1.125rem (18px) | 1.25rem (20px) | 700 / Bold | Section titles |
| `bodyEmphasis` | 17 | 17 | 1.0625rem (17px) | 1.0625rem | 600 / Semibold | Primary buttons, list row titles |
| `body` | 16 | 16 | 1rem (16px) | 1rem | 400 / Regular | Standard text |
| `caption` | 13 | 13 | 0.8125rem (13px) | 0.875rem (14px) | 500 / Medium | Metadata, subtitles, chips |
| `tiny` | 11 | 11 | 0.6875rem (11px) | 0.75rem (12px) | 600 / Semibold | Pill labels, badges |

Dynamic Type / accessibility:
- iOS: prefer semantic styles (`.headline`, `.body`, `.caption`) for any user-facing static text. Use fixed sizes only for game UI where layout would break.
- Android: use `MaterialTheme.typography` with `fontSize` in `sp` so user font scaling applies.
- Web: respect `prefers-reduced-motion` and `prefers-color-scheme`. All sizes in `rem` (never `px`) so user zoom works.

---

## 3. Responsive Breakpoints (Android + Web)

iOS uses size classes (`compact`/`regular`) — no custom breakpoints. Android and Web share the **same** named breakpoints so layouts are predictable across teams.

| Name | Min width | Typical device | Web Tailwind | Android `WindowSizeClass` |
|---|---|---|---|---|
| `xs` | 0 | small phones | (default) | `Compact` |
| `sm` | 480px | large phones | `sm:` | `Compact` |
| `md` | 768px | small tablets / foldables | `md:` | `Medium` |
| `lg` | 1024px | tablets / small laptops | `lg:` | `Expanded` |
| `xl` | 1280px | desktops | `xl:` | `Expanded` |
| `2xl` | 1536px | large desktops | `2xl:` | `Expanded` |

Mandatory layout rules per breakpoint:

- **xs / sm (mobile, < 768px):**
  - 4-tab bottom navigation.
  - Game grid: 2 columns.
  - Card decks: full-width swipe stack.
  - Factory tab: single column.
  - Profile = bottom sheet.
  - Page horizontal padding: 16px.
- **md (tablet portrait, 768–1023px):**
  - Bottom nav still visible but content uses 2-column layouts where it makes sense (Friends + Activity side-by-side).
  - Game grid: 3 columns.
  - Card decks: stack centered, max-width 480px.
  - Page horizontal padding: 24px.
- **lg / xl (desktop, ≥ 1024px):**
  - Replace bottom nav with **left sidebar** (240px fixed) — Web only. Android keeps bottom nav.
  - Game grid: 4 columns.
  - Profile = right-side panel (drawer 360px) or modal — never bottom sheet.
  - Content max-width: 1200px (xl) / 1400px (2xl), centered.
  - Page horizontal padding: 32px.
- **2xl (≥ 1536px):**
  - Game grid: 5 columns.
  - Sidebar may expand to 280px.
  - Use the extra room for a persistent right rail (e.g., Online Friends, Live Rooms) on the home page.

Web container helper (Tailwind):
```tsx
<div className="mx-auto w-full max-w-screen-xl px-4 sm:px-6 lg:px-8" />
```

Android equivalent:
```kotlin
val widthSizeClass = calculateWindowSizeClass(activity).widthSizeClass
val columns = when (widthSizeClass) {
    WindowWidthSizeClass.Compact -> 2
    WindowWidthSizeClass.Medium  -> 3
    WindowWidthSizeClass.Expanded -> 4
    else -> 2
}
```

---

## 4. Spacing & Sizing (shared tokens)

| Token | Value | Usage |
|---|---|---|
| `space-1` | 4 | Tight icon ↔ text |
| `space-2` | 8 | Chip padding, small gaps |
| `space-3` | 12 | Grid spacing, list separators |
| `space-4` | 16 | **Default page horizontal padding (mobile)** |
| `space-5` | 20 | Card internal gap |
| `space-6` | 24 | Page horizontal padding (md) |
| `space-8` | 32 | Page horizontal padding (lg+), section gap |
| `space-10` | 40 | Hero section vertical padding |
| `space-12` | 48 | Above-the-fold whitespace on desktop |

Corner radii: `radius-sm 10`, `radius-md 14`, `radius-lg 18` (SurfaceCard), `radius-xl 20` (GameCard), `radius-pill 999`.

Touch targets: **44×44pt minimum** on iOS, **48×48dp** on Android (Material), **44×44px** on Web.

---

## 5. Color Tokens (cross-platform names)

The numeric values live in `02_DESIGN_SYSTEM_PROMPT.md`. Use these **identical** token names on every platform so the design language stays unified:

```
bg.base                # deepest background
bg.card                # 72% ultraThinMaterial / equivalent rgba(255,255,255,0.05)
bg.elevated            # cards on top of cards
stroke.hairline        # white 5%
text.primary           # white
text.secondary         # white 60%
text.tertiary          # white 35%
accent.success         # 0.20 / 0.78 / 0.35
accent.warning         # 1.00 / 0.80 / 0.00
accent.destructive     # 1.00 / 0.27 / 0.27
game.<name>.start      # gradient start (per-game)
game.<name>.end        # gradient end (per-game)
player.<index>         # 0..11 player palette
tool.<name>            # dice/bottle/hourglass/coin/team
card.<category>        # act/talk/challenges/penalty/couple
```

- iOS: `extension Color { static let bgBase = ... }` in `DesignSystem.swift`.
- Android: `object AppColors { val BgBase = Color(0xFF0D0D1A) ... }` plus Compose `MaterialTheme` override.
- Web: CSS variables in `globals.css` + a Tailwind `theme.extend.colors` mapping (`bg-base`, `text-primary`, etc.).

---

## 6. Motion Tokens (cross-platform)

| Token | iOS | Android | Web |
|---|---|---|---|
| `motion.spring` | `.spring(response: 0.35, dampingFraction: 0.7)` | `spring(stiffness = 380, dampingRatio = 0.7f)` | `framer-motion: { type: 'spring', stiffness: 380, damping: 28 }` |
| `motion.bouncy` | `.spring(response: 0.45, dampingFraction: 0.55)` | `spring(stiffness = 260, dampingRatio = 0.55f)` | `{ type: 'spring', stiffness: 260, damping: 16 }` |
| `motion.quick` | `.spring(response: 0.25, dampingFraction: 0.8)` | `spring(stiffness = 600, dampingRatio = 0.8f)` | `{ type: 'spring', stiffness: 600, damping: 30 }` |
| `motion.fade` | `.easeInOut(duration: 0.25)` | `tween(250, easing = EaseInOut)` | `{ duration: 0.25, ease: 'easeInOut' }` |

All animations must respect `prefers-reduced-motion` (Web), `Settings → Reduce Motion` (iOS), and `Settings → Remove animations` (Android). When reduced motion is on, replace all spring/scale animations with a 0.15s opacity fade.

---

## 7. Asset Density Rules

- iOS: ship `@1x @2x @3x` PNGs in `Assets.xcassets`, or vector PDFs.
- Android: ship `mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi` or use vector drawables (`<vector>`).
- Web: ship 1x + 2x WebP/AVIF via `<picture>` or `next/image`. SVG for icons. Always include a 192/512 PWA icon set.

---

## 8. Done Checklist

Before starting any screen, confirm:
- [ ] Font family loaded on the target platform.
- [ ] Type scale tokens declared in code.
- [ ] Breakpoint helper available (Tailwind config or `WindowSizeClass` reader).
- [ ] Color tokens registered with the names above.
- [ ] Motion tokens centralized in one file per platform.
