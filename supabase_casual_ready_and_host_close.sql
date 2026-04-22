-- ============================================================
-- Casual Rooms — Host-leave closes room + Ready-check persistence
-- Idempotent: safe to re-run.
-- Run in Supabase SQL Editor.
-- ============================================================

-- ============================================================
-- 1. Add ready_confirmed_at column to casual_room_players
-- ============================================================

ALTER TABLE public.casual_room_players
    ADD COLUMN IF NOT EXISTS ready_confirmed_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_casual_room_players_ready
    ON public.casual_room_players (room_id, ready_confirmed_at);

-- ============================================================
-- 2. RPC: casual_set_ready
-- Player marks themselves ready for the start-game confirmation.
-- Verified by session_token.
-- ============================================================

DROP FUNCTION IF EXISTS public.casual_set_ready(uuid, text, boolean);
CREATE OR REPLACE FUNCTION public.casual_set_ready(
    p_room_id       uuid,
    p_session_token text,
    p_ready         boolean
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.casual_room_players
    SET ready_confirmed_at = CASE WHEN p_ready THEN now() ELSE NULL END,
        last_seen_at = now(),
        is_connected = true
    WHERE room_id = p_room_id
      AND session_token = p_session_token;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'player_not_found');
    END IF;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- 3. RPC: casual_clear_all_ready
-- Host resets all ready flags (e.g. when starting a new round
-- or cancelling the ready-check).
-- ============================================================

DROP FUNCTION IF EXISTS public.casual_clear_all_ready(uuid, text);
CREATE OR REPLACE FUNCTION public.casual_clear_all_ready(
    p_room_id            uuid,
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

    UPDATE public.casual_room_players
    SET ready_confirmed_at = NULL
    WHERE room_id = p_room_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- 4. REPLACE casual_leave_room
-- Host leaving now ALWAYS closes the room (status='closed')
-- regardless of other connected players. Code becomes un-joinable.
-- Non-host leave behaves as before (just removes the player).
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
    v_player public.casual_room_players%ROWTYPE;
BEGIN
    SELECT * INTO v_player
    FROM public.casual_room_players
    WHERE room_id = p_room_id
      AND guest_player_id = p_player_id
      AND session_token = p_session_token;

    IF v_player IS NULL THEN
        RETURN jsonb_build_object('error', 'player_not_found');
    END IF;

    IF v_player.is_host THEN
        -- Host leaving → close the room entirely.
        -- Keep player rows so guests can see the 'closed' state before their
        -- own disconnect cleanup, but mark host as disconnected.
        UPDATE public.casual_rooms
        SET status = 'closed'
        WHERE id = p_room_id;

        UPDATE public.casual_room_players
        SET is_connected = false, last_seen_at = now()
        WHERE id = v_player.id;

        RETURN jsonb_build_object('success', true, 'room_closed', true);
    END IF;

    -- Guest leave → just remove their row
    DELETE FROM public.casual_room_players WHERE id = v_player.id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- 5. GRANTS
-- ============================================================

GRANT EXECUTE ON FUNCTION public.casual_set_ready(uuid, text, boolean) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.casual_clear_all_ready(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.casual_leave_room(uuid, uuid, text) TO anon, authenticated;
