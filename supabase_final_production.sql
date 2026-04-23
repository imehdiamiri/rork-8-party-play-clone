-- ============================================================
-- 8PartyPlay / PartyGames — FINAL Production Supabase SQL
-- Run this ONCE in Supabase SQL Editor.
-- Idempotent: safe to re-run. Drops old objects before recreating.
-- Aligned 1:1 with ios/PartyGames Swift code.
-- ============================================================

-- 0. Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. TABLES
-- ============================================================

-- 1a. profiles
CREATE TABLE IF NOT EXISTS public.profiles (
    id           uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username     text NOT NULL,
    email        text,
    public_id    integer GENERATED ALWAYS AS IDENTITY UNIQUE,
    display_name text,
    avatar_url   text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT profiles_username_length CHECK (char_length(trim(username)) BETWEEN 2 AND 24)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username_unique ON public.profiles (lower(username));
CREATE INDEX IF NOT EXISTS idx_profiles_public_id ON public.profiles (public_id);

-- 1b. wallets (stars-based economy)
CREATE TABLE IF NOT EXISTS public.wallets (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    stars_balance  integer NOT NULL DEFAULT 100 CHECK (stars_balance >= 0),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON public.wallets (user_id);

-- 1c. star_transactions
CREATE TABLE IF NOT EXISTS public.star_transactions (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount           integer NOT NULL,
    transaction_type text NOT NULL,
    reason           text NOT NULL DEFAULT '',
    reference_type   text,
    reference_id     uuid,
    idempotency_key  uuid UNIQUE,
    created_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT star_transactions_type_check CHECK (
        transaction_type IN (
            'reward','purchase','unlockPurchase','gameReward',
            'subscriptionGrant','refund'
        )
    )
);

CREATE INDEX IF NOT EXISTS idx_star_transactions_user_created ON public.star_transactions (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_star_transactions_idempotency ON public.star_transactions (idempotency_key) WHERE idempotency_key IS NOT NULL;

-- 1d. xp_progress
CREATE TABLE IF NOT EXISTS public.xp_progress (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    game_key       text NOT NULL,
    xp             integer NOT NULL DEFAULT 0 CHECK (xp >= 0),
    matches_played integer NOT NULL DEFAULT 0 CHECK (matches_played >= 0),
    wins           integer NOT NULL DEFAULT 0 CHECK (wins >= 0),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, game_key)
);

CREATE INDEX IF NOT EXISTS idx_xp_progress_user_id ON public.xp_progress (user_id);

-- 1e. game_trials
CREATE TABLE IF NOT EXISTS public.game_trials (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    game_key     text NOT NULL,
    times_played integer NOT NULL DEFAULT 0 CHECK (times_played >= 0),
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, game_key)
);

CREATE INDEX IF NOT EXISTS idx_game_trials_user_id ON public.game_trials (user_id);

-- 1f. game_unlocks
CREATE TABLE IF NOT EXISTS public.game_unlocks (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    game_key    text NOT NULL,
    unlocked_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, game_key)
);

CREATE INDEX IF NOT EXISTS idx_game_unlocks_user_id ON public.game_unlocks (user_id);

-- 1g. subscriptions
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    tier                 text NOT NULL,
    is_active            boolean NOT NULL DEFAULT false,
    expires_at           timestamptz,
    auto_renews          boolean NOT NULL DEFAULT false,
    last_star_grant_date timestamptz,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_active ON public.subscriptions (user_id) WHERE is_active = true;

