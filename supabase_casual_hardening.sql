-- ============================================================
-- Casual Guest Room System — Hardening Migration
-- Run in Supabase SQL Editor AFTER the base schema.
-- Idempotent: safe to re-run.
-- ============================================================

-- ============================================================
-- 1. TABLES (idempotent create)
-- ============================================================

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

-- ============================================================
-- 2. CONSTRAINTS (idempotent add)
-- ============================================================

-- UNIQUE room_code (prevents code collisions)
DO $$ BEGIN
    ALTER TABLE public.casual_rooms ADD CONSTRAINT uq_casual_rooms_room_code UNIQUE (room_code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- UNIQUE (room_id, normalized_display_name) — race-safe duplicate name prevention
DO $$ BEGIN
    ALTER TABLE public.casual_room_players
        ADD CONSTRAINT uq_casual_player_name_per_room UNIQUE (room_id, normalized_display_name);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- UNIQUE session_token per room (prevents duplicate reconnect entries)
DO $$ BEGIN
    ALTER TABLE public.casual_room_players
        ADD CONSTRAINT uq_casual_player_session_per_room UNIQUE (room_id, session_token);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- 3. INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_casual_rooms_room_code
    ON public.casual_rooms (room_code);

CREATE INDEX IF NOT EXISTS idx_casual_rooms_status
    ON public.casual_rooms (status) WHERE status IN ('waiting', 'starting', 'in_progress');

CREATE INDEX IF NOT EXISTS idx_casual_room_players_room_id
    ON public.casual_room_players (room_id);

CREATE INDEX IF NOT EXISTS idx_casual_room_players_session_token
    ON public.casual_room_players (session_token);

CREATE INDEX IF NOT EXISTS idx_casual_room_players_connected
    ON public.casual_room_players (room_id, is_connected);

CREATE INDEX IF NOT EXISTS idx_casual_room_players_last_seen
    ON public.casual_room_players (last_seen_at);

-- ============================================================
-- 4. ROW LEVEL SECURITY
-- ============================================================
-- Guest system uses anon key (no auth.uid()).
-- RLS: SELECT open, all mutations via security-definer RPCs only.

ALTER TABLE public.casual_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.casual_room_players ENABLE ROW LEVEL SECURITY;

-- Drop old permissive policies if any
DROP POLICY IF EXISTS "casual_rooms_select" ON public.casual_rooms;
DROP POLICY IF EXISTS "casual_rooms_insert" ON public.casual_rooms;
DROP POLICY IF EXISTS "casual_rooms_update" ON public.casual_rooms;
DROP POLICY IF EXISTS "casual_rooms_delete" ON public.casual_rooms;
DROP POLICY IF EXISTS "casual_room_players_select" ON public.casual_room_players;
DROP POLICY IF EXISTS "casual_room_players_insert" ON public.casual_room_players;
DROP POLICY IF EXISTS "casual_room_players_update" ON public.casual_room_players;
DROP POLICY IF EXISTS "casual_room_players_delete" ON public.casual_room_players;

-- SELECT only — anyone can read room state (needed for join/lobby)
CREATE POLICY "casual_rooms_select"
    ON public.casual_rooms FOR SELECT USING (true);

CREATE POLICY "casual_room_players_select"
    ON public.casual_room_players FOR SELECT USING (true);

-- No INSERT/UPDATE/DELETE policies = direct mutations blocked for anon/authenticated.
-- All mutations go through security-definer RPCs below.

-- ============================================================
-- 5. RPC: casual_create_room
-- ============================================================

DROP FUNCTION IF EXISTS public.casual_create_room(uuid, text, text, text, uuid, text, integer, integer, integer, integer, integer, text);
CREATE OR REPLACE FUNCTION public.casual_create_room(
    p_room_id         uuid,
    p_room_code       text,
    p_game_type       text,
    p_status          text,
    p_host_player_id  uuid,
    p_session_token   text,
    p_host_display_name text,
    p_max_players     integer,
    p_min_players     integer,
    p_settings_rounds integer,
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

-- ============================================================
-- 6. RPC: casual_join_room
-- Atomic: validates room, checks capacity, checks duplicate name,
-- handles reconnect, inserts player — all in one transaction.
-- ============================================================

DROP FUNCTION IF EXISTS public.casual_join_room(text, uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.casual_join_room(
    p_room_code      text,
    p_player_id      uuid,
    p_display_name   text,
    p_normalized_name text,
    p_session_token  text
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

    -- Lock the room row to prevent races
    SELECT * INTO v_room
    FROM public.casual_rooms
    WHERE room_code = v_code
    FOR UPDATE;

    IF v_room IS NULL THEN
        RETURN jsonb_build_object('error', 'room_not_found');
    END IF;

    IF v_room.status = 'closed' THEN
        RETURN jsonb_build_object('error', 'room_not_found');
    END IF;

    -- Check reconnect by session_token
    SELECT * INTO v_existing
    FROM public.casual_room_players
    WHERE room_id = v_room.id AND session_token = p_session_token;

    IF v_existing IS NOT NULL THEN
        UPDATE public.casual_room_players
        SET is_connected = true, last_seen_at = now()
        WHERE id = v_existing.id;
        RETURN jsonb_build_object('success', true, 'room_id', v_room.id, 'reconnected', true);
    END IF;

    -- Not a reconnect — check if game already started
    IF v_room.status IN ('starting', 'in_progress') THEN
        RETURN jsonb_build_object('error', 'room_already_started');
    END IF;

    -- Check capacity
    SELECT count(*) INTO v_connected_cnt
    FROM public.casual_room_players
    WHERE room_id = v_room.id AND is_connected = true;

    IF v_connected_cnt >= v_room.max_players THEN
        RETURN jsonb_build_object('error', 'room_full');
    END IF;

    -- Check duplicate name (constraint will also catch, but give nice error)
    IF EXISTS (
        SELECT 1 FROM public.casual_room_players
        WHERE room_id = v_room.id AND normalized_display_name = p_normalized_name
    ) THEN
        RETURN jsonb_build_object('error', 'duplicate_name');
    END IF;

    -- Insert player (UNIQUE constraint is final safety net)
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

-- ============================================================
-- 7. RPC: casual_leave_room
-- Handles host reassignment or room closure.
-- ============================================================

DROP FUNCTION IF EXISTS public.casual_leave_room(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.casual_leave_room(
    p_room_id        uuid,
    p_player_id      uuid,
    p_session_token  text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_player    public.casual_room_players%ROWTYPE;
    v_new_host  public.casual_room_players%ROWTYPE;
BEGIN
    -- Verify the player owns this session
    SELECT * INTO v_player
    FROM public.casual_room_players
    WHERE room_id = p_room_id
      AND guest_player_id = p_player_id
      AND session_token = p_session_token;

    IF v_player IS NULL THEN
        RETURN jsonb_build_object('error', 'player_not_found');
    END IF;

    -- Remove the player
    DELETE FROM public.casual_room_players WHERE id = v_player.id;

    IF v_player.is_host THEN
        -- Try to assign new host (earliest joined connected player)
        SELECT * INTO v_new_host
        FROM public.casual_room_players
        WHERE room_id = p_room_id AND is_connected = true
        ORDER BY joined_at ASC
        LIMIT 1;

        IF v_new_host IS NOT NULL THEN
            UPDATE public.casual_room_players SET is_host = true WHERE id = v_new_host.id;
            UPDATE public.casual_rooms SET host_guest_player_id = v_new_host.guest_player_id WHERE id = p_room_id;
            RETURN jsonb_build_object('success', true, 'new_host_id', v_new_host.guest_player_id);
        ELSE
            -- No players left, close room
            UPDATE public.casual_rooms SET status = 'closed' WHERE id = p_room_id;
            RETURN jsonb_build_object('success', true, 'room_closed', true);
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- 8. RPC: casual_kick_player
-- Only the host (verified by session_token) can kick.
-- ============================================================

DROP FUNCTION IF EXISTS public.casual_kick_player(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.casual_kick_player(
    p_room_id           uuid,
    p_target_player_id  uuid,
    p_host_session_token text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_host public.casual_room_players%ROWTYPE;
BEGIN
    -- Verify caller is host
    SELECT * INTO v_host
    FROM public.casual_room_players
    WHERE room_id = p_room_id
      AND session_token = p_host_session_token
      AND is_host = true;

    IF v_host IS NULL THEN
        RETURN jsonb_build_object('error', 'not_host');
    END IF;

    -- Cannot kick yourself
    IF v_host.guest_player_id = p_target_player_id THEN
        RETURN jsonb_build_object('error', 'cannot_kick_self');
    END IF;

    DELETE FROM public.casual_room_players
    WHERE room_id = p_room_id AND guest_player_id = p_target_player_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- 9. RPC: casual_update_room_status
-- Only host can change status.
-- ============================================================

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
    SELECT * INTO v_host
    FROM public.casual_room_players
    WHERE room_id = p_room_id
      AND session_token = p_host_session_token
      AND is_host = true;

    IF v_host IS NULL THEN
        RETURN jsonb_build_object('error', 'not_host');
    END IF;

    UPDATE public.casual_rooms
    SET status = p_status,
        started_at = CASE WHEN p_status IN ('starting', 'in_progress') THEN now() ELSE started_at END
    WHERE id = p_room_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- 10. RPC: casual_update_room_settings
-- Only host can change settings.
-- ============================================================

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
    SELECT * INTO v_host
    FROM public.casual_room_players
    WHERE room_id = p_room_id
      AND session_token = p_host_session_token
      AND is_host = true;

    IF v_host IS NULL THEN
        RETURN jsonb_build_object('error', 'not_host');
    END IF;

    UPDATE public.casual_rooms
    SET settings_rounds = p_rounds,
        settings_answer_time = p_answer_time,
        settings_vote_time = p_vote_time,
        settings_question_pack = p_question_pack
    WHERE id = p_room_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- 11. RPC: casual_heartbeat
-- Updates last_seen_at, verified by session_token.
-- ============================================================

DROP FUNCTION IF EXISTS public.casual_heartbeat(uuid, text);
CREATE OR REPLACE FUNCTION public.casual_heartbeat(
    p_room_id        uuid,
    p_session_token  text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.casual_room_players
    SET last_seen_at = now(), is_connected = true
    WHERE room_id = p_room_id AND session_token = p_session_token;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'player_not_found');
    END IF;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- 12. RPC: casual_mark_disconnected
-- ============================================================

DROP FUNCTION IF EXISTS public.casual_mark_disconnected(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.casual_mark_disconnected(
    p_room_id        uuid,
    p_player_id      uuid,
    p_session_token  text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.casual_room_players
    SET is_connected = false, last_seen_at = now()
    WHERE room_id = p_room_id
      AND guest_player_id = p_player_id
      AND session_token = p_session_token;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- 13. RPC: casual_cleanup_stale_players
-- Marks players disconnected if last_seen > grace period.
-- Call periodically (e.g. from host every 30s, or a cron).
-- ============================================================

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
-- 14. REALTIME (for DB change listeners)
-- ============================================================

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.casual_rooms;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.casual_room_players;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- 15. GRANTS for RPCs (anon + authenticated can call)
-- ============================================================
-- The base schema already has:
--   grant execute on all functions in schema public to anon, authenticated, service_role;
-- So RPCs are callable. SELECT on tables is allowed via RLS policies above.
-- Direct INSERT/UPDATE/DELETE is blocked by RLS (no policies for those).
