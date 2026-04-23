-- =============================================================================
-- 888Play Multiplayer SQL Query Pack
-- Apply once in Supabase SQL Editor. Safe to re-run (CREATE OR REPLACE).
-- Depends on: public.mp_events (see supabase_mp_telemetry.sql)
-- =============================================================================

-- 1) Room funnel -------------------------------------------------------------
-- Daily counts across the full room lifecycle funnel.
CREATE OR REPLACE VIEW public.mp_room_funnel AS
SELECT
    date_trunc('day', created_at)                                    AS day,
    count(*) FILTER (WHERE event = 'room_create_succeeded')          AS rooms_created,
    count(*) FILTER (WHERE event = 'room_join_succeeded')            AS joins_succeeded,
    count(*) FILTER (WHERE event = 'room_join_failed')               AS joins_failed,
    count(*) FILTER (WHERE event = 'ready_check_started')            AS ready_checks,
    count(*) FILTER (WHERE event = 'player_ready_submitted')         AS ready_submits,
    count(*) FILTER (WHERE event = 'match_start_succeeded')          AS match_starts,
    count(*) FILTER (WHERE event = 'results_screen_shown')           AS results_shown,
    count(*) FILTER (WHERE event = 'rematch_started')                AS rematches
FROM public.mp_events
GROUP BY 1
ORDER BY 1 DESC;

-- 2) Join failure reasons ----------------------------------------------------
-- Top failure_reason values for room_join_failed. Detects bad codes, closed
-- rooms, version mismatches, network issues.
CREATE OR REPLACE VIEW public.mp_join_failures AS
SELECT
    date_trunc('day', created_at)      AS day,
    coalesce(failure_reason, 'unknown') AS failure_reason,
    count(*)                            AS failures,
    count(DISTINCT device_id)           AS unique_devices
FROM public.mp_events
WHERE event = 'room_join_failed'
GROUP BY 1, 2
ORDER BY 1 DESC, failures DESC;

-- 3) Forced return home trend ------------------------------------------------
-- Counts of users being kicked back to Home by the system, with reason. Spikes
-- indicate room invalidation, auth loss, or bad recovery paths.
CREATE OR REPLACE VIEW public.mp_forced_home_trend AS
SELECT
    date_trunc('hour', created_at)     AS hour,
    coalesce(failure_reason, 'unknown') AS reason,
    coalesce(session_phase, 'unknown') AS phase,
    count(*)                            AS occurrences,
    count(DISTINCT device_id)           AS unique_devices
FROM public.mp_events
WHERE event = 'forced_return_home'
GROUP BY 1, 2, 3
ORDER BY 1 DESC, occurrences DESC;

-- 4) Resume / reconnect recovery rate ----------------------------------------
-- How often resumed/reconnected sessions successfully land back on a valid
-- state (spectator snapshot, active turn, or results) vs get dropped.
CREATE OR REPLACE VIEW public.mp_reconnect_recovery AS
WITH resumes AS (
    SELECT session_id, min(created_at) AS resumed_at
    FROM public.mp_events
    WHERE event IN ('app_resumed_in_match', 'reconnect_during_match')
    GROUP BY session_id
),
recoveries AS (
    SELECT e.session_id, min(e.created_at) AS recovered_at
    FROM public.mp_events e
    JOIN resumes r ON r.session_id = e.session_id AND e.created_at >= r.resumed_at
    WHERE e.event IN ('spectator_snapshot_received',
                      'turn_advance_authorized',
                      'results_screen_shown',
                      'room_resync_completed',
                      'session_resync_completed')
    GROUP BY e.session_id
)
SELECT
    date_trunc('day', r.resumed_at)                                  AS day,
    count(*)                                                         AS resume_attempts,
    count(rec.session_id)                                            AS recovered,
    count(*) - count(rec.session_id)                                 AS unrecovered,
    round(100.0 * count(rec.session_id) / nullif(count(*), 0), 2)    AS recovery_rate_pct
FROM resumes r
LEFT JOIN recoveries rec ON rec.session_id = r.session_id
GROUP BY 1
ORDER BY 1 DESC;

