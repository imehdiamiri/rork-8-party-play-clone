# 8PartyPlay — Cross-Platform Sync Prompt

This document describes how the iOS, Android, and Web clients stay consistent through the single Firebase backend. The goal: one user, one profile, one star balance, one set of rooms — regardless of where they sign in.

---

## 1. Golden Rules

1. **Firestore is the source of truth.** Never cache mutations locally without reflecting them to Firestore. Clients listen with `onSnapshot` (iOS/Android/Web) and update UI reactively.
2. **Server writes entitlements.** Stars, subscriptionTier, subscriptionExpiresAt, publicUserID, and friendship state transitions are written only by Cloud Functions and webhooks — clients only request.
3. **Same shape everywhere.** The exact same field names and types are used by iOS Swift, Android Kotlin, and TypeScript on web. No client-specific fields unless documented below.
4. **Idempotent mutations.** Every mutation that could be retried (subscription grant, invite redemption, star pack purchase) is keyed so a duplicate request never double-credits.
5. **Time is server time.** Use `FieldValue.serverTimestamp()` on writes, never `Date.now()` from the client.

---

## 2. User Identity

- One `FirebaseUser.uid` per user across all platforms. Signing in with the same provider on another device resolves to the same uid.
- `/users/{uid}` holds the canonical profile. All clients listen.
- `publicUserID` is assigned once by `onUserCreate`. Use this for friend search so the internal uid stays private.
- Avatars live in Firebase Storage at `/avatars/{uid}.jpg`. Clients upload and then write `avatarURL` in their own profile doc.
- `platforms` map records last-seen timestamps per platform for analytics.

---

## 3. Entitlements (Subscriptions)

- `subscriptionTier`, `subscriptionSource`, `subscriptionExpiresAt` are written by:
  - `revenueCatWebhook` → `source: "apple"` (iOS only)
  - `stripeWebhook` → `source: "stripe"` (Android + Web)
- All clients read-only. UI logic:
  - If `subscriptionSource == "apple"` → Android/Web show "Managed on iPhone" and hide manage-billing.
  - If `subscriptionSource == "stripe"` → iOS shows "Managed on Web/Android" and hides Restore Purchases.
- Premium gating uses `isPro = subscriptionTier != "none" && subscriptionExpiresAt > now`.

---

## 4. Star Economy

- Single denormalized counter on the user doc + append-only log in `starTransactions/*`.
- Client flow for spending:
  1. User taps "Unlock with ⭐".
  2. Client calls `spendStars({ amount, reason, referenceID })`.
  3. Cloud Function runs a transaction: check balance, decrement, append transaction, grant item (e.g. unlock game).
  4. Client's `onSnapshot` receives the updated doc → UI updates.
- Client flow for granting (external):
  - Signup bonus — `onUserCreate` trigger (+50⭐).
  - Daily reward — scheduled function every 24h (+5⭐ if last claim > 20h).
  - Subscription bonus — RevenueCat/Stripe webhooks.
  - Star packs — RevenueCat/Stripe webhooks.
  - Invite reward — `redeemInviteCode` for both inviter and invitee.
- Duplicate guards: every grant uses `referenceID` as the doc ID in `/users/{uid}/starTransactions/` so retries are no-ops.

---

## 5. Rooms & Multiplayer

Rooms are platform-agnostic: any client can host and any mix of clients can join.

- `hostPlatform` in the room doc is informational (for debugging and for showing "Hosted on iPhone").
- All state changes flow through `/rooms/{id}/state/current` (host writes) and `/rooms/{id}/events/*` (any player appends).
- Joiners receive updates via `onSnapshot`; no polling.
- **Clock sync:** use server timestamps for phase transitions. Every phase has `startedAt` and `durationMs`; clients compute `remaining = startedAt + durationMs - now()` using a `clockSkew` estimate from the RTDB `/.info/serverTimeOffset` endpoint.
- **Presence:** Realtime DB `/presence/{uid}` with `onDisconnect`. Host migration / host-left detection watches this feed.
- **Rejoin:** if a client reconnects within the grace period, Firestore replays state; the client resumes at the correct phase.

---

## 6. Friends

- `/friendships/{id}` is symmetric — either user sees the same record.
- Online status comes from `/presence/{uid}` (RTDB), layered on top of friendship state.
- Friend requests are created only by the requester; only the recipient can flip to `accepted` or `declined` (enforced in rules).
- Incoming-request notifications go out via FCM to all registered tokens (iOS/Android/Web).

---

## 7. Saved Cards & AI Generations

- `/users/{uid}/savedCards/*` is shared across devices. User saves on web → sees on phone immediately.
- AI generation quota: `/users/{uid}/aiQuota/{YYYY-MM-DD}` counts calls per day. Reset daily by the scheduled function.

---

## 8. Notifications

- `/users/{uid}/deviceTokens/*` stores every token across platforms. FCM sends to all by iterating them.
- Token format stable: `{ token, platform: "ios"|"android"|"web", createdAt }`.
- Delete token on sign-out and on token refresh.
- Deep-link schemes shared across platforms:
  - `partyplay://room/<code>`
  - `partyplay://invite/<code>`
  - `partyplay://billing/success` / `partyplay://billing/cancel`
  - `https://8partyplay.app/r/<code>` (universal / App Links)
  - `https://8partyplay.app/invite?code=<code>`

---

## 9. Schema Migrations

- Add a `schemaVersion` field to the user doc; increment when making breaking changes.
- Cloud Function `migrateUser` runs on read if `schemaVersion < current`, repairing old docs.
- All clients tolerate missing fields (use `?? default`), so partial rollouts don't break older clients.

---

## 10. Local Persistence per Platform

- **iOS:** UserDefaults for toggles; Keychain never used for server data; Firestore offline cache enabled.
- **Android:** DataStore Preferences for toggles; Firestore offline cache enabled.
- **Web:** `localStorage` for toggles + persisted auth; Firestore enabled `persistentLocalCache()` for offline reads.
- Local data is UI-only; the server remains authoritative.

---

## 11. Error Handling & Telemetry

- All Cloud Functions return `{ ok: true, data }` or throw `HttpsError`. Clients show a friendly toast and log the error with `MultiplayerTelemetry`.
- Crashlytics is initialized on iOS + Android. Web uses Firebase Performance + Sentry.
- Every subscription / purchase path writes an analytics event with `platform` and `source` dimensions so parity can be audited.

---

## 12. Testing Parity

- End-to-end tests run a scenario where iOS creates a room, Android joins, Web joins, and all three finish Memory Grid with consistent scoring.
- Webhook replay tests verify that idempotent guards hold across all three entitlement paths.
- Visual regression tests check that the same game looks correct on each platform's reference device.
