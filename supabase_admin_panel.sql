-- ============================================================
-- 888Play — ADMIN PANEL schema & RPCs
-- Run AFTER supabase_final_production.sql and supabase_invite_system.sql
-- Idempotent: safe to re-run.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. ADMIN TABLES
-- ============================================================

-- Allow-list of admin emails. Only these users can access the panel.
CREATE TABLE IF NOT EXISTS public.admin_users (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email       text NOT NULL UNIQUE,
    role        text NOT NULL DEFAULT 'admin' CHECK (role IN ('admin','superadmin')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid
);

CREATE INDEX IF NOT EXISTS idx_admin_users_email ON public.admin_users (lower(email));

-- Audit log: every admin action gets logged
CREATE TABLE IF NOT EXISTS public.admin_audit_log (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_email  text NOT NULL,
    admin_id     uuid,
    action       text NOT NULL,
    target_type  text,
    target_id    text,
    payload      jsonb,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_created ON public.admin_audit_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_admin ON public.admin_audit_log (admin_email, created_at DESC);

-- Remote app config (key-value). Read by iOS app; edited in admin panel.
CREATE TABLE IF NOT EXISTS public.app_config (
    key         text PRIMARY KEY,
    value       jsonb NOT NULL,
    description text,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  text
);

-- UI config (remote UI customization — copy, colors, feature flags, game list overrides)
CREATE TABLE IF NOT EXISTS public.ui_config (
    key         text PRIMARY KEY,
    value       jsonb NOT NULL,
    description text,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  text
);

-- Announcements / push messages
CREATE TABLE IF NOT EXISTS public.announcements (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title       text NOT NULL,
    body        text NOT NULL,
    audience    text NOT NULL DEFAULT 'all' CHECK (audience IN ('all','free','subscribed','banned')),
    send_push   boolean NOT NULL DEFAULT false,
    active      boolean NOT NULL DEFAULT true,
    starts_at   timestamptz NOT NULL DEFAULT now(),
    ends_at     timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  text
);

CREATE INDEX IF NOT EXISTS idx_announcements_active ON public.announcements (active, starts_at DESC);

-- AI usage log (if not already present)
CREATE TABLE IF NOT EXISTS public.ai_usage_log (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    feature     text NOT NULL,
    stars_cost  integer NOT NULL DEFAULT 0,
    prompt      text,
    success     boolean NOT NULL DEFAULT true,
    error       text,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_user ON public.ai_usage_log (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_created ON public.ai_usage_log (created_at DESC);

-- Ban table
CREATE TABLE IF NOT EXISTS public.user_bans (
    user_id    uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    reason     text,
    banned_at  timestamptz NOT NULL DEFAULT now(),
    banned_by  text,
    expires_at timestamptz
);

-- ============================================================
-- 2. HELPERS
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_admin(p_email text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (SELECT 1 FROM public.admin_users WHERE lower(email) = lower(p_email));
$$;

CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.admin_users a
        JOIN auth.users u ON lower(u.email) = lower(a.email)
        WHERE u.id = auth.uid()
    );
$$;

-- ============================================================
-- 3. RLS
-- ============================================================

ALTER TABLE public.admin_users      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_log  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_config       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ui_config        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage_log     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_bans        ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_users_admin_only ON public.admin_users;
CREATE POLICY admin_users_admin_only ON public.admin_users
    FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());

DROP POLICY IF EXISTS admin_audit_admin_only ON public.admin_audit_log;
CREATE POLICY admin_audit_admin_only ON public.admin_audit_log
    FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());

DROP POLICY IF EXISTS app_config_read ON public.app_config;
CREATE POLICY app_config_read ON public.app_config
    FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS app_config_admin_write ON public.app_config;
CREATE POLICY app_config_admin_write ON public.app_config
    FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());

DROP POLICY IF EXISTS ui_config_read ON public.ui_config;
CREATE POLICY ui_config_read ON public.ui_config
    FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS ui_config_admin_write ON public.ui_config;
CREATE POLICY ui_config_admin_write ON public.ui_config
    FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());

DROP POLICY IF EXISTS announcements_read ON public.announcements;
CREATE POLICY announcements_read ON public.announcements
    FOR SELECT TO authenticated USING (active = true);
DROP POLICY IF EXISTS announcements_admin_write ON public.announcements;
CREATE POLICY announcements_admin_write ON public.announcements
    FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());

DROP POLICY IF EXISTS ai_usage_own ON public.ai_usage_log;
CREATE POLICY ai_usage_own ON public.ai_usage_log
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.current_user_is_admin());
DROP POLICY IF EXISTS ai_usage_insert_own ON public.ai_usage_log;
CREATE POLICY ai_usage_insert_own ON public.ai_usage_log
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS user_bans_read ON public.user_bans;
CREATE POLICY user_bans_read ON public.user_bans
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.current_user_is_admin());
DROP POLICY IF EXISTS user_bans_admin_write ON public.user_bans;
CREATE POLICY user_bans_admin_write ON public.user_bans
    FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());