-- 5) Spectator snapshot health ----------------------------------------------
-- Success / timeout rate and latency for spectator snapshot requests.
CREATE OR REPLACE VIEW public.mp_spectator_snapshot_health AS
SELECT
    date_trunc('hour', created_at)                                        AS hour,
    count(*) FILTER (WHERE event = 'spectator_snapshot_requested')        AS requested,
    count(*) FILTER (WHERE event = 'spectator_snapshot_received')         AS received,
    count(*) FILTER (WHERE event = 'spectator_snapshot_timeout')          AS timeouts,
    round(100.0
        * count(*) FILTER (WHERE event = 'spectator_snapshot_received')
        / nullif(count(*) FILTER (WHERE event = 'spectator_snapshot_requested'), 0), 2
    )                                                                     AS success_rate_pct,
    avg(latency_ms) FILTER (WHERE event = 'spectator_snapshot_received')::int AS avg_latency_ms,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY latency_ms)
        FILTER (WHERE event = 'spectator_snapshot_received')::int         AS p95_latency_ms
FROM public.mp_events
WHERE event IN ('spectator_snapshot_requested',
                'spectator_snapshot_received',
                'spectator_snapshot_timeout')
GROUP BY 1
ORDER BY 1 DESC;

-- 6) Turn health & latency ---------------------------------------------------
-- Authoritative turn advance outcomes + RPC latency + human turn duration.
CREATE OR REPLACE VIEW public.mp_turn_health AS
SELECT
    date_trunc('hour', created_at)                                       AS hour,
    count(*) FILTER (WHERE event = 'turn_advance_requested')             AS requested,
    count(*) FILTER (WHERE event = 'turn_advance_authorized')            AS authorized,
    count(*) FILTER (WHERE event = 'turn_advance_rejected')              AS rejected,
    count(*) FILTER (WHERE event = 'turn_advance_rpc_failed')            AS rpc_failed,
    round(100.0
        * count(*) FILTER (WHERE event = 'turn_advance_authorized')
        / nullif(count(*) FILTER (WHERE event = 'turn_advance_requested'), 0), 2
    )                                                                    AS authorized_rate_pct,
    round(100.0
        * count(*) FILTER (WHERE event = 'turn_advance_rejected')
        / nullif(count(*) FILTER (WHERE event = 'turn_advance_requested'), 0), 2
    )                                                                    AS rejected_rate_pct,
    avg(turn_rpc_latency_ms) FILTER (WHERE event IN
        ('turn_advance_authorized','turn_advance_rejected'))::int        AS avg_rpc_ms,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY turn_rpc_latency_ms)
        FILTER (WHERE event IN
            ('turn_advance_authorized','turn_advance_rejected'))::int    AS p95_rpc_ms,
    avg(turn_duration_ms) FILTER (WHERE event = 'turn_advance_authorized')::bigint
                                                                         AS avg_turn_ms,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY turn_duration_ms)
        FILTER (WHERE event = 'turn_advance_authorized')::bigint         AS p95_turn_ms
FROM public.mp_events
WHERE event IN ('turn_advance_requested',
                'turn_advance_authorized',
                'turn_advance_rejected',
                'turn_advance_rpc_failed')
GROUP BY 1
ORDER BY 1 DESC;

-- 7) Results delivery health -------------------------------------------------
-- Does every match_start eventually show results? Detects match-end desync.
CREATE OR REPLACE VIEW public.mp_results_delivery AS
WITH started AS (
    SELECT session_id, min(created_at) AS started_at
    FROM public.mp_events
    WHERE event = 'match_start_succeeded'
    GROUP BY session_id
),
shown AS (
    SELECT session_id, min(created_at) AS shown_at
    FROM public.mp_events
    WHERE event = 'results_screen_shown'
    GROUP BY session_id
)
SELECT
    date_trunc('day', s.started_at)                                          AS day,
    count(*)                                                                 AS matches_started,
    count(sh.session_id)                                                     AS results_shown,
    count(*) - count(sh.session_id)                                          AS results_missing,
    round(100.0 * count(sh.session_id) / nullif(count(*), 0), 2)             AS delivery_rate_pct,
    avg(extract(epoch FROM (sh.shown_at - s.started_at)) * 1000)::bigint     AS avg_time_to_results_ms
FROM started s
LEFT JOIN shown sh ON sh.session_id = s.session_id
GROUP BY 1
ORDER BY 1 DESC;

