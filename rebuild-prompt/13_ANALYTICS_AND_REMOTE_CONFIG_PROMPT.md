# 13 — Analytics, Remote Config & App Check

Instrument every meaningful user action so product decisions are data-driven, and use Remote Config to control behavior without shipping updates.

---

## 1. Firebase Analytics — Event Catalog

All events go through a single `Analytics` service with a strongly-typed enum. Never call `Analytics.logEvent` from a view directly.

### App lifecycle
- `app_open` — auto by Firebase
- `app_first_open` — auto
- `onboarding_started`
- `onboarding_completed` — params: `slides_seen`
- `auth_method_selected` — params: `method` (apple / google / email / guest)
- `auth_success` — params: `method`, `is_new_user`
- `auth_failed` — params: `method`, `error_code`

### Navigation
- `tab_selected` — params: `tab` (games / tools / friends / factory)
- `profile_opened`
- `paywall_viewed` — params: `source` (locked_game / wallet / factory_quota / profile)
- `paywall_dismissed`
- `paywall_purchase_started` — params: `product_id`
- `paywall_purchase_success` — params: `product_id`, `price_usd`
- `paywall_purchase_failed` — params: `product_id`, `error_code`
- `restore_purchases` — params: `restored_count`

### Games
- `game_opened` — params: `game_id`
- `game_mode_selected` — params: `game_id`, `mode` (one_phone / multi_phone / team)
- `game_started` — params: `game_id`, `mode`, `player_count`, `is_host`
- `game_round_completed` — params: `game_id`, `round`, `duration_s`
- `game_ended` — params: `game_id`, `winner_count`, `duration_s`, `ended_reason` (finished / quit / host_left)
- `game_locked_tapped` — params: `game_id`

### Tools
- `tool_used` — params: `tool_id` (dice / bottle / coin / hourglass / team_splitter)
- `card_deck_opened` — params: `deck_id`
- `card_swiped` — params: `deck_id`, `direction` (left / right)
- `card_shared` — params: `deck_id`, `card_id`

### Factory
- `factory_idea_generated` — params: `vibe`, `player_count`
- `factory_cards_generated` — params: `category`, `subtype`, `vibe`, `count`
- `factory_quota_reached`
- `factory_saved` — params: `kind` (idea / pack)
- `factory_shared` — params: `kind`

### Social
- `friend_added_offline`
- `friend_request_sent`
- `friend_request_accepted`
- `room_created` — params: `game_id`, `mode`, `access` (public / private)
- `room_joined` — params: `method` (code / invite / public_list)
- `room_left` — params: `reason` (user / kicked / disconnected)
- `invite_sent` — params: `channel` (share_sheet / push)

### Economy
- `stars_earned` — params: `amount`, `source` (daily / invite / signup / subscription / purchase)
- `stars_spent` — params: `amount`, `reason`
- `daily_reward_claimed` — params: `streak_day`

### Errors
- `error_shown` — params: `code`, `screen`
- `reconnect_attempt` — params: `attempt_number`
- `reconnect_success`

### User Properties
- `is_pro` — bool
- `star_balance_bucket` — `0-49` / `50-199` / `200-999` / `1000+`
- `preferred_mode` — one_phone / multi / team
- `total_matches_bucket`

---

## 2. Firebase Crashlytics

- Call `Crashlytics.setUserID(firebaseUID)` on auth change.
- Log non-fatal errors with `Crashlytics.record(error:)` inside every `catch` that is not user-actionable.
- Custom keys: `last_screen`, `last_game_id`, `room_id`, `is_host`.

---

## 3. Remote Config Keys

All keys must ship with an in-app default and be fetched on every cold start with a 1-hour min fetch interval.

| Key | Type | Default | Purpose |
|---|---|---|---|
| `paywall_enabled` | bool | `true` | Emergency disable |
| `paywall_variant` | string | `"A"` | A/B test paywall design |
| `daily_reward_base` | int | `10` | ⭐ per claim |
| `daily_reward_streak_bonus` | int | `5` | ⭐ per streak day |
| `invite_reward` | int | `30` | ⭐ for inviter on friend join |
| `factory_free_daily_quota` | int | `3` | Free generations / day |
| `factory_pro_daily_quota` | int | `100` | Pro generations / day |
| `max_public_rooms_shown` | int | `50` | Public rooms cap |
| `min_supported_build` | int | `1` | Force-update gate |
| `force_update_message` | string | `""` | Shown in blocking sheet |
| `featured_game_id` | string | `""` | Hero card at top of Games tab |
| `new_games` | stringArray-JSON | `"[]"` | Games to badge "NEW" |
| `disabled_games` | stringArray-JSON | `"[]"` | Server-side kill switch per game |

Expose them through a `RemoteConfigService` and observe with `@Observable`.

---

## 4. App Check

- Enable **App Check with DeviceCheck** on iOS.
- Enforce App Check on: Firestore, Functions, Storage, RTDB.
- In debug builds use Debug provider (`AppCheckDebugProviderFactory`).

---

## 5. Privacy

- Analytics collection respects the `allowsAnalytics` user default. Profile → Privacy has a toggle.
- Crashlytics respects `allowsCrashReports` default.
- No PII in event params (no email, no name). Firebase UID only.
- Info.plist includes `NSUserTrackingUsageDescription` only if IDFA is used (it is **not** required for Firebase Analytics without Ads).
