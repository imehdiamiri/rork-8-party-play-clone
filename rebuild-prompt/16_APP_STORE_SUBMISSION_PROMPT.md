# 16 — Submission & Deployment (App Store + Google Play + Web)

Everything required to publish 8PartyPlay on the **App Store** (iOS), **Google Play** (Android), and **Vercel** (Web). iOS is covered first; Android and Web follow in sections 11 and 12.

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

---

## 11. Google Play Submission (Android)

### Package & identifiers
- **Application ID:** `com.eightpartyplay.app`
- **Version name:** semver (matches iOS)
- **Version code:** monotonic integer
- **Min SDK:** 29 · **Target SDK:** 34+
- Signing: Play App Signing enabled; upload key stored in CI secret (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`).

### Manifest permissions (declare + justify)
- `INTERNET`, `POST_NOTIFICATIONS`, `VIBRATE`, `RECORD_AUDIO` (Reverse Singing), `READ_MEDIA_IMAGES` (avatar).

### Play Console setup
- **App category:** Games → Party.
- **Content rating:** IARC questionnaire — Teen (mild suggestive themes from Truth & Dare).
- **Target audience:** 13+.
- **Data Safety form:** mirror the iOS privacy label. Declare email, username, avatar, user-generated content, purchase history, analytics, crash logs. No tracking, no ads SDK, no IDFA-equivalent.
- **Privacy Policy URL:** `https://8partyplay.app/privacy`
- **Account deletion URL:** `https://8partyplay.app/delete-account` (visible on Google Play product page — required).

### Store listing
- **Short description** (80 chars), **Full description** (4000 chars) — generated via `app-store-metadata` skill then adapted for Play.
- **Feature graphic** 1024×500 PNG.
- **App icon** 512×512 (from `h03kekxe8ymunf0mls4b3.png`).
- **Phone screenshots** (min 2, recommended 8) at 1080×1920 or larger.
- **7"/10" tablet screenshots** optional but recommended for higher placement.
- **Promo video** optional (YouTube URL).

### Deep links & App Links
- Intent-filter `https://8partyplay.app/r/*` and `/invite` with `android:autoVerify="true"`.
- Host `/.well-known/assetlinks.json` on the web domain with the SHA-256 of the Play App Signing key.
- Custom scheme `partyplay://*` for internal + Stripe return.

### Payments (Stripe — not Google Play Billing)
- Since Stripe is used for digital subscriptions, follow Google's **User Choice Billing** program if available in the target markets; otherwise, default to Google Play Billing for the Play Store build and keep Stripe only on the sideloaded/web builds. Pick one path per release.
- If using Stripe: add clear disclosure on the paywall ("Billed by Stripe") and ensure pricing is displayed before purchase.
- If using Play Billing: mirror the Stripe price catalog with Google Play products (`pro_monthly`, `pro_yearly`, `star_100`, `star_500`, `star_1200`) and wire RevenueCat's Android SDK with `EXPO_PUBLIC_REVENUECAT_ANDROID_API_KEY` — entitlements still converge via `revenueCatWebhook`.
- Document the chosen path in the Play Console review notes.

### Firebase setup
- Register Android app in Firebase, download `google-services.json` → `android/app/`.
- Enable **Play Integrity** App Check provider.
- Upload FCM server key / or use the default OAuth-based send.

### Pre-flight (every upload)
- [ ] All permissions justified in Play Console.
- [ ] No debug logs / `Log.d` in release.
- [ ] ProGuard/R8 rules keep Firebase + Stripe classes.
- [ ] `google-services.json` points to the **release** Firebase app.
- [ ] Play Integrity configured.
- [ ] Signed AAB uploaded to Internal testing track first.
- [ ] Crashlytics + mapping file upload configured.

### Release flow
1. Internal testing → Closed testing (20+ testers for 14 days) → Production.
2. Staged rollout 10% → 50% → 100%.

---

## 12. Web Deployment (Vercel)

### Domain
- Primary: `8partyplay.app`
- Redirects: `8partyplay.com`, `www.8partyplay.app`

### Vercel project
- Root directory: `website/`
- Framework preset: Next.js
- Node runtime for Stripe webhook; Edge runtime for marketing pages.
- Environment variables (see `18_WEB_APP_PROMPT.md` section 12) set for Production and Preview.

### Build & performance budgets
- Lighthouse mobile ≥ 95 for `/`, `/privacy`, `/terms`.
- LCP < 2.5s, CLS < 0.05, TBT < 200ms on marketing pages.
- Image optimization via `next/image`; preload hero logo.

### Stripe webhook
- Register `https://8partyplay.app/api/stripe/webhook` **or** the Firebase Cloud Function URL `https://<region>-<project>.cloudfunctions.net/stripeWebhook` in the Stripe Dashboard.
- Set `STRIPE_WEBHOOK_SECRET` in Vercel + Firebase Functions config.

### PWA
- `app/manifest.ts` exposed at `/manifest.webmanifest`.
- `public/sw.js` precaches shell + tool assets; stale-while-revalidate for card JSON.
- `public/firebase-messaging-sw.js` registered for FCM web push.

### SEO & legal
- `/privacy`, `/terms`, `/support`, `/delete-account` live, linked from footer + App Store / Play Console.
- `sitemap.xml` + `robots.txt` via Next.js metadata routes.
- OG image + Twitter card per page.
- Cookie consent banner (GDPR/CCPA) — analytics gated until consent.

### Pre-flight (every deploy)
- [ ] All env vars present (Firebase public, Stripe publishable + prices, reCAPTCHA site key).
- [ ] Server env vars present (Firebase admin, Stripe secret + webhook secret).
- [ ] `NEXT_PUBLIC_APP_URL` matches the deployed domain.
- [ ] Stripe webhook signing verified via `stripe listen --forward-to ...` smoke test on staging.
- [ ] `/.well-known/assetlinks.json` (Android) and `/.well-known/apple-app-site-association` (iOS) hosted and valid.
- [ ] Lighthouse budgets met.
- [ ] Analytics consent banner working; no cookies before consent.

### Release flow
1. Push to `main` → Vercel auto-deploys Production.
2. Feature branches → Preview URLs used for QA.
3. After deploy, run Playwright smoke pack against Production.