-- 8) Rematch funnel ----------------------------------------------------------
-- Votes submitted -> persisted -> rematch_started. Detects lost votes or
-- failed rematch starts.
CREATE OR REPLACE VIEW public.mp_rematch_funnel AS
SELECT
    date_trunc('day', created_at)                                  AS day,
    count(*) FILTER (WHERE event = 'results_screen_shown')         AS results_shown,
    count(*) FILTER (WHERE event = 'rematch_vote_submitted')       AS votes_submitted,
    count(*) FILTER (WHERE event = 'rematch_vote_persisted')       AS votes_persisted,
    count(*) FILTER (WHERE event = 'rematch_started')              AS rematches_started,
    count(*) FILTER (WHERE event = 'rematch_start_failed')         AS rematches_failed,
    round(100.0
        * count(*) FILTER (WHERE event = 'rematch_vote_persisted')
        / nullif(count(*) FILTER (WHERE event = 'rematch_vote_submitted'), 0), 2
    )                                                              AS persist_rate_pct,
    round(100.0
        * count(*) FILTER (WHERE event = 'rematch_started')
        / nullif(count(*) FILTER (WHERE event = 'rematch_vote_persisted'), 0), 2
    )                                                              AS start_rate_pct
FROM public.mp_events
GROUP BY 1
ORDER BY 1 DESC;

-- 9) Session outcome distribution --------------------------------------------
CREATE OR REPLACE VIEW public.mp_session_outcomes AS
SELECT
    date_trunc('day', created_at)                                            AS day,
    session_outcome,
    count(*)                                                                 AS sessions,
    avg(session_duration_ms)::bigint                                         AS avg_duration_ms,
    percentile_cont(0.5)  WITHIN GROUP (ORDER BY session_duration_ms)::bigint AS p50_duration_ms,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY session_duration_ms)::bigint AS p95_duration_ms
FROM public.mp_events
WHERE event = 'session_ended'
  AND session_outcome IS NOT NULL
GROUP BY 1, 2
ORDER BY 1 DESC, sessions DESC;

-- 10) App version regression -------------------------------------------------
-- Per-version reliability snapshot for detecting release regressions.
CREATE OR REPLACE VIEW public.mp_version_regression AS
SELECT
    coalesce(app_version, 'unknown')                                 AS app_version,
    coalesce(platform, 'unknown')                                    AS platform,
    count(DISTINCT session_id)                                       AS sessions,
    count(*) FILTER (WHERE event = 'match_start_succeeded')          AS match_starts,
    count(*) FILTER (WHERE event = 'results_screen_shown')           AS results_shown,
    count(*) FILTER (WHERE event = 'turn_advance_rpc_failed')        AS turn_rpc_fails,
    count(*) FILTER (WHERE event = 'forced_return_home')             AS forced_home,
    count(*) FILTER (WHERE event = 'spectator_snapshot_timeout')     AS snapshot_timeouts,
    count(*) FILTER (WHERE event = 'room_join_failed')               AS join_fails,
    round(100.0
        * count(*) FILTER (WHERE event = 'results_screen_shown')
        / nullif(count(*) FILTER (WHERE event = 'match_start_succeeded'), 0), 2
    )                                                                AS results_rate_pct
FROM public.mp_events
WHERE created_at > now() - interval '14 days'
GROUP BY 1, 2
ORDER BY sessions DESC;

-- 11) Device-level trouble spots ---------------------------------------------
-- Devices with abnormally high failure/retry/forced-home counts. Useful for
-- spotting bad networks, jailbroken installs, or flaky regions.
CREATE OR REPLACE VIEW public.mp_device_trouble AS
SELECT
    device_id,
    coalesce(platform, 'unknown')                                   AS platform,
    coalesce(app_version, 'unknown')                                AS app_version,
    count(DISTINCT session_id)                                      AS sessions,
    count(*) FILTER (WHERE event = 'forced_return_home')            AS forced_home,
    count(*) FILTER (WHERE event = 'room_join_failed')              AS join_fails,
    count(*) FILTER (WHERE event = 'turn_advance_rpc_failed')       AS turn_rpc_fails,
    count(*) FILTER (WHERE event = 'spectator_snapshot_timeout')    AS snapshot_timeouts,
    count(*) FILTER (WHERE event = 'reconnect_during_match')        AS reconnects,
    max(created_at)                                                 AS last_seen
FROM public.mp_events
WHERE created_at > now() - interval '14 days'
  AND device_id IS NOT NULL
GROUP BY 1, 2, 3
HAVING
    count(*) FILTER (WHERE event = 'forced_return_home')         >= 3
 OR count(*) FILTER (WHERE event = 'room_join_failed')           >= 5
 OR count(*) FILTER (WHERE event = 'turn_advance_rpc_failed')    >= 3
 OR count(*) FILTER (WHERE event = 'spectator_snapshot_timeout') >= 3
