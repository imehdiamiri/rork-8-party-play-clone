-- ============================================================
-- Casual Multiplayer — Authoritative Turn + Per-Player Rematch
-- Run in Supabase SQL Editor AFTER supabase_casual_hardening.sql.
-- Idempotent: safe to re-run.
-- ============================================================

-- 1. Columns

ALTER TABLE public.casual_rooms
    ADD COLUMN IF NOT EXISTS active_turn_index integer NOT NULL DEFAULT 0;
ALTER TABLE public.casual_rooms
    ADD COLUMN IF NOT EXISTS active_player_id uuid;
ALTER TABLE public.casual_rooms
    ADD COLUMN IF NOT EXISTS turn_version integer NOT NULL DEFAULT 0;

ALTER TABLE public.casual_room_players
    ADD COLUMN IF NOT EXISTS rematch_ready_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_casual_room_players_rematch_ready
    ON public.casual_room_players (room_id, rematch_ready_at);

-- 2. Authoritative turn-advance RPC (CAS-protected)
-- Only the caller whose session_token resolves to the current active player
-- can advance. Two racing clients cannot both succeed; stale clients with
-- an old expected_index are rejected.

CREATE OR REPLACE FUNCTION public.casual_claim_turn_advance(
    p_room_id uuid,
    p_session_token text,
    p_expected_index integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room             public.casual_rooms%ROWTYPE;
    v_player           public.casual_room_players%ROWTYPE;
    v_player_index     integer;
    v_connected_count  integer;
    v_expected_position integer;
BEGIN
    SELECT * INTO v_room FROM public.casual_rooms WHERE id = p_room_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'room_not_found');
    END IF;

    SELECT * INTO v_player
    FROM public.casual_room_players
    WHERE room_id = p_room_id AND session_token = p_session_token
    LIMIT 1;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'player_not_in_room');
    END IF;

    -- CAS: expected_index must match server's current active_turn_index
    IF v_room.active_turn_index <> p_expected_index THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'stale_turn',
            'server_index', v_room.active_turn_index,
            'active_player_id', v_room.active_player_id
        );
    END IF;

    -- Position check: caller must be the player whose turn it is.
    -- Uses the deterministic join order as the turn order.
    SELECT COUNT(*) INTO v_connected_count
    FROM public.casual_room_players
    WHERE room_id = p_room_id;

    IF v_connected_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'no_players');
    END IF;

    SELECT idx - 1 INTO v_player_index FROM (
        SELECT id, ROW_NUMBER() OVER (ORDER BY joined_at ASC, id ASC) AS idx
        FROM public.casual_room_players
        WHERE room_id = p_room_id
    ) ranked
    WHERE ranked.id = v_player.id;

    v_expected_position := p_expected_index % v_connected_count;

    IF v_player_index IS NULL OR v_player_index <> v_expected_position THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'not_active_player',
            'server_index', v_room.active_turn_index,
            'active_player_id', v_room.active_player_id
        );
    END IF;

    UPDATE public.casual_rooms
       SET active_turn_index = p_expected_index + 1,
           active_player_id  = (
               SELECT guest_player_id FROM (
                   SELECT guest_player_id,
                          ROW_NUMBER() OVER (ORDER BY joined_at ASC, id ASC) AS idx
                   FROM public.casual_room_players
                   WHERE room_id = p_room_id
               ) r
               WHERE r.idx - 1 = (p_expected_index + 1) % v_connected_count
           ),
           turn_version = turn_version + 1
     WHERE id = p_room_id;

    SELECT * INTO v_room FROM public.casual_rooms WHERE id = p_room_id;

    RETURN jsonb_build_object(
        'success', true,
        'server_index', v_room.active_turn_index,
        'active_player_id', v_room.active_player_id,
        'turn_version', v_room.turn_version
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.casual_claim_turn_advance(uuid, text, integer) TO anon, authenticated;

-- 3. Reset turn counter (called at match start / rematch start)

CREATE OR REPLACE FUNCTION public.casual_reset_turn(
    p_room_id uuid,
    p_host_session_token text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_host boolean;
    v_first_player uuid;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.casual_room_players
         WHERE room_id = p_room_id
           AND session_token = p_host_session_token
           AND is_host = true
    ) INTO v_is_host;

    IF NOT v_is_host THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_host');
    END IF;

    SELECT guest_player_id INTO v_first_player
    FROM public.casual_room_players
    WHERE room_id = p_room_id
    ORDER BY joined_at ASC, id ASC
    LIMIT 1;

    UPDATE public.casual_rooms
       SET active_turn_index = 0,
           active_player_id  = v_first_player,
           turn_version      = turn_version + 1
     WHERE id = p_room_id;

    RETURN jsonb_build_object('success', true, 'active_player_id', v_first_player);
END;
$$;

GRANT EXECUTE ON FUNCTION public.casual_reset_turn(uuid, text) TO anon, authenticated;

-- 4. Per-player rematch readiness (DB-authoritative, no host mediation)

CREATE OR REPLACE FUNCTION public.casual_set_rematch_ready(
    p_room_id uuid,
    p_session_token text,
    p_ready boolean
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rows int;
BEGIN
    UPDATE public.casual_room_players
       SET rematch_ready_at = CASE WHEN p_ready THEN now() ELSE NULL END,
           last_seen_at = now()
     WHERE room_id = p_room_id
       AND session_token = p_session_token;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'player_not_in_room');
    END IF;
    RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.casual_set_rematch_ready(uuid, text, boolean) TO anon, authenticated;

-- 5. Clear all rematch flags (called by host when starting rematch)

CREATE OR REPLACE FUNCTION public.casual_clear_all_rematch(
    p_room_id uuid,
    p_host_session_token text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_host boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.casual_room_players
         WHERE room_id = p_room_id
           AND session_token = p_host_session_token
           AND is_host = true
    ) INTO v_is_host;

    IF NOT v_is_host THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_host');
    END IF;

    UPDATE public.casual_room_players
       SET rematch_ready_at = NULL
     WHERE room_id = p_room_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.casual_clear_all_rematch(uuid, text) TO anon, authenticated;