-- 1h. friendships
CREATE TABLE IF NOT EXISTS public.friendships (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    friend_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT friendships_not_same CHECK (user_id <> friend_id),
    CONSTRAINT friendships_pair_sorted CHECK (user_id < friend_id),
    UNIQUE (user_id, friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_user_id ON public.friendships (user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_friend_id ON public.friendships (friend_id);

-- 1i. friend_requests
CREATE TABLE IF NOT EXISTS public.friend_requests (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT friend_requests_not_same CHECK (sender_id <> receiver_id),
    UNIQUE (sender_id, receiver_id)
);

CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver ON public.friend_requests (receiver_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_friend_requests_sender ON public.friend_requests (sender_id, status, created_at DESC);

-- 1j. rooms
CREATE TABLE IF NOT EXISTS public.rooms (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code         text NOT NULL UNIQUE,
    game_key     text NOT NULL,
    host_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status       text NOT NULL DEFAULT 'lobby' CHECK (status IN ('lobby','playing','finished','cancelled')),
    access       text NOT NULL DEFAULT 'private' CHECK (access IN ('private','public')),
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);

-- Ensure 'access' column exists if table was created by an older schema
DO $$ BEGIN
    ALTER TABLE public.rooms ADD COLUMN access text NOT NULL DEFAULT 'private';
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'rooms_access_check'
    ) THEN
        ALTER TABLE public.rooms ADD CONSTRAINT rooms_access_check CHECK (access IN ('private','public'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_rooms_status_created ON public.rooms (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rooms_host ON public.rooms (host_user_id);

-- 1k. room_members
CREATE TABLE IF NOT EXISTS public.room_members (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id    uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_host    boolean NOT NULL DEFAULT false,
    is_ready   boolean NOT NULL DEFAULT false,
    joined_at  timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (room_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_room_members_room_id ON public.room_members (room_id, joined_at ASC);
CREATE INDEX IF NOT EXISTS idx_room_members_user_id ON public.room_members (user_id);

-- 1l. room_invites
CREATE TABLE IF NOT EXISTS public.room_invites (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id         uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    inviter_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invited_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status          text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','revoked')),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT room_invites_not_same CHECK (inviter_user_id <> invited_user_id),
    UNIQUE (room_id, invited_user_id)
);

CREATE INDEX IF NOT EXISTS idx_room_invites_invited ON public.room_invites (invited_user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_room_invites_room ON public.room_invites (room_id);

-- 1m. game_sessions
CREATE TABLE IF NOT EXISTS public.game_sessions (
    id            uuid PRIMARY KEY,
    room_id       uuid REFERENCES public.rooms(id) ON DELETE SET NULL,
    game_key      text NOT NULL,
    mode          text NOT NULL,
    status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','finalized','cancelled')),
    created_by    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_state jsonb,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_game_sessions_room ON public.game_sessions (room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_game_sessions_created_by ON public.game_sessions (created_by);
CREATE INDEX IF NOT EXISTS idx_game_sessions_status ON public.game_sessions (status);

-- 1n. game_results
CREATE TABLE IF NOT EXISTS public.game_results (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id    uuid NOT NULL REFERENCES public.game_sessions(id) ON DELETE CASCADE,
    user_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rank          integer NOT NULL CHECK (rank >= 1),
    score         integer NOT NULL DEFAULT 0,
    stars_awarded integer NOT NULL DEFAULT 0 CHECK (stars_awarded >= 0),
    xp_awarded    integer NOT NULL DEFAULT 0 CHECK (xp_awarded >= 0),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (session_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_game_results_session ON public.game_results (session_id, rank ASC);
CREATE INDEX IF NOT EXISTS idx_game_results_user ON public.game_results (user_id, created_at DESC);

-- 1o. unlock_items (store catalog)
CREATE TABLE IF NOT EXISTS public.unlock_items (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    item_key    text NOT NULL UNIQUE,
    title       text NOT NULL,
    description text,
    price_stars integer NOT NULL DEFAULT 0 CHECK (price_stars >= 0),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- 1p. user_unlocks
CREATE TABLE IF NOT EXISTS public.user_unlocks (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    item_key   text NOT NULL REFERENCES public.unlock_items(item_key) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, item_key)
);

CREATE INDEX IF NOT EXISTS idx_user_unlocks_user ON public.user_unlocks (user_id, created_at DESC);

-- 1q. reward_idempotency
CREATE TABLE IF NOT EXISTS public.reward_idempotency (
    key            uuid PRIMARY KEY,
    scope          text NOT NULL,
    owner_user_id  uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reward_idempotency_owner ON public.reward_idempotency (owner_user_id, created_at DESC);

-- 1r. casual_rooms (guest/anonymous lobby system)
CREATE TABLE IF NOT EXISTS public.casual_rooms (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_code             text NOT NULL,
    game_type             text NOT NULL,
    status                text NOT NULL DEFAULT 'waiting'
                          CHECK (status IN ('waiting','full','starting','in_progress','closed')),
    host_guest_player_id  uuid,
    max_players           integer NOT NULL DEFAULT 10,
    min_players           integer NOT NULL DEFAULT 3,
    settings_rounds       integer NOT NULL DEFAULT 5,
    settings_answer_time  integer NOT NULL DEFAULT 30,
    settings_vote_time    integer NOT NULL DEFAULT 20,
    settings_question_pack text NOT NULL DEFAULT 'random',
    created_at            timestamptz NOT NULL DEFAULT now(),
    started_at            timestamptz
);

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_casual_rooms_room_code'
    ) THEN
        ALTER TABLE public.casual_rooms ADD CONSTRAINT uq_casual_rooms_room_code UNIQUE (room_code);
    END IF;
END $$;

-- 1s. casual_room_players
CREATE TABLE IF NOT EXISTS public.casual_room_players (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id                  uuid NOT NULL REFERENCES public.casual_rooms(id) ON DELETE CASCADE,
    guest_player_id          uuid NOT NULL,
    display_name             text NOT NULL,
    normalized_display_name  text NOT NULL,
    is_host                  boolean NOT NULL DEFAULT false,
    is_connected             boolean NOT NULL DEFAULT true,
    session_token            text NOT NULL,
    joined_at                timestamptz NOT NULL DEFAULT now(),
    last_seen_at             timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_casual_player_name_per_room'
    ) THEN
        ALTER TABLE public.casual_room_players
            ADD CONSTRAINT uq_casual_player_name_per_room UNIQUE (room_id, normalized_display_name);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_casual_player_session_per_room'
    ) THEN
        ALTER TABLE public.casual_room_players
            ADD CONSTRAINT uq_casual_player_session_per_room UNIQUE (room_id, session_token);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_casual_rooms_room_code ON public.casual_rooms (room_code);
CREATE INDEX IF NOT EXISTS idx_casual_rooms_status ON public.casual_rooms (status) WHERE status IN ('waiting','starting','in_progress');
CREATE INDEX IF NOT EXISTS idx_casual_room_players_room_id ON public.casual_room_players (room_id);
CREATE INDEX IF NOT EXISTS idx_casual_room_players_session_token ON public.casual_room_players (session_token);
CREATE INDEX IF NOT EXISTS idx_casual_room_players_connected ON public.casual_room_players (room_id, is_connected);

-- ============================================================
-- 2. TRIGGERS (updated_at auto-set)
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_set_updated_at ON public.profiles;
CREATE TRIGGER profiles_set_updated_at BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS wallets_set_updated_at ON public.wallets;
CREATE TRIGGER wallets_set_updated_at BEFORE UPDATE ON public.wallets
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS xp_progress_set_updated_at ON public.xp_progress;
CREATE TRIGGER xp_progress_set_updated_at BEFORE UPDATE ON public.xp_progress
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS game_trials_set_updated_at ON public.game_trials;
CREATE TRIGGER game_trials_set_updated_at BEFORE UPDATE ON public.game_trials
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS subscriptions_set_updated_at ON public.subscriptions;
CREATE TRIGGER subscriptions_set_updated_at BEFORE UPDATE ON public.subscriptions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS friend_requests_set_updated_at ON public.friend_requests;
CREATE TRIGGER friend_requests_set_updated_at BEFORE UPDATE ON public.friend_requests
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS rooms_set_updated_at ON public.rooms;
CREATE TRIGGER rooms_set_updated_at BEFORE UPDATE ON public.rooms
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS room_members_set_updated_at ON public.room_members;
CREATE TRIGGER room_members_set_updated_at BEFORE UPDATE ON public.room_members
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS room_invites_set_updated_at ON public.room_invites;
CREATE TRIGGER room_invites_set_updated_at BEFORE UPDATE ON public.room_invites
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS game_sessions_set_updated_at ON public.game_sessions;
CREATE TRIGGER game_sessions_set_updated_at BEFORE UPDATE ON public.game_sessions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS game_results_set_updated_at ON public.game_results;
CREATE TRIGGER game_results_set_updated_at BEFORE UPDATE ON public.game_results
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS unlock_items_set_updated_at ON public.unlock_items;
CREATE TRIGGER unlock_items_set_updated_at BEFORE UPDATE ON public.unlock_items
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 3. HELPER FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION public.room_is_visible_to_user(p_room_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.rooms r
        WHERE r.id = p_room_id
          AND (
              r.access = 'public'
              OR r.host_user_id = p_user_id
              OR EXISTS (
                  SELECT 1
                  FROM public.room_members rm
                  WHERE rm.room_id = r.id
                    AND rm.user_id = p_user_id
              )
              OR EXISTS (
                  SELECT 1
                  FROM public.room_invites ri
                  WHERE ri.room_id = r.id
                    AND ri.invited_user_id = p_user_id
                    AND ri.status IN ('pending','accepted')
              )
          )
    );
$$;

CREATE OR REPLACE FUNCTION public.is_room_host(p_room_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.rooms r
        WHERE r.id = p_room_id
          AND r.host_user_id = p_user_id
    );
$$;

CREATE OR REPLACE FUNCTION public.claim_idempotency_key(p_key uuid, p_scope text, p_owner_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.reward_idempotency(key, scope, owner_user_id)
    VALUES (p_key, p_scope, p_owner_user_id);
    RETURN true;
EXCEPTION
    WHEN unique_violation THEN
        RETURN false;
END;
$$;

-- ============================================================
-- 4. RPC FUNCTIONS (called by iOS app)
-- ============================================================

-- 4a. ensure_profile_and_wallet
CREATE OR REPLACE FUNCTION public.ensure_profile_and_wallet(
    p_username text,
    p_email    text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_username text := lower(trim(coalesce(p_username, '')));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_username = '' THEN
        RAISE EXCEPTION 'Username is required';
    END IF;

    INSERT INTO public.profiles(id, username, email, display_name)
    VALUES (v_uid, v_username, p_email, v_username)
    ON CONFLICT (id) DO UPDATE
        SET email        = coalesce(excluded.email, public.profiles.email),
            display_name = coalesce(public.profiles.display_name, excluded.display_name);

    INSERT INTO public.wallets(user_id, stars_balance)
    VALUES (v_uid, 100)
    ON CONFLICT (user_id) DO NOTHING;
END;
$$;

-- 4b. update_profile_settings
CREATE OR REPLACE FUNCTION public.update_profile_settings(
    p_username     text,
    p_display_name text,
    p_public_id    integer DEFAULT NULL,
    p_avatar_url   text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_username text := lower(trim(coalesce(p_username, '')));
    v_display_name text := trim(coalesce(p_display_name, ''));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_username = '' THEN
        RAISE EXCEPTION 'Username is required';
    END IF;

    UPDATE public.profiles
    SET username     = v_username,
        display_name = CASE WHEN v_display_name = '' THEN username ELSE v_display_name END,
        avatar_url   = p_avatar_url
    WHERE id = v_uid;
END;
$$;

-- 4c. search_profiles
CREATE OR REPLACE FUNCTION public.search_profiles(p_query text)
RETURNS TABLE (
    id                 uuid,
    username           text,
    email              text,
    public_id          integer,
    avatar_url         text,
    relationship_state text
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_query text := trim(coalesce(p_query, ''));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_query = '' THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        p.username,
        p.email,
        p.public_id,
        p.avatar_url,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM public.friendships f
                WHERE f.user_id = least(v_uid, p.id) AND f.friend_id = greatest(v_uid, p.id)
            ) THEN 'existing_friend'
            WHEN EXISTS (
                SELECT 1 FROM public.friend_requests fr
                WHERE fr.sender_id = v_uid AND fr.receiver_id = p.id AND fr.status = 'pending'
            ) THEN 'pending_outgoing'
            WHEN EXISTS (
                SELECT 1 FROM public.friend_requests fr
                WHERE fr.sender_id = p.id AND fr.receiver_id = v_uid AND fr.status = 'pending'
            ) THEN 'pending_incoming'
            ELSE 'none'
        END AS relationship_state
    FROM public.profiles p
    WHERE p.id <> v_uid
      AND (
          p.username ILIKE '%' || v_query || '%'
          OR coalesce(p.display_name, '') ILIKE '%' || v_query || '%'
          OR p.public_id::text = v_query
      )
    ORDER BY p.username ASC
    LIMIT 25;
END;
$$;

-- 4d. send_friend_request
CREATE OR REPLACE FUNCTION public.send_friend_request(p_receiver_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF v_uid = p_receiver_id THEN RAISE EXCEPTION 'Cannot friend yourself'; END IF;

    IF EXISTS (
        SELECT 1 FROM public.friendships f
        WHERE f.user_id = least(v_uid, p_receiver_id)
          AND f.friend_id = greatest(v_uid, p_receiver_id)
    ) THEN
        RETURN;
    END IF;

    INSERT INTO public.friend_requests(sender_id, receiver_id, status)
    VALUES (v_uid, p_receiver_id, 'pending')
    ON CONFLICT (sender_id, receiver_id) DO UPDATE
        SET status = 'pending', updated_at = now();
END;
$$;

-- 4e. accept_friend_request
CREATE OR REPLACE FUNCTION public.accept_friend_request(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_sender_id uuid;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    SELECT sender_id INTO v_sender_id
    FROM public.friend_requests
    WHERE id = p_request_id AND receiver_id = v_uid AND status = 'pending';

    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Friend request not found';
    END IF;

    UPDATE public.friend_requests SET status = 'accepted', updated_at = now()
    WHERE id = p_request_id;

    INSERT INTO public.friendships(user_id, friend_id)
    VALUES (least(v_uid, v_sender_id), greatest(v_uid, v_sender_id))
    ON CONFLICT (user_id, friend_id) DO NOTHING;
END;
$$;

-- 4f. decline_friend_request
CREATE OR REPLACE FUNCTION public.decline_friend_request(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    UPDATE public.friend_requests SET status = 'declined', updated_at = now()
    WHERE id = p_request_id AND receiver_id = v_uid AND status = 'pending';
END;
$$;

-- 4g. create_entry_fee_record
CREATE OR REPLACE FUNCTION public.create_entry_fee_record(
    p_room_id         uuid,
    p_amount          integer,
    p_currency        text,
    p_idempotency_key uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_claimed boolean;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF p_currency <> 'stars' THEN RAISE EXCEPTION 'Unsupported currency: %', p_currency; END IF;
    IF p_amount < 0 THEN RAISE EXCEPTION 'Amount must be non-negative'; END IF;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'entry_fee', v_uid);
    IF NOT v_claimed THEN RETURN; END IF;
    IF p_amount = 0 THEN RETURN; END IF;

    UPDATE public.wallets
    SET stars_balance = stars_balance - p_amount
    WHERE user_id = v_uid AND stars_balance >= p_amount;

    IF NOT FOUND THEN RAISE EXCEPTION 'Insufficient Stars'; END IF;

    INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type, reference_id, idempotency_key)
    VALUES (v_uid, -p_amount, 'unlockPurchase', 'Room entry fee', 'room', p_room_id, p_idempotency_key);
END;
$$;

-- 4h. purchase_unlock_item
CREATE OR REPLACE FUNCTION public.purchase_unlock_item(
    p_item_key        text,
    p_idempotency_key uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_price integer;
    v_claimed boolean;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    SELECT price_stars INTO v_price FROM public.unlock_items WHERE item_key = p_item_key;
    IF v_price IS NULL THEN RAISE EXCEPTION 'Unlock item not found'; END IF;
    IF EXISTS (SELECT 1 FROM public.user_unlocks WHERE user_id = v_uid AND item_key = p_item_key) THEN RETURN; END IF;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'purchase_unlock_item', v_uid);
    IF NOT v_claimed THEN RETURN; END IF;

    UPDATE public.wallets SET stars_balance = stars_balance - v_price
    WHERE user_id = v_uid AND stars_balance >= v_price;
    IF NOT FOUND THEN RAISE EXCEPTION 'Insufficient Stars'; END IF;

    INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type, reference_id, idempotency_key)
    VALUES (v_uid, -v_price, 'unlockPurchase', 'Store unlock purchase', 'unlock_item', NULL, p_idempotency_key);

    INSERT INTO public.user_unlocks(user_id, item_key)
    VALUES (v_uid, p_item_key)
    ON CONFLICT (user_id, item_key) DO NOTHING;
END;
$$;

-- 4i. finalize_game_results
CREATE OR REPLACE FUNCTION public.finalize_game_results(
    p_session_id      uuid,
    p_idempotency_key uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_claimed boolean;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.game_sessions WHERE id = p_session_id AND created_by = v_uid) THEN
        RAISE EXCEPTION 'Only session owner can finalize';
    END IF;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'finalize_game_results', v_uid);
    IF NOT v_claimed THEN RETURN; END IF;

    UPDATE public.game_sessions SET status = 'finalized', updated_at = now()
    WHERE id = p_session_id AND status <> 'finalized';
END;
$$;

-- 4j. distribute_prize_pool
CREATE OR REPLACE FUNCTION public.distribute_prize_pool(
    p_session_id      uuid,
    p_idempotency_key uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_claimed boolean;
    v_row record;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.game_sessions WHERE id = p_session_id AND created_by = v_uid) THEN
        RAISE EXCEPTION 'Only session owner can distribute rewards';
    END IF;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'distribute_prize_pool', v_uid);
    IF NOT v_claimed THEN RETURN; END IF;

    FOR v_row IN
        SELECT gr.user_id, gr.stars_awarded, gr.xp_awarded, gs.game_key
        FROM public.game_results gr
        JOIN public.game_sessions gs ON gs.id = gr.session_id
        WHERE gr.session_id = p_session_id
    LOOP
        IF v_row.stars_awarded > 0 THEN
            UPDATE public.wallets SET stars_balance = stars_balance + v_row.stars_awarded
            WHERE user_id = v_row.user_id;

            INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type, reference_id)
            VALUES (v_row.user_id, v_row.stars_awarded, 'gameReward', 'Game reward payout', 'game_session', p_session_id);
        END IF;

        INSERT INTO public.xp_progress(user_id, game_key, xp, matches_played, wins)
        VALUES (
            v_row.user_id, v_row.game_key, v_row.xp_awarded, 1,
            CASE WHEN EXISTS (
                SELECT 1 FROM public.game_results gr2
                WHERE gr2.session_id = p_session_id AND gr2.user_id = v_row.user_id AND gr2.rank = 1
            ) THEN 1 ELSE 0 END
        )
        ON CONFLICT (user_id, game_key) DO UPDATE
            SET xp = public.xp_progress.xp + excluded.xp,
                matches_played = public.xp_progress.matches_played + 1,
                wins = public.xp_progress.wins + excluded.wins,
                updated_at = now();
    END LOOP;
END;
$$;

-- 4k. delete_my_account_data (App Store requirement)
CREATE OR REPLACE FUNCTION public.delete_my_account_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    DELETE FROM public.game_results WHERE user_id = v_uid;
    DELETE FROM public.room_invites WHERE invited_user_id = v_uid OR inviter_user_id = v_uid;
    DELETE FROM public.room_members WHERE user_id = v_uid;
    DELETE FROM public.rooms WHERE host_user_id = v_uid;
    DELETE FROM public.friend_requests WHERE sender_id = v_uid OR receiver_id = v_uid;
    DELETE FROM public.friendships WHERE user_id = v_uid OR friend_id = v_uid;
    DELETE FROM public.user_unlocks WHERE user_id = v_uid;
    DELETE FROM public.game_unlocks WHERE user_id = v_uid;
    DELETE FROM public.game_trials WHERE user_id = v_uid;
    DELETE FROM public.xp_progress WHERE user_id = v_uid;
    DELETE FROM public.subscriptions WHERE user_id = v_uid;
    DELETE FROM public.star_transactions WHERE user_id = v_uid;
    DELETE FROM public.reward_idempotency WHERE owner_user_id = v_uid;
    DELETE FROM public.wallets WHERE user_id = v_uid;
    DELETE FROM public.profiles WHERE id = v_uid;
END;
$$;

-- ============================================================
-- 4L. CASUAL ROOM RPCs (guest system, security definer)
-- ============================================================

DROP FUNCTION IF EXISTS public.casual_create_room(uuid, text, text, text, uuid, text, text, integer, integer, integer, integer, integer, text);
CREATE OR REPLACE FUNCTION public.casual_create_room(
    p_room_id           uuid,
    p_room_code         text,
    p_game_type         text,
    p_status            text,
    p_host_player_id    uuid,
    p_session_token     text,
    p_host_display_name text,
    p_max_players       integer,
    p_min_players       integer,
    p_settings_rounds   integer,
    p_settings_answer_time integer,
    p_settings_vote_time   integer,
    p_settings_question_pack text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_normalized text;
BEGIN
    v_normalized := lower(trim(both from p_host_display_name));

    INSERT INTO public.casual_rooms (
        id, room_code, game_type, status, host_guest_player_id,
        max_players, min_players,
        settings_rounds, settings_answer_time, settings_vote_time, settings_question_pack
    ) VALUES (
        p_room_id, p_room_code, p_game_type, p_status, p_host_player_id,
        p_max_players, p_min_players,
        p_settings_rounds, p_settings_answer_time, p_settings_vote_time, p_settings_question_pack
    );

    INSERT INTO public.casual_room_players (
        id, room_id, guest_player_id, display_name, normalized_display_name,
        is_host, is_connected, session_token
    ) VALUES (
        gen_random_uuid(), p_room_id, p_host_player_id, p_host_display_name, v_normalized,
        true, true, p_session_token
    );

    RETURN jsonb_build_object('success', true, 'room_id', p_room_id);
END;
$$;

DROP FUNCTION IF EXISTS public.casual_join_room(text, uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.casual_join_room(
    p_room_code       text,
    p_player_id       uuid,
    p_display_name    text,
    p_normalized_name text,
    p_session_token   text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_room          public.casual_rooms%ROWTYPE;
    v_existing      public.casual_room_players%ROWTYPE;
    v_connected_cnt integer;
    v_code          text;
BEGIN
    v_code := upper(trim(both from p_room_code));

    SELECT * INTO v_room FROM public.casual_rooms
    WHERE room_code = v_code FOR UPDATE;

    IF v_room IS NULL THEN RETURN jsonb_build_object('error', 'room_not_found'); END IF;
    IF v_room.status = 'closed' THEN RETURN jsonb_build_object('error', 'room_not_found'); END IF;

    SELECT * INTO v_existing FROM public.casual_room_players
    WHERE room_id = v_room.id AND session_token = p_session_token;

    IF v_existing IS NOT NULL THEN
        UPDATE public.casual_room_players SET is_connected = true, last_seen_at = now()
        WHERE id = v_existing.id;
        RETURN jsonb_build_object('success', true, 'room_id', v_room.id, 'reconnected', true);
    END IF;

    IF v_room.status IN ('starting','in_progress') THEN
        RETURN jsonb_build_object('error', 'room_already_started');
    END IF;

    SELECT count(*) INTO v_connected_cnt FROM public.casual_room_players
    WHERE room_id = v_room.id AND is_connected = true;

    IF v_connected_cnt >= v_room.max_players THEN
        RETURN jsonb_build_object('error', 'room_full');
    END IF;

    IF EXISTS (SELECT 1 FROM public.casual_room_players WHERE room_id = v_room.id AND normalized_display_name = p_normalized_name) THEN
        RETURN jsonb_build_object('error', 'duplicate_name');
    END IF;

    BEGIN
        INSERT INTO public.casual_room_players (
            id, room_id, guest_player_id, display_name, normalized_display_name,
            is_host, is_connected, session_token
        ) VALUES (
            gen_random_uuid(), v_room.id, p_player_id, p_display_name, p_normalized_name,
            false, true, p_session_token
        );
    EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('error', 'duplicate_name');
    END;

    RETURN jsonb_build_object('success', true, 'room_id', v_room.id, 'reconnected', false);
END;
$$;

DROP FUNCTION IF EXISTS public.casual_leave_room(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.casual_leave_room(
    p_room_id       uuid,
    p_player_id     uuid,
    p_session_token text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_player   public.casual_room_players%ROWTYPE;
    v_new_host public.casual_room_players%ROWTYPE;
BEGIN
    SELECT * INTO v_player FROM public.casual_room_players
    WHERE room_id = p_room_id AND guest_player_id = p_player_id AND session_token = p_session_token;

    IF v_player IS NULL THEN RETURN jsonb_build_object('error', 'player_not_found'); END IF;

    DELETE FROM public.casual_room_players WHERE id = v_player.id;

    IF v_player.is_host THEN
        SELECT * INTO v_new_host FROM public.casual_room_players
        WHERE room_id = p_room_id AND is_connected = true
        ORDER BY joined_at ASC LIMIT 1;

        IF v_new_host IS NOT NULL THEN
            UPDATE public.casual_room_players SET is_host = true WHERE id = v_new_host.id;
            UPDATE public.casual_rooms SET host_guest_player_id = v_new_host.guest_player_id WHERE id = p_room_id;
            RETURN jsonb_build_object('success', true, 'new_host_id', v_new_host.guest_player_id);
        ELSE
            UPDATE public.casual_rooms SET status = 'closed' WHERE id = p_room_id;
            RETURN jsonb_build_object('success', true, 'room_closed', true);
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true);
END;
$$;

DROP FUNCTION IF EXISTS public.casual_kick_player(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.casual_kick_player(
    p_room_id            uuid,
    p_target_player_id   uuid,
    p_host_session_token text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_host public.casual_room_players%ROWTYPE;
BEGIN
    SELECT * INTO v_host FROM public.casual_room_players
    WHERE room_id = p_room_id AND session_token = p_host_session_token AND is_host = true;

    IF v_host IS NULL THEN RETURN jsonb_build_object('error', 'not_host'); END IF;
    IF v_host.guest_player_id = p_target_player_id THEN RETURN jsonb_build_object('error', 'cannot_kick_self'); END IF;

    DELETE FROM public.casual_room_players
    WHERE room_id = p_room_id AND guest_player_id = p_target_player_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

DROP FUNCTION IF EXISTS public.casual_update_room_status(uuid, text, text);
CREATE OR REPLACE FUNCTION public.casual_update_room_status(
    p_room_id            uuid,
    p_status             text,
    p_host_session_token text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_host public.casual_room_players%ROWTYPE;
BEGIN
    SELECT * INTO v_host FROM public.casual_room_players
    WHERE room_id = p_room_id AND session_token = p_host_session_token AND is_host = true;

    IF v_host IS NULL THEN RETURN jsonb_build_object('error', 'not_host'); END IF;

    UPDATE public.casual_rooms
    SET status = p_status,
        started_at = CASE WHEN p_status IN ('starting','in_progress') THEN now() ELSE started_at END
    WHERE id = p_room_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

DROP FUNCTION IF EXISTS public.casual_update_room_settings(uuid, text, integer, integer, integer, text);
CREATE OR REPLACE FUNCTION public.casual_update_room_settings(
    p_room_id            uuid,
    p_host_session_token text,
    p_rounds             integer,
    p_answer_time        integer,
    p_vote_time          integer,
    p_question_pack      text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_host public.casual_room_players%ROWTYPE;
BEGIN
    SELECT * INTO v_host FROM public.casual_room_players
    WHERE room_id = p_room_id AND session_token = p_host_session_token AND is_host = true;

    IF v_host IS NULL THEN RETURN jsonb_build_object('error', 'not_host'); END IF;

    UPDATE public.casual_rooms
    SET settings_rounds = p_rounds,
        settings_answer_time = p_answer_time,
        settings_vote_time = p_vote_time,
        settings_question_pack = p_question_pack
    WHERE id = p_room_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

DROP FUNCTION IF EXISTS public.casual_heartbeat(uuid, text);
CREATE OR REPLACE FUNCTION public.casual_heartbeat(
    p_room_id       uuid,
    p_session_token text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.casual_room_players
    SET last_seen_at = now(), is_connected = true
    WHERE room_id = p_room_id AND session_token = p_session_token;
    IF NOT FOUND THEN RETURN jsonb_build_object('error', 'player_not_found'); END IF;
    RETURN jsonb_build_object('success', true);
END;
$$;

DROP FUNCTION IF EXISTS public.casual_mark_disconnected(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.casual_mark_disconnected(
    p_room_id       uuid,
    p_player_id     uuid,
    p_session_token text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.casual_room_players
    SET is_connected = false, last_seen_at = now()
    WHERE room_id = p_room_id AND guest_player_id = p_player_id AND session_token = p_session_token;
    RETURN jsonb_build_object('success', true);
END;
$$;

DROP FUNCTION IF EXISTS public.casual_cleanup_stale_players(uuid, integer);
CREATE OR REPLACE FUNCTION public.casual_cleanup_stale_players(
    p_room_id       uuid,
    p_grace_seconds integer DEFAULT 120
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_stale_count integer;
BEGIN
    UPDATE public.casual_room_players
    SET is_connected = false
    WHERE room_id = p_room_id
      AND is_connected = true
      AND last_seen_at < now() - (p_grace_seconds || ' seconds')::interval;
    GET DIAGNOSTICS v_stale_count = ROW_COUNT;
    RETURN jsonb_build_object('success', true, 'stale_marked', v_stale_count);
END;
$$;

-- ============================================================
-- 5. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.star_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xp_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_trials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.unlock_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_idempotency ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.casual_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.casual_room_players ENABLE ROW LEVEL SECURITY;

-- profiles
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update" ON public.profiles;
DROP POLICY IF EXISTS "profiles_delete" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_authenticated" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_self" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_self" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_delete" ON public.profiles FOR DELETE USING (auth.uid() = id);

-- wallets
DROP POLICY IF EXISTS "wallets_select_own" ON public.wallets;
DROP POLICY IF EXISTS "wallets_insert_own" ON public.wallets;
CREATE POLICY "wallets_select_own" ON public.wallets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "wallets_insert_own" ON public.wallets FOR INSERT WITH CHECK (auth.uid() = user_id AND stars_balance = 100);

-- star_transactions
DROP POLICY IF EXISTS "star_transactions_select_own" ON public.star_transactions;
CREATE POLICY "star_transactions_select_own" ON public.star_transactions FOR SELECT USING (auth.uid() = user_id);

-- xp_progress
DROP POLICY IF EXISTS "xp_progress_select_own" ON public.xp_progress;
CREATE POLICY "xp_progress_select_own" ON public.xp_progress FOR SELECT USING (auth.uid() = user_id);

-- game_trials
DROP POLICY IF EXISTS "game_trials_select_own" ON public.game_trials;
CREATE POLICY "game_trials_select_own" ON public.game_trials FOR SELECT USING (auth.uid() = user_id);

-- game_unlocks
DROP POLICY IF EXISTS "game_unlocks_select_own" ON public.game_unlocks;
CREATE POLICY "game_unlocks_select_own" ON public.game_unlocks FOR SELECT USING (auth.uid() = user_id);

-- subscriptions
DROP POLICY IF EXISTS "subscriptions_select_own" ON public.subscriptions;
CREATE POLICY "subscriptions_select_own" ON public.subscriptions FOR SELECT USING (auth.uid() = user_id);

-- friendships
DROP POLICY IF EXISTS "friendships_select" ON public.friendships;
DROP POLICY IF EXISTS "friendships_delete" ON public.friendships;
DROP POLICY IF EXISTS "friendships_select_participant" ON public.friendships;
DROP POLICY IF EXISTS "friendships_delete_participant" ON public.friendships;
CREATE POLICY "friendships_select" ON public.friendships FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY "friendships_delete" ON public.friendships FOR DELETE USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- friend_requests
DROP POLICY IF EXISTS "fr_select" ON public.friend_requests;
DROP POLICY IF EXISTS "friend_requests_select_participant" ON public.friend_requests;
CREATE POLICY "fr_select" ON public.friend_requests FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- rooms
DROP POLICY IF EXISTS "rooms_select" ON public.rooms;
DROP POLICY IF EXISTS "rooms_insert" ON public.rooms;
DROP POLICY IF EXISTS "rooms_update" ON public.rooms;
DROP POLICY IF EXISTS "rooms_select_visible" ON public.rooms;
DROP POLICY IF EXISTS "rooms_insert_host" ON public.rooms;
DROP POLICY IF EXISTS "rooms_update_host" ON public.rooms;
CREATE POLICY "rooms_select" ON public.rooms FOR SELECT USING (true);
CREATE POLICY "rooms_insert" ON public.rooms FOR INSERT WITH CHECK (auth.uid() = host_user_id);
CREATE POLICY "rooms_update" ON public.rooms FOR UPDATE USING (auth.uid() = host_user_id);

-- room_members
DROP POLICY IF EXISTS "rm_select" ON public.room_members;
DROP POLICY IF EXISTS "rm_insert" ON public.room_members;
DROP POLICY IF EXISTS "rm_update" ON public.room_members;
DROP POLICY IF EXISTS "rm_delete" ON public.room_members;
DROP POLICY IF EXISTS "room_members_select_visible" ON public.room_members;
DROP POLICY IF EXISTS "room_members_insert_self" ON public.room_members;
DROP POLICY IF EXISTS "room_members_update_self_or_host" ON public.room_members;
DROP POLICY IF EXISTS "room_members_delete_self_or_host" ON public.room_members;
CREATE POLICY "rm_select" ON public.room_members FOR SELECT USING (true);
CREATE POLICY "rm_insert" ON public.room_members FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "rm_update" ON public.room_members FOR UPDATE USING (auth.uid() = user_id OR public.is_room_host(room_id, auth.uid()));
CREATE POLICY "rm_delete" ON public.room_members FOR DELETE USING (auth.uid() = user_id OR public.is_room_host(room_id, auth.uid()));

-- room_invites
DROP POLICY IF EXISTS "ri_select" ON public.room_invites;
DROP POLICY IF EXISTS "ri_insert" ON public.room_invites;
DROP POLICY IF EXISTS "ri_update" ON public.room_invites;
DROP POLICY IF EXISTS "room_invites_select_participant" ON public.room_invites;
DROP POLICY IF EXISTS "room_invites_insert_inviter" ON public.room_invites;
DROP POLICY IF EXISTS "room_invites_update_participant" ON public.room_invites;
CREATE POLICY "ri_select" ON public.room_invites FOR SELECT USING (auth.uid() = inviter_user_id OR auth.uid() = invited_user_id);
CREATE POLICY "ri_insert" ON public.room_invites FOR INSERT WITH CHECK (auth.uid() = inviter_user_id);
CREATE POLICY "ri_update" ON public.room_invites FOR UPDATE USING (auth.uid() = inviter_user_id OR auth.uid() = invited_user_id);

-- game_sessions
DROP POLICY IF EXISTS "gs_select" ON public.game_sessions;
DROP POLICY IF EXISTS "gs_insert" ON public.game_sessions;
DROP POLICY IF EXISTS "gs_update" ON public.game_sessions;
DROP POLICY IF EXISTS "game_sessions_select_visible" ON public.game_sessions;
DROP POLICY IF EXISTS "game_sessions_insert_room_member" ON public.game_sessions;
DROP POLICY IF EXISTS "game_sessions_update_creator" ON public.game_sessions;
CREATE POLICY "gs_select" ON public.game_sessions FOR SELECT USING (true);
CREATE POLICY "gs_insert" ON public.game_sessions FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "gs_update" ON public.game_sessions FOR UPDATE USING (auth.uid() = created_by);

-- game_results
DROP POLICY IF EXISTS "gr_select" ON public.game_results;
DROP POLICY IF EXISTS "gr_insert" ON public.game_results;
DROP POLICY IF EXISTS "gr_update" ON public.game_results;
DROP POLICY IF EXISTS "game_results_select_room_member" ON public.game_results;
DROP POLICY IF EXISTS "game_results_insert_creator" ON public.game_results;
DROP POLICY IF EXISTS "game_results_update_creator" ON public.game_results;
CREATE POLICY "gr_select" ON public.game_results FOR SELECT USING (true);
CREATE POLICY "gr_insert" ON public.game_results FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.game_sessions gs WHERE gs.id = session_id AND gs.created_by = auth.uid())
);
CREATE POLICY "gr_update" ON public.game_results FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.game_sessions gs WHERE gs.id = session_id AND gs.created_by = auth.uid())
);

-- unlock_items
DROP POLICY IF EXISTS "ui_select" ON public.unlock_items;
DROP POLICY IF EXISTS "unlock_items_select_all" ON public.unlock_items;
CREATE POLICY "ui_select" ON public.unlock_items FOR SELECT USING (true);

-- user_unlocks
DROP POLICY IF EXISTS "uu_select_own" ON public.user_unlocks;
DROP POLICY IF EXISTS "user_unlocks_select_own" ON public.user_unlocks;
CREATE POLICY "uu_select_own" ON public.user_unlocks FOR SELECT USING (auth.uid() = user_id);

-- reward_idempotency
DROP POLICY IF EXISTS "reward_idempotency_owner_only" ON public.reward_idempotency;
CREATE POLICY "reward_idempotency_owner_only" ON public.reward_idempotency FOR SELECT USING (auth.uid() = owner_user_id);

-- casual_rooms (guest access via anon)
DROP POLICY IF EXISTS "casual_rooms_select" ON public.casual_rooms;
DROP POLICY IF EXISTS "casual_rooms_insert" ON public.casual_rooms;
DROP POLICY IF EXISTS "casual_rooms_update" ON public.casual_rooms;
DROP POLICY IF EXISTS "casual_rooms_delete" ON public.casual_rooms;
CREATE POLICY "casual_rooms_select" ON public.casual_rooms FOR SELECT USING (true);

-- casual_room_players (guest access via anon)
DROP POLICY IF EXISTS "casual_room_players_select" ON public.casual_room_players;
DROP POLICY IF EXISTS "casual_room_players_insert" ON public.casual_room_players;
DROP POLICY IF EXISTS "casual_room_players_update" ON public.casual_room_players;
DROP POLICY IF EXISTS "casual_room_players_delete" ON public.casual_room_players;
CREATE POLICY "casual_room_players_select" ON public.casual_room_players FOR SELECT USING (true);

-- ============================================================
-- 6. REALTIME
-- ============================================================

DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_members; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.room_invites; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.friendships; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.friend_requests; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.game_sessions; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.wallets; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.casual_rooms; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.casual_room_players; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- 7. GRANTS
-- ============================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;

-- ============================================================
-- 8. SEED: Store items
-- ============================================================

INSERT INTO public.unlock_items (item_key, title, description, price_stars)
VALUES
    ('memory_path', 'Memory Path', 'Permanent unlock for Memory Path', 120),
    ('pass_guess', 'Pass & Guess', 'Permanent unlock for Pass & Guess', 120),
    ('guess_the_fake_answer', 'Guess the Fake Answer', 'Permanent unlock for Guess the Fake Answer', 120),
    ('reverse_singing', 'Reverse Singing', 'Permanent unlock for Reverse Singing', 120)
ON CONFLICT (item_key) DO NOTHING;
