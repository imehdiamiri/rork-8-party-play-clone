# 16 — App Store Submission

Everything required to publish 8PartyPlay on the App Store.

---

## 1. Bundle & Identifiers

- **Bundle ID:** `com.8partyplay.app`
- **Team ID:** from `EXPO_PUBLIC_TEAM_ID`
- **Display name:** `8PartyPlay`
- **Marketing version:** semver (e.g. `1.0.0`)
- **Build number:** monotonic integer, bumped every upload
- **Minimum OS:** iOS 18.0
- **Supported devices:** iPhone only (iPad runs in compatibility mode)
- **Supported orientations:** Portrait on all iPhones. Draw & Rush may allow landscape if toggled in settings (optional).

---

## 2. Required Keys (`project.pbxproj`)

Add via `INFOPLIST_KEY_*` entries:

- `INFOPLIST_KEY_NSCameraUsageDescription` — "We use the camera so you can take a profile photo."
- `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` — "Pick a photo for your profile."
- `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` — "Save generated cards to your library."
- `INFOPLIST_KEY_NSMicrophoneUsageDescription` — "Record voice for Reverse Singing."
- `INFOPLIST_KEY_NSUserNotificationsUsageDescription` — "Notify you about friend requests, invites, and room starts."
- `INFOPLIST_KEY_NSContactsUsageDescription` — *only if* invite-by-contacts is shipped. Otherwise omit.
- `INFOPLIST_KEY_UIBackgroundModes` — `remote-notification`
- `INFOPLIST_KEY_LSApplicationQueriesSchemes` — empty unless deep-linking to third-party apps.
- `INFOPLIST_KEY_CFBundleURLTypes` — register scheme `partyplay`.
- `INFOPLIST_KEY_NSAppTransportSecurity` — default (no arbitrary loads).
- Associated Domains entitlement — `applinks:8partyplay.com`.

---

## 3. App Icon & Screenshots

- Generate icon via `app-config` skill (`generateImage` type `icon`).
- Capture App Store screenshots via `app-config` skill `captureScreenshots`. Required sets:
  - 6.9" (iPhone 16 Pro Max) — 5 screenshots.
  - 6.5" (iPhone 11 Pro Max) — 5 screenshots.
- Suggested screenshot order:
  1. Games grid with hero title overlay.
  2. Imposter reveal moment.
  3. Draw & Rush canvas mid-round.
  4. Party Tools (Dice + Coin + Bottle).
  5. Paywall / Pro benefits.

---

## 4. App Store Metadata (use `app-store-metadata` skill)

- **Name:** `8PartyPlay`
- **Subtitle:** 30-char hook, e.g. `Party games for real friends.`
- **Primary category:** Games → Family
- **Secondary category:** Entertainment
- **Age rating:** 12+ (infrequent/mild mature themes — Truth & Dare)
- **Keywords:** comma-list ≤ 100 chars, localized per market.
- **Description:** 4000 chars max, generated via skill.
- **Promotional text:** 170 chars, updatable without review.
- **Support URL:** `https://8partyplay.com/support`
- **Marketing URL:** `https://8partyplay.com`
- **Privacy Policy URL:** `https://8partyplay.com/privacy`
- **Terms of Use (EULA) URL:** `https://8partyplay.com/terms` (standard Apple EULA is fine if none provided).

---

## 5. Privacy — App Privacy Nutrition Label

Declare in App Store Connect:

| Data category | Collected | Linked to user | Used for tracking |
|---|---|---|---|
| Contact Info → Email | Yes (auth) | Yes | No |
| Contact Info → Name | Yes (username) | Yes | No |
| User Content → Photos | Yes (avatar) | Yes | No |
| User Content → Other (drawings, generated cards) | Yes | Yes | No |
| Identifiers → User ID (Firebase UID) | Yes | Yes | No |
| Usage Data → Product Interaction | Yes (Analytics) | Yes | No |
| Diagnostics → Crash Data | Yes (Crashlytics) | No | No |
| Purchases → Purchase History | Yes (RevenueCat) | Yes | No |

No tracking. No third-party advertising SDK. No IDFA.

---

## 6. In-App Purchases (RevenueCat + App Store Connect)

Set up in App Store Connect and mirror inside RevenueCat:

| Product ID | Type | Price tier | Notes |
|---|---|---|---|
| `partyplay.pro.monthly` | Auto-renewable sub | Tier 5 | 3-day free trial, group `pro` |
| `partyplay.pro.yearly` | Auto-renewable sub | Tier 25 | 7-day free trial, group `pro` |
| `partyplay.stars.small` | Consumable | Tier 1 | 100 ⭐ |
| `partyplay.stars.medium` | Consumable | Tier 3 | 500 ⭐ |
| `partyplay.stars.large` | Consumable | Tier 7 | 1500 ⭐ |
| `partyplay.stars.mega` | Consumable | Tier 15 | 5000 ⭐ |

Requirements:
- Localized display name + description per product.
- Review screenshot per product (paywall).
- Subscription group display name + localized description.
- Restore purchases entry point in Profile → always visible.

---

## 7. Sign in with Apple

- Capability `com.apple.developer.applesignin` enabled.
- App review requires a working Apple sign-in flow because we offer 3rd-party sign-in (Google).
- Provide account deletion (required for apps with sign-in) — visible in Profile and executable without contacting support.

---

## 8. Review Notes

Supply reviewers:
- Demo credentials (pre-seeded test account with Pro entitlement).
- Note that camera/microphone features are degraded in Simulator but fully functional on device.
- Note that multi-device features need two devices — include instructions to use "Join with Code" with a pre-running host room ID on request.
- Explain Stars economy is non-exchangeable virtual currency, used only inside the app.

---

## 9. Pre-Flight (run before every upload)

Use `app-store-preflight` skill to verify:
- [ ] All permission strings present and meaningful.
- [ ] No `NSAllowsArbitraryLoads`.
- [ ] Assets complete (icon, launch, screenshots).
- [ ] No debug logging in Release.
- [ ] No hard-coded secrets.
- [ ] Build signed with the correct Team ID.
- [ ] Crashlytics dSYM upload configured.
- [ ] TestFlight internal group added.

---

## 10. Submission Orchestration

Follow the `app-store-publish` skill to:
1. Generate/refresh icon and screenshots.
2. Generate/refresh metadata.
3. Run preflight.
4. Archive and upload via `asc` CLI.
5. Submit to TestFlight internal → external → App Store review.
