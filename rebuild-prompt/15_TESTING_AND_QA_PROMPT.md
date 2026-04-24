# 15 — Testing & QA

Automated tests plus manual QA scripts so nothing regresses between builds.

---

## 1. Unit Tests (`XCTest` / `Swift Testing`)

Use Swift Testing (`@Test`, `#expect`) for all new tests. Target ≥ 70 % coverage on ViewModels and Services.

Required suites:

- **Auth**
  - Email/password sign-in success, wrong password, weak password, rate-limit.
  - Apple / Google token validation paths.
  - Guest upgrade to full account preserves UID and stars.
- **Stars Economy**
  - Daily reward: first claim, repeat claim same day blocked, streak increments across consecutive days, streak resets after a gap.
  - Purchase credits balance atomically.
  - Spend blocks when insufficient.
- **Game engines** (per game)
  - Imposter: role assignment always produces exactly N imposters, never duplicates, word pool never empty.
  - Memory Grid: generated pattern matches declared difficulty size.
  - Ten Tangle: scoring function returns expected values for known sequences.
  - Guess the Seconds: delta calculation handles stop before / after target.
  - Tap in Order: out-of-order tap marks player eliminated.
  - Color Trap: trap trigger logic rejects matching-color taps.
- **Room state machine**
  - Lobby → Starting → In-Game → Ended transitions only through defined edges.
  - Host migration picks next-joined active player deterministically.
  - Reconnection restores player into same seat within `reconnectWindowSec`.
- **RevenueCat bridge**
  - Entitlement derivation from `CustomerInfo` mocks.
  - Restore purchases merges into local state.
- **Remote Config**
  - Defaults load when network is offline.
  - Force-update gate triggers when `min_supported_build > current`.

---

## 2. UI Tests (`XCUITest`)

Smoke flows that run on every CI build:

1. Fresh install → Onboarding → Guest sign-in → Games tab visible.
2. Open Imposter → select 4 players → start → reveal role → finish round.
3. Open Tools → Dice Roller → roll → result visible.
4. Open Factory → generate idea → hit quota → paywall shown.
5. Profile → open wallet → tap star pack → paywall / sandbox purchase.
6. Friends → add offline friend → appears in list.
7. Create Room → join from second simulator → both see lobby (run with two simulators via `xcodebuild test`).

---

## 3. Manual QA Checklist

### Devices
- iPhone SE (3rd gen) — smallest screen, iOS 18.
- iPhone 15 — baseline.
- iPhone 16 Pro Max — largest, iOS 26 Liquid Glass.
- iPad (compatibility mode only, no iPad-specific UI).

### Scenarios
- [ ] Cold launch < 2 s to first frame.
- [ ] Background → foreground keeps user in the same screen.
- [ ] Airplane mode mid-game: connection banner, reconnect attempts, fallback to local.
- [ ] Kill app mid-room: on relaunch user is offered "Rejoin last room".
- [ ] Low Power Mode: animations degrade gracefully, no dropped frames.
- [ ] Dark appearance only — no white flashes on transitions.
- [ ] All haptics respect the Profile toggle.
- [ ] All SFX respect the Profile toggle.
- [ ] Push notifications arrive for: friend request, room invite, room starting.
- [ ] Universal link `https://8partyplay.com/invite?code=ABCD` opens the app to join flow.
- [ ] Custom scheme `partyplay://room/ABCD` opens lobby.
- [ ] Delete Account removes user doc, auth record, Storage assets.
- [ ] Restore Purchases recovers Pro entitlement on a fresh install with same Apple ID.

### Paywall & Purchases (sandbox)
- [ ] Monthly sub purchase → Pro unlocked within 2 s.
- [ ] Yearly sub with intro trial — trial badge visible.
- [ ] Star pack consumable credits balance.
- [ ] Cancel in Settings → entitlement remains until period end.

### Accessibility
- [ ] VoiceOver navigates every screen in a logical order.
- [ ] Dynamic Type AX5 — no truncation on Games grid, Paywall, Profile.
- [ ] Reduce Motion disables coin/bottle/dice physics animations.

---

## 4. Performance Targets

| Metric | Budget |
|---|---|
| Cold launch (iPhone 15) | ≤ 1.8 s |
| Warm launch | ≤ 0.6 s |
| Frame rate in games | 60 fps (120 fps on ProMotion) |
| Memory footprint | ≤ 250 MB in any game |
| Firestore reads per session | ≤ 150 (except active multiplayer) |
| Binary size | ≤ 80 MB |

Use Instruments (Time Profiler, Allocations, Animation Hitches) before every release.

---

## 5. CI Gates

A build is release-eligible only if:
- All unit + UI tests pass.
- `swiftBuild` succeeds on both Debug + Release.
- Preflight checks (see skill `app-store-preflight`) pass.
- No Crashlytics-issue regressions vs previous build.
- Remote Config `min_supported_build` will not orphan the new build.
