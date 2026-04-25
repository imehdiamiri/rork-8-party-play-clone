# 05 — Backend (Supabase)

The full schema lives in `supabase_final_production.sql` at repo root. Use that file as the single source of truth and apply it once on a fresh project. This document summarizes shape & expectations.

## Project
- URL: `https://lhbepwdudjhghxgiegnl.supabase.co`
- Anon key (publishable): `sb_publishable_0gBYSRLqEyJrrN6bDp5mag_jOPIzSzR`
- OAuth callback scheme: `app.rork.cejfnhlng6nv3gg1g94ab://callback`

## Auth providers
- Email + password (custom username/password flow uses email "{username}@8partyplay.local").
- Sign in with Apple (native via `ASAuthorizationAppleIDProvider`, then `supabase.auth.signInWithIdToken(.apple, idToken:, nonce:)`).
- Google (PKCE web flow, `supabase.auth.signInWithOAuth(.google, redirectTo:)`).
- Anonymous guest (signInAnonymously) for casual room joins without an account.

## Tables (canonical list — keep in sync with the SQL file)
- `profiles` — id (uuid, FK to auth.users), username, public_user_id (int, unique, 6-digit), avatar_url, bio?, created_at, updated_at, push_token?, locale.
- `stars_balance` — user_id PK, balance int default 0, last_daily_claim_at?, signup_bonus_granted bool.
- `star_transactions` — id, user_id, amount, type (text from enum), description, reference_id?, created_at.
- `subscriptions` — user_id, tier (weekly/monthly/yearly/lifetime), is_active, is_lifetime, expires_at?, auto_renews, last_star_grant_at?, source ("revenuecat"|"appstore").
- `friends` — user_a, user_b, created_at (a<b enforced).
- `friend_requests` — id, from_user, to_user, status (pending/accepted/declined), created_at, responded_at?.
- `casual_rooms` — id, code (6-char unique), host_id, host_name, game (text), mode (single/multi/team), status, message, is_public, version, created_at, updated_at.
- `casual_room_players` — room_id, player_id, name, is_host, is_ready, role, joined_at, left_at?.
- `room_invites` — id, room_id, from_user, to_user, status, created_at.
- `game_results` — id, user_id, game (text), mode, room_code?, score, rank, stars_won, played_at.
- `device_tokens` — user_id, token, platform="ios", updated_at.
- `app_config` — singleton row with remote-config keys (daily_reward_amount, signup_bonus_amount, invite_reward_amount, weekly/monthly/yearly star grants, paywall copy overrides, premium game key list).

> XP, level, fakeAnswer, hot_bomb, wrong_answer, title_it tables MUST NOT be created. Earlier migrations may have created `xp_progress`, `xp_awarded` columns and `settings_*` columns on `casual_rooms` — leave them alone if present (the app no longer reads/writes them) but do not include them in fresh schemas.

## RLS (every table on)
- `profiles`: public-read for username/public_user_id/avatar; only owner writes.
- `stars_balance`, `star_transactions`, `subscriptions`, `device_tokens`: only owner reads + writes.
- `friends` + `friend_requests`: visible to either side; writes via RPCs only.
- `casual_rooms` + `casual_room_players`: SELECT for all authenticated users (includes anonymous guests); inserts/updates only via RPCs.
- `game_results`: insert by owner; SELECT by owner only.
- `app_config`: SELECT for everyone; UPDATE for service role only.

## RPC functions (callable from client)
- `set_username(p_username text)` — assigns a free 6-digit `public_user_id` if missing.
- `search_users(p_query text)` — case-insensitive match on username/email/public_user_id; returns up to 20 with relationship state.
- `friend_request_send(p_to uuid)`, `friend_request_accept(p_id uuid)`, `friend_request_decline(p_id uuid)`, `friend_remove(p_other uuid)`.
- `casual_create_room(p_code, p_game, p_mode, p_message, p_is_public, p_settings_rounds=0, p_settings_answer_time=0, p_settings_vote_time=0, p_settings_question_pack='random')` — last four are legacy fakeAnswer params; pass defaults to satisfy the existing schema.
- `casual_join_room(p_code, p_player_name)` — creates a row in `casual_room_players`, marks host left=false.
- `casual_leave_room(p_room_id)`.
- `casual_set_ready(p_room_id, p_is_ready)`.
- `casual_update_status(p_room_id, p_status, p_version)` — optimistic-lock update; bumps version.
- `claim_daily_reward()` — grants daily stars from `app_config.daily_reward_amount`, refuses if claimed within 22h.
- `claim_signup_bonus()` — once per account.
- `claim_invite_reward(p_invite_code)` — increments inviter and invitee balance per `app_config.invite_reward_amount`.
- `record_subscription_event(p_tier, p_is_active, p_is_lifetime, p_expires_at, p_grant_stars int)` — server-side mark-active and bonus star grant.
- `record_star_pack_purchase(p_amount int, p_product_id text)`.
- `record_game_result(p_game, p_mode, p_room_code, p_score, p_rank, p_stars_won)`.

All RPCs return JSON or void. Use `SECURITY DEFINER` and validate caller is auth.uid().

## Realtime
- Channel name: `casual:{room_code}`.
- Broadcast events:
  - `players_changed` — full list of room players.
  - `state_changed` — `CasualRoomStatePayload` (host pushes the session JSON: phase, current round, per-game state).
  - `team_state_changed` — `TeamState` JSON when in `.teamMode`.
  - `host_left` — emitted by the host when they intentionally exit.
- Postgres changes channel: `friends`, `friend_requests`, `casual_rooms`, `casual_room_players` filtered by user / room id, used in fallback when broadcast is offline.

## Webhooks (RevenueCat → Supabase)
RevenueCat configures a webhook to a Supabase Edge Function `revenuecat-webhook` that inserts into `subscriptions` and `star_transactions`. Verify shared secret. Outside the iOS scope but documented here so subscription stars survive across devices.

## Storage
Single bucket `avatars/`. Public-read, write only by the owner (RLS check `name LIKE auth.uid() || '/%'`).
