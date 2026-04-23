-- =============================================================================
-- Multiplayer telemetry table (mp_events)
-- Lightweight append-only log for 888Play multiplayer observability.
-- Apply once in Supabase SQL Editor.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.mp_events (
    id                   bigserial PRIMARY KEY,
    created_at           timestamptz NOT NULL DEFAULT now(),
    event                text NOT NULL,
    session_id           uuid,
    room_id              uuid,
    match_id             uuid,
    player_id            uuid,
    device_id            text,
    user_role            text,
    game_type            text,
    app_version          text,
    platform             text,
    room_status          text,
    session_phase        text,
    state_version        int,
    active_player_id     uuid,
    active_turn_index    int,
    player_count         int,
    source               text,
    network_state        text,
    success              boolean,
    failure_reason       text,
    latency_ms           int,
    session_duration_ms  bigint,
    turn_duration_ms     bigint,
    turn_rpc_latency_ms  int,
    phase_at_exit        text,
    session_outcome      text,
    session_token_hash   text,
    props                jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_mp_events_created_at
    ON public.mp_events (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mp_events_event_created_at
    ON public.mp_events (event, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mp_events_room_id
    ON public.mp_events (room_id);
CREATE INDEX IF NOT EXISTS idx_mp_events_session_id
    ON public.mp_events (session_id);
CREATE INDEX IF NOT EXISTS idx_mp_events_device_id
    ON public.mp_events (device_id);
CREATE INDEX IF NOT EXISTS idx_mp_events_session_outcome
    ON public.mp_events (session_outcome);

-- Enable RLS. Clients should only ever INSERT. No reads from app.
ALTER TABLE public.mp_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mp_events_insert_anyone" ON public.mp_events;
CREATE POLICY "mp_events_insert_anyone"
    ON public.mp_events
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

-- Reads restricted to service role (dashboards / SQL editor).
DROP POLICY IF EXISTS "mp_events_select_none" ON public.mp_events;
CREATE POLICY "mp_events_select_none"
    ON public.mp_events
    FOR SELECT
    USING (false);

GRANT INSERT ON public.mp_events TO anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.mp_events_id_seq TO anon, authenticated;

-- =============================================================================
-- Saved analytics views
-- =============================================================================

-- 1) Room funnel: creation -> join -> ready -> start -> results
CREATE OR REPLACE VIEW public.mp_room_funnel AS
SELECT
    date_trunc('day', created_at)                                          AS day,
    count(*) FILTER (WHERE event = 'room_create_succeeded')                AS rooms_created,
    count(*) FILTER (WHERE event = 'room_join_succeeded')                  AS joins_succeeded,
    count(*) FILTER (WHERE event = 'room_join_failed')                     AS joins_failed,
    count(*) FILTER (WHERE event = 'ready_check_started')                  AS ready_checks,
    count(*) FILTER (WHERE event = 'player_ready_submitted')               AS ready_submits,
    count(*) FILTER (WHERE event = 'match_start_succeeded')                AS match_starts,
    count(*) FILTER (WHERE event = 'results_screen_shown')                 AS results_shown,
    count(*) FILTER (WHERE event = 'rematch_started')                      AS rematches
FROM public.mp_events
GROUP BY 1
ORDER BY 1 DESC;

-- 2) Session outcome distribution
CREATE OR REPLACE VIEW public.mp_session_outcomes AS
SELECT
    date_trunc('day', created_at)  AS day,
    session_outcome,
    count(*)                        AS sessions,
    avg(session_duration_ms)::bigint AS avg_duration_ms,
    percentile_cont(0.5)  WITHIN GROUP (ORDER BY session_duration_ms)::bigint AS p50_duration_ms,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY session_duration_ms)::bigint AS p95_duration_ms
FROM public.mp_events
WHERE event = 'session_ended'
  AND session_outcome IS NOT NULL
GROUP BY 1, 2
ORDER BY 1 DESC, sessions DESC;

-- 3) Turn performance: auth / reject / rpc-fail + latency
CREATE OR REPLACE VIEW public.mp_turn_performance AS
SELECT
    date_trunc('hour', created_at) AS hour,
    count(*) FILTER (WHERE event = 'turn_advance_requested')    AS requested,
    count(*) FILTER (WHERE event = 'turn_advance_authorized')   AS authorized,
    count(*) FILTER (WHERE event = 'turn_advance_rejected')     AS rejected,
    count(*) FILTER (WHERE event = 'turn_advance_rpc_failed')   AS rpc_failed,
    avg(turn_rpc_latency_ms) FILTER (WHERE event IN ('turn_advance_authorized','turn_advance_rejected'))::int AS avg_rpc_ms,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY turn_rpc_latency_ms)
        FILTER (WHERE event IN ('turn_advance_authorized','turn_advance_rejected'))::int AS p95_rpc_ms,
    avg(turn_duration_ms) FILTER (WHERE event = 'turn_advance_authorized')::bigint AS avg_turn_ms
FROM public.mp_events
WHERE event IN ('turn_advance_requested','turn_advance_authorized','turn_advance_rejected','turn_advance_rpc_failed')
GROUP BY 1
ORDER BY 1 DESC;

GRANT SELECT ON public.mp_room_funnel, public.mp_session_outcomes, public.mp_turn_performance
    TO authenticated;