ORDER BY forced_home DESC, turn_rpc_fails DESC, join_fails DESC;

-- 12) Weekly reliability summary --------------------------------------------
-- Single-row-per-week high-level health snapshot.
CREATE OR REPLACE VIEW public.mp_weekly_reliability AS
SELECT
    date_trunc('week', created_at)                                           AS week,
    count(DISTINCT session_id)                                               AS sessions,
    count(DISTINCT device_id)                                                AS unique_devices,
    count(*) FILTER (WHERE event = 'room_create_succeeded')                  AS rooms_created,
    count(*) FILTER (WHERE event = 'match_start_succeeded')                  AS match_starts,
    count(*) FILTER (WHERE event = 'results_screen_shown')                   AS results_shown,
    count(*) FILTER (WHERE event = 'rematch_started')                        AS rematches,
    count(*) FILTER (WHERE event = 'forced_return_home')                     AS forced_home,
    count(*) FILTER (WHERE event = 'room_join_failed')                       AS join_fails,
    count(*) FILTER (WHERE event = 'turn_advance_rpc_failed')                AS turn_rpc_fails,
    count(*) FILTER (WHERE event = 'spectator_snapshot_timeout')             AS snapshot_timeouts,
    round(100.0
        * count(*) FILTER (WHERE event = 'results_screen_shown')
        / nullif(count(*) FILTER (WHERE event = 'match_start_succeeded'), 0), 2
    )                                                                        AS results_delivery_pct,
    round(100.0
        * count(*) FILTER (WHERE event = 'room_join_succeeded')
        / nullif(count(*) FILTER (WHERE event IN
            ('room_join_succeeded','room_join_failed')), 0), 2
    )                                                                        AS join_success_pct,
    round(100.0
        * count(*) FILTER (WHERE event = 'turn_advance_authorized')
        / nullif(count(*) FILTER (WHERE event = 'turn_advance_requested'), 0), 2
    )                                                                        AS turn_authorized_pct
FROM public.mp_events
WHERE created_at > now() - interval '90 days'
GROUP BY 1
ORDER BY 1 DESC;

-- =============================================================================
-- Grants (dashboards/SQL editor reads via service role; authenticated may read
-- the aggregated views for in-app admin tooling if desired).
-- =============================================================================
GRANT SELECT ON
    public.mp_room_funnel,
    public.mp_join_failures,
    public.mp_forced_home_trend,
    public.mp_reconnect_recovery,
    public.mp_spectator_snapshot_health,
    public.mp_turn_health,
    public.mp_results_delivery,
    public.mp_rematch_funnel,
    public.mp_session_outcomes,
    public.mp_version_regression,
    public.mp_device_trouble,
    public.mp_weekly_reliability
TO authenticated;

-- =============================================================================
-- Validation block (run separately, read-only). Confirms each view exists and
-- returns a row count without errors. Safe to run after apply.
-- =============================================================================
-- SELECT 'mp_room_funnel'              AS view, count(*) FROM public.mp_room_funnel              UNION ALL
-- SELECT 'mp_join_failures'            AS view, count(*) FROM public.mp_join_failures            UNION ALL
-- SELECT 'mp_forced_home_trend'        AS view, count(*) FROM public.mp_forced_home_trend        UNION ALL
-- SELECT 'mp_reconnect_recovery'       AS view, count(*) FROM public.mp_reconnect_recovery       UNION ALL
-- SELECT 'mp_spectator_snapshot_health' AS view, count(*) FROM public.mp_spectator_snapshot_health UNION ALL
-- SELECT 'mp_turn_health'              AS view, count(*) FROM public.mp_turn_health              UNION ALL
-- SELECT 'mp_results_delivery'         AS view, count(*) FROM public.mp_results_delivery         UNION ALL
-- SELECT 'mp_rematch_funnel'           AS view, count(*) FROM public.mp_rematch_funnel           UNION ALL
-- SELECT 'mp_session_outcomes'         AS view, count(*) FROM public.mp_session_outcomes         UNION ALL
-- SELECT 'mp_version_regression'       AS view, count(*) FROM public.mp_version_regression       UNION ALL
-- SELECT 'mp_device_trouble'           AS view, count(*) FROM public.mp_device_trouble           UNION ALL
-- SELECT 'mp_weekly_reliability'       AS view, count(*) FROM public.mp_weekly_reliability;
