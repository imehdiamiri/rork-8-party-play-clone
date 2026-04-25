# 31 — Localization, Accessibility, QA, Submission

## Localization
- **English only.** No Persian/RTL/other languages. `AppLanguage` enum has a single case `.english = "en"`.
- All user-facing strings are inline literals (no `.strings` table required at this stage). Keep them under `Utilities/AppLocalization.swift` and `Utilities/GameLocalization.swift` for centralized access.
- Force LTR via `AppLanguageFontModifier` (no-op, but documents intent).
- Numbers / dates use system formatters (`Date.FormatStyle`, `Decimal.FormatStyle`) so they auto-localize for the device region while text stays English.

## Accessibility
- Every interactive element has an `accessibilityLabel` (e.g. ProfileToolbarButton labels itself "Profile").
- Touch targets ≥ 44pt.
- Dynamic Type: titles use `.viralTitleStyle` (system-rounded) which scales; do not pin specific point sizes for body copy. Test at "Larger Accessibility Sizes".
- Reduce Motion: gate decorative spring animations with `@Environment(\.accessibilityReduceMotion)` and use `.linear` fallback for splash, onboarding halos, mesh blur.
- VoiceOver: group avatars + names so they read as one element ("Alice, host, ready").
- High contrast: use `.foregroundStyle(.primary)` / `.secondary` so the system bumps contrast in HC mode.

## Build configuration
- Targets: `App8PartyPlay` (main app), `App8PartyPlayTests`, `App8PartyPlayUITests`.
- iOS 18.0 minimum, Swift 6, strict concurrency = `complete`, default actor isolation = `MainActor`.
- DEBUG: `Purchases.logLevel = .debug`. RELEASE: `.error`.
- `PrivacyInfo.xcprivacy` declares: NSPrivacyTracking = NO, accessed APIs (UserDefaults, FileTimestamp, SystemBoot for crash reports), data types (User ID, Email, Audio Data, Photos for avatar, Friends/Contacts NO, Browsing/Search NO).

## QA checklist
Before each release:
- Walk every game in single-device mode, all settings.
- Run a multi-device session for: Memory Grid, Memory Path, Tap in Order, Color Trap, Imposter, Draw & Rush.
- Run a team-mode session for: Memory Grid, Memory Path, Imposter.
- Verify mic permission flow (Reverse Singing).
- Verify push permission flow (after onboarding).
- Verify Apple/Google sign-in, sign-out, delete account.
- Verify daily reward + signup bonus + invite code apply.
- Verify subscription purchase + restore (sandbox).
- Verify deep link `invite://?code=XYZ` and universal link.
- Background/foreground transitions during a live multiplayer round (host + joiner).
- Connection banner appears when toggling airplane mode.

## App Store submission
- Display Name: 8PartyPlay. Subtitle: "Party games with friends".
- Primary category: Games > Family. Secondary: Entertainment.
- Age rating: 12+ (mild suggestive themes from Truth & Dare and Adult card pack — Adult pack must remain locked behind 18+ toggle).
- Privacy URL + Terms URL filled.
- Screenshots: 6.7", 5.5". Provide a hero set per game (see `screenshots/`).
- App Store description, keywords, promotional text generated via the `app-store-metadata` skill.
- Run `app-store-preflight` skill before each submission.

## What MUST NOT slip back in
- XP, levels, level-up animations.
- Reverse Singing voting.
- Hot Bomb / Wrong Answer Only / Title It / Guess the Fake Answer / Guess the Real Answer.
- Tournaments.
- Persian / Vazirmatn fonts / language picker.
- Any in-app spending mechanism for stars (no buying unlocks with stars).

## Cleanup notes (carry-over from DEVLOG)
- DB tables `xp_progress` and columns `xp_awarded`, `settings_rounds`, `settings_answer_time`, `settings_vote_time`, `settings_question_pack` may still exist in legacy Supabase projects — they are unused and safe to drop in a future migration. Do NOT reintroduce reads/writes to them.
- `GameEngineProtocol.swift` was removed; its only consumed code lives in `Services/SharedResultBuilder.swift` (28 lines).
- `Utilities/AnimationModifiers.swift` is intentionally minimal (32 lines) — it exposes only `slideUpOnAppear` and `CardPressStyle`. Do not re-add the deleted helpers (Bounce/Pulse/Shake/CountdownScale/Confetti).