-- ============================================================
-- 4. ADMIN RPCs
-- ============================================================

-- Log an admin action
CREATE OR REPLACE FUNCTION public._admin_log(
    p_action text,
    p_target_type text,
    p_target_id text,
    p_payload jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email text;
BEGIN
    SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
    INSERT INTO public.admin_audit_log (admin_email, admin_id, action, target_type, target_id, payload)
    VALUES (COALESCE(v_email,'system'), auth.uid(), p_action, p_target_type, p_target_id, p_payload);
END;
$$;

-- Search users
CREATE OR REPLACE FUNCTION public.admin_search_users(
    p_query text DEFAULT '',
    p_limit int DEFAULT 50,
    p_offset int DEFAULT 0
) RETURNS TABLE (
    id uuid,
    username text,
    email text,
    public_id integer,
    stars_balance integer,
    is_subscribed boolean,
    is_banned boolean,
    created_at timestamptz,
    last_sign_in_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'not_authorized';
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        p.username,
        p.email,
        p.public_id,
        COALESCE(w.stars_balance, 0),
        EXISTS (SELECT 1 FROM public.subscriptions s WHERE s.user_id = p.id AND s.status IN ('active','trialing') AND (s.expires_at IS NULL OR s.expires_at > now())),
        EXISTS (SELECT 1 FROM public.user_bans b WHERE b.user_id = p.id AND (b.expires_at IS NULL OR b.expires_at > now())),
        p.created_at,
        u.last_sign_in_at
    FROM public.profiles p
    LEFT JOIN public.wallets w ON w.user_id = p.id
    LEFT JOIN auth.users u ON u.id = p.id
    WHERE p_query = '' OR
          p.username ILIKE '%'||p_query||'%' OR
          p.email ILIKE '%'||p_query||'%' OR
          p.id::text = p_query OR
          p.public_id::text = p_query
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- User detail
CREATE OR REPLACE FUNCTION public.admin_user_detail(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v jsonb;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'not_authorized';
    END IF;

    SELECT jsonb_build_object(
        'profile', to_jsonb(p.*),
        'wallet', (SELECT to_jsonb(w.*) FROM public.wallets w WHERE w.user_id = p.id),
        'subscription', (SELECT to_jsonb(s.*) FROM public.subscriptions s WHERE s.user_id = p.id ORDER BY s.created_at DESC LIMIT 1),
        'unlocks', (SELECT COALESCE(jsonb_agg(jsonb_build_object('game_key',g.game_key,'unlocked_at',g.unlocked_at)), '[]'::jsonb) FROM public.game_unlocks g WHERE g.user_id = p.id),
        'ban', (SELECT to_jsonb(b.*) FROM public.user_bans b WHERE b.user_id = p.id),
        'last_sign_in_at', (SELECT u.last_sign_in_at FROM auth.users u WHERE u.id = p.id),
        'recent_transactions', (
            SELECT COALESCE(jsonb_agg(to_jsonb(t.*) ORDER BY t.created_at DESC), '[]'::jsonb)
            FROM (SELECT * FROM public.star_transactions WHERE user_id = p.id ORDER BY created_at DESC LIMIT 20) t
        ),
        'recent_ai', (
            SELECT COALESCE(jsonb_agg(to_jsonb(a.*) ORDER BY a.created_at DESC), '[]'::jsonb)
            FROM (SELECT * FROM public.ai_usage_log WHERE user_id = p.id ORDER BY created_at DESC LIMIT 20) a
        ),
        'invite_stats', (
            SELECT jsonb_build_object(
                'invite_code', pr.invite_code,
                'invited_count', (SELECT count(*) FROM public.profiles WHERE invited_by = p.id),
                'invited_by', pr.invited_by
            ) FROM public.profiles pr WHERE pr.id = p.id
        )
    ) INTO v
    FROM public.profiles p
    WHERE p.id = p_user_id;

    RETURN v;
END;
$$;

-- Adjust stars (grant or deduct)
CREATE OR REPLACE FUNCTION public.admin_adjust_stars(
    p_user_id uuid,
    p_delta int,
    p_reason text DEFAULT 'admin_adjustment'
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_new int;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'not_authorized';
    END IF;

    INSERT INTO public.wallets (user_id, stars_balance)
    VALUES (p_user_id, GREATEST(0, p_delta))
    ON CONFLICT (user_id) DO UPDATE
        SET stars_balance = GREATEST(0, public.wallets.stars_balance + p_delta),
            updated_at = now()
    RETURNING stars_balance INTO v_new;

    INSERT INTO public.star_transactions (user_id, amount, transaction_type, reason)
    VALUES (p_user_id, p_delta, CASE WHEN p_delta >= 0 THEN 'reward' ELSE 'refund' END, p_reason);

    PERFORM public._admin_log('adjust_stars','user',p_user_id::text, jsonb_build_object('delta',p_delta,'reason',p_reason,'new_balance',v_new));
    RETURN v_new;
END;
$$;

-- Unlock / relock a game for a user
CREATE OR REPLACE FUNCTION public.admin_unlock_game(
    p_user_id uuid,
    p_game_key text,
    p_lock boolean DEFAULT false
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'not_authorized';
    END IF;

    IF p_lock THEN
        DELETE FROM public.game_unlocks WHERE user_id = p_user_id AND game_key = p_game_key;
        PERFORM public._admin_log('lock_game','user',p_user_id::text, jsonb_build_object('game_key',p_game_key));
    ELSE
        INSERT INTO public.game_unlocks (user_id, game_key)
        VALUES (p_user_id, p_game_key)
        ON CONFLICT DO NOTHING;
        PERFORM public._admin_log('unlock_game','user',p_user_id::text, jsonb_build_object('game_key',p_game_key));
    END IF;
END;
$$;

-- Ban / unban
CREATE OR REPLACE FUNCTION public.admin_set_ban(
    p_user_id uuid,
    p_banned boolean,
    p_reason text DEFAULT NULL,
    p_expires_at timestamptz DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email text;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'not_authorized';
    END IF;

    SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();

    IF p_banned THEN
        INSERT INTO public.user_bans (user_id, reason, banned_by, expires_at)
        VALUES (p_user_id, p_reason, v_email, p_expires_at)
        ON CONFLICT (user_id) DO UPDATE
            SET reason = EXCLUDED.reason, banned_by = EXCLUDED.banned_by,
                expires_at = EXCLUDED.expires_at, banned_at = now();
        PERFORM public._admin_log('ban','user',p_user_id::text, jsonb_build_object('reason',p_reason,'expires_at',p_expires_at));
    ELSE
        DELETE FROM public.user_bans WHERE user_id = p_user_id;
        PERFORM public._admin_log('unban','user',p_user_id::text, NULL);
    END IF;
END;
$$;

-- Grant/revoke subscription (manual override)
CREATE OR REPLACE FUNCTION public.admin_set_subscription(
    p_user_id uuid,
    p_active boolean,
    p_expires_at timestamptz DEFAULT NULL,
    p_tier text DEFAULT 'premium'
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'not_authorized';
    END IF;

    IF p_active THEN
        INSERT INTO public.subscriptions (user_id, status, tier, expires_at, source)
        VALUES (p_user_id, 'active', p_tier, COALESCE(p_expires_at, now() + interval '30 days'), 'admin')
        ON CONFLICT (user_id) DO UPDATE
            SET status='active', tier=EXCLUDED.tier, expires_at=EXCLUDED.expires_at, source='admin', updated_at=now();
        PERFORM public._admin_log('grant_subscription','user',p_user_id::text, jsonb_build_object('tier',p_tier,'expires_at',p_expires_at));
    ELSE
        UPDATE public.subscriptions SET status='canceled', updated_at=now() WHERE user_id = p_user_id;
        PERFORM public._admin_log('revoke_subscription','user',p_user_id::text, NULL);
    END IF;
END;
$$;

-- Analytics summary
CREATE OR REPLACE FUNCTION public.admin_analytics_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v jsonb;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'not_authorized';
    END IF;

    SELECT jsonb_build_object(
        'total_users', (SELECT count(*) FROM public.profiles),
        'new_users_24h', (SELECT count(*) FROM public.profiles WHERE created_at > now() - interval '24 hours'),
        'new_users_7d', (SELECT count(*) FROM public.profiles WHERE created_at > now() - interval '7 days'),
        'new_users_30d', (SELECT count(*) FROM public.profiles WHERE created_at > now() - interval '30 days'),
        'dau', (SELECT count(DISTINCT id) FROM auth.users WHERE last_sign_in_at > now() - interval '24 hours'),
        'wau', (SELECT count(DISTINCT id) FROM auth.users WHERE last_sign_in_at > now() - interval '7 days'),
        'mau', (SELECT count(DISTINCT id) FROM auth.users WHERE last_sign_in_at > now() - interval '30 days'),
        'active_subscriptions', (SELECT count(*) FROM public.subscriptions WHERE status IN ('active','trialing') AND (expires_at IS NULL OR expires_at > now())),
        'total_stars_circulating', (SELECT COALESCE(sum(stars_balance),0) FROM public.wallets),
        'ai_calls_24h', (SELECT count(*) FROM public.ai_usage_log WHERE created_at > now() - interval '24 hours'),
        'ai_stars_spent_30d', (SELECT COALESCE(sum(stars_cost),0) FROM public.ai_usage_log WHERE created_at > now() - interval '30 days'),
        'invites_completed', (SELECT count(*) FROM public.profiles WHERE invited_by IS NOT NULL),
        'banned_users', (SELECT count(*) FROM public.user_bans WHERE expires_at IS NULL OR expires_at > now())
    ) INTO v;

    RETURN v;
END;
$$;

-- Signups per day (last 30d)
CREATE OR REPLACE FUNCTION public.admin_signups_timeseries(p_days int DEFAULT 30)
RETURNS TABLE(day date, count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'not_authorized';
    END IF;

    RETURN QUERY
    SELECT d::date, COALESCE(c.count, 0)
    FROM generate_series(now() - (p_days || ' days')::interval, now(), interval '1 day') d
    LEFT JOIN (
        SELECT date_trunc('day', created_at)::date AS day, count(*)::bigint AS count
        FROM public.profiles GROUP BY 1
    ) c ON c.day = d::date
    ORDER BY d;
END;
$$;

-- Upsert app_config
CREATE OR REPLACE FUNCTION public.admin_set_config(p_key text, p_value jsonb, p_description text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email text;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'not_authorized';
    END IF;
    SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();

    INSERT INTO public.app_config (key, value, description, updated_by)
    VALUES (p_key, p_value, p_description, v_email)
    ON CONFLICT (key) DO UPDATE
        SET value = EXCLUDED.value,
            description = COALESCE(EXCLUDED.description, public.app_config.description),
            updated_by = EXCLUDED.updated_by,
            updated_at = now();

    PERFORM public._admin_log('set_config','config',p_key, jsonb_build_object('value',p_value));
END;
$$;

-- Upsert ui_config
CREATE OR REPLACE FUNCTION public.admin_set_ui_config(p_key text, p_value jsonb, p_description text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email text;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'not_authorized';
    END IF;
    SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();

    INSERT INTO public.ui_config (key, value, description, updated_by)
    VALUES (p_key, p_value, p_description, v_email)
    ON CONFLICT (key) DO UPDATE
        SET value = EXCLUDED.value,
            description = COALESCE(EXCLUDED.description, public.ui_config.description),
            updated_by = EXCLUDED.updated_by,
            updated_at = now();

    PERFORM public._admin_log('set_ui_config','ui_config',p_key, jsonb_build_object('value',p_value));
END;
$$;

-- Seed default config
INSERT INTO public.app_config (key, value, description) VALUES
    ('economy.signup_bonus_stars',      '100'::jsonb, 'Stars awarded on signup'),
    ('economy.daily_reward_stars',      '10'::jsonb,  'Stars awarded on daily login'),
    ('economy.invite_reward_stars',     '30'::jsonb,  'Stars awarded to inviter after valid signup'),
    ('economy.ai_cost_free',            '5'::jsonb,   'Star cost for AI usage (free users)'),
    ('economy.ai_cost_subscriber',      '2'::jsonb,   'Star cost for AI usage (subscribers)'),
    ('feature_flags.invite_enabled',    'true'::jsonb, 'Show invite UI'),
    ('feature_flags.ai_enabled',        'true'::jsonb, 'Enable AI features')
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.ui_config (key, value, description) VALUES
    ('free_games',     '["reverse_singing","truth_or_dare","guess_seconds","memory_grid","imposter"]'::jsonb, 'Game keys that are free for everyone'),
    ('featured_games', '["imposter","truth_or_dare"]'::jsonb, 'Games featured on home screen'),
    ('home_banner',    '{"enabled":false,"title":"","body":"","cta":"","url":""}'::jsonb, 'Home banner'),
    ('theme',          '{"accent":"blue","style":"auto"}'::jsonb, 'Global theme tokens')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- 5. Grants
-- ============================================================
GRANT EXECUTE ON FUNCTION public.is_admin(text)                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin()        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_users(text,int,int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_user_detail(uuid)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_adjust_stars(uuid,int,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_unlock_game(uuid,text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_ban(uuid,boolean,text,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_subscription(uuid,boolean,timestamptz,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_analytics_summary()      TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_signups_timeseries(int)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_config(text,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_ui_config(text,jsonb,text) TO authenticated;

-- ============================================================
-- 6. Seed the first admin (REPLACE EMAIL!)
-- ============================================================
-- INSERT INTO public.admin_users(email, role) VALUES ('you@example.com', 'superadmin')
-- ON CONFLICT (email) DO NOTHING;
