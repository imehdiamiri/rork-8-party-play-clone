-- ============================================================
-- 8PartyPlay — FINAL Star Economy Migration
-- Server-authoritative stars. Run once; safe to re-run.
-- ============================================================

-- 1. Align transaction_type constraint with Swift enum (snake_case).
ALTER TABLE public.star_transactions
    DROP CONSTRAINT IF EXISTS star_transactions_type_check;

ALTER TABLE public.star_transactions
    ADD CONSTRAINT star_transactions_type_check CHECK (
        transaction_type IN (
            'purchase',
            'daily_reward',
            'subscription_reward',
            'tournament_entry',
            'tournament_reward',
            'refund',
            'admin_adjustment'
        )
    );

-- 2. Track daily reward claims (one per user per UTC day).
CREATE TABLE IF NOT EXISTS public.daily_reward_claims (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    claim_date date NOT NULL,
    amount     integer NOT NULL DEFAULT 5,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, claim_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_reward_claims_user ON public.daily_reward_claims (user_id, claim_date DESC);

-- 3. claim_daily_reward — 5 Stars per UTC day.
CREATE OR REPLACE FUNCTION public.claim_daily_reward()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_amount integer := 5;
    v_today date := (now() at time zone 'utc')::date;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    BEGIN
        INSERT INTO public.daily_reward_claims(user_id, claim_date, amount)
        VALUES (v_uid, v_today, v_amount);
    EXCEPTION WHEN unique_violation THEN
        RETURN 0;
    END;

    INSERT INTO public.wallets(user_id, stars_balance)
    VALUES (v_uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

    UPDATE public.wallets
       SET stars_balance = stars_balance + v_amount, updated_at = now()
     WHERE user_id = v_uid;

    INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type)
    VALUES (v_uid, v_amount, 'daily_reward', 'Daily reward', 'daily');

    RETURN v_amount;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_daily_reward() TO authenticated;

-- 4. grant_subscription_stars — per billing period (idempotent).
CREATE OR REPLACE FUNCTION public.grant_subscription_stars(
    p_amount     integer,
    p_tier       text,
    p_period_key text,
    p_expires_at timestamptz DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_already integer;
    v_is_lifetime boolean := (p_tier = 'lifetime');
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN RETURN 0; END IF;
    IF p_period_key IS NULL OR length(trim(p_period_key)) = 0 THEN
        RAISE EXCEPTION 'period_key is required';
    END IF;

    SELECT count(*) INTO v_already
      FROM public.star_transactions
     WHERE user_id = v_uid
       AND transaction_type = 'subscription_reward'
       AND reference_type = 'billing_period'
       AND reason = p_period_key;

    IF v_already > 0 THEN
        INSERT INTO public.subscriptions(user_id, tier, is_active, expires_at, auto_renews, last_star_grant_date)
        VALUES (v_uid, coalesce(p_tier, 'monthly'), true, p_expires_at, NOT v_is_lifetime, now())
        ON CONFLICT (user_id) DO UPDATE
            SET tier = coalesce(p_tier, public.subscriptions.tier),
                is_active = true,
                expires_at = coalesce(p_expires_at, public.subscriptions.expires_at),
                auto_renews = NOT v_is_lifetime,
                updated_at = now();
        RETURN 0;
    END IF;

    INSERT INTO public.wallets(user_id, stars_balance)
    VALUES (v_uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

    UPDATE public.wallets
       SET stars_balance = stars_balance + p_amount, updated_at = now()
     WHERE user_id = v_uid;

    INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type)
    VALUES (v_uid, p_amount, 'subscription_reward', p_period_key, 'billing_period');

    INSERT INTO public.subscriptions(user_id, tier, is_active, expires_at, auto_renews, last_star_grant_date)
    VALUES (v_uid, coalesce(p_tier, 'monthly'), true, p_expires_at, NOT v_is_lifetime, now())
    ON CONFLICT (user_id) DO UPDATE
        SET tier = coalesce(p_tier, public.subscriptions.tier),
            is_active = true,
            expires_at = coalesce(p_expires_at, public.subscriptions.expires_at),
            auto_renews = NOT v_is_lifetime,
            last_star_grant_date = now(),
            updated_at = now();

    RETURN p_amount;
END;
$$;

GRANT EXECUTE ON FUNCTION public.grant_subscription_stars(integer, text, text, timestamptz) TO authenticated;

-- 5. grant_purchased_stars — star pack purchases (idempotent by product+key).
CREATE OR REPLACE FUNCTION public.grant_purchased_stars(
    p_amount          integer,
    p_product_id      text,
    p_idempotency_key uuid
)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_claimed boolean;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN RETURN 0; END IF;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'purchase_stars', v_uid);
    IF NOT v_claimed THEN RETURN 0; END IF;

    INSERT INTO public.wallets(user_id, stars_balance)
    VALUES (v_uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

    UPDATE public.wallets
       SET stars_balance = stars_balance + p_amount, updated_at = now()
     WHERE user_id = v_uid;

    INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type, idempotency_key)
    VALUES (v_uid, p_amount, 'purchase', coalesce(p_product_id, 'star_pack'), 'star_pack', p_idempotency_key);

    RETURN p_amount;
END;
$$;

GRANT EXECUTE ON FUNCTION public.grant_purchased_stars(integer, text, uuid) TO authenticated;

-- 6. tournament_join — deduct 10 Stars entry fee per player (idempotent per session+user).
CREATE OR REPLACE FUNCTION public.tournament_join(
    p_session_id      uuid,
    p_idempotency_key uuid
)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_entry integer := 10;
    v_claimed boolean;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'tournament_join', v_uid);
    IF NOT v_claimed THEN RETURN 0; END IF;

    UPDATE public.wallets
       SET stars_balance = stars_balance - v_entry, updated_at = now()
     WHERE user_id = v_uid AND stars_balance >= v_entry;

    IF NOT FOUND THEN RAISE EXCEPTION 'Insufficient Stars'; END IF;

    INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type, reference_id, idempotency_key)
    VALUES (v_uid, -v_entry, 'tournament_entry', 'Tournament entry fee', 'game_session', p_session_id, p_idempotency_key);

    RETURN v_entry;
END;
$$;

GRANT EXECUTE ON FUNCTION public.tournament_join(uuid, uuid) TO authenticated;

-- 7. distribute_prize_pool — rewrite with fixed 65/35 split, 10% platform fee.
-- Only session host (created_by) may call. Idempotent per session.
CREATE OR REPLACE FUNCTION public.distribute_prize_pool(
    p_session_id      uuid,
    p_idempotency_key uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_claimed boolean;
    v_entry_total integer;
    v_player_count integer;
    v_pool integer;
    v_first integer;
    v_second integer;
    v_first_user uuid;
    v_second_user uuid;
    v_entry_per_player integer := 10;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.game_sessions WHERE id = p_session_id AND created_by = v_uid) THEN
        RAISE EXCEPTION 'Only session owner can distribute rewards';
    END IF;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'distribute_prize_pool', v_uid);
    IF NOT v_claimed THEN RETURN; END IF;

    -- How many players paid entry (based on tournament_entry transactions referencing this session).
    SELECT count(*) INTO v_player_count
      FROM public.star_transactions
     WHERE reference_type = 'game_session'
       AND reference_id = p_session_id
       AND transaction_type = 'tournament_entry';

    IF v_player_count < 4 THEN
        -- Minimum 4 players to trigger payout. Refund entries.
        UPDATE public.wallets w
           SET stars_balance = stars_balance + v_entry_per_player, updated_at = now()
          FROM public.star_transactions t
         WHERE t.reference_type = 'game_session'
           AND t.reference_id = p_session_id
           AND t.transaction_type = 'tournament_entry'
           AND w.user_id = t.user_id;

        INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type, reference_id)
        SELECT t.user_id, v_entry_per_player, 'refund', 'Tournament cancelled (min players)', 'game_session', p_session_id
          FROM public.star_transactions t
         WHERE t.reference_type = 'game_session'
           AND t.reference_id = p_session_id
           AND t.transaction_type = 'tournament_entry';
        RETURN;
    END IF;

    v_entry_total := v_entry_per_player * v_player_count;
    v_pool := v_entry_total - floor(v_entry_total * 0.10)::integer; -- 10% platform fee
    v_second := floor(v_pool * 0.35)::integer;
    v_first := v_pool - v_second;                                    -- remainder to 1st

    SELECT user_id INTO v_first_user
      FROM public.game_results
     WHERE session_id = p_session_id AND rank = 1
     LIMIT 1;

    SELECT user_id INTO v_second_user
      FROM public.game_results
     WHERE session_id = p_session_id AND rank = 2
     LIMIT 1;

    IF v_first_user IS NOT NULL AND v_first > 0 THEN
        UPDATE public.wallets SET stars_balance = stars_balance + v_first, updated_at = now()
         WHERE user_id = v_first_user;
        INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type, reference_id)
        VALUES (v_first_user, v_first, 'tournament_reward', 'Tournament 1st place', 'game_session', p_session_id);
    END IF;

    IF v_second_user IS NOT NULL AND v_second > 0 THEN
        UPDATE public.wallets SET stars_balance = stars_balance + v_second, updated_at = now()
         WHERE user_id = v_second_user;
        INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type, reference_id)
        VALUES (v_second_user, v_second, 'tournament_reward', 'Tournament 2nd place', 'game_session', p_session_id);
    END IF;

    -- XP for everyone (participation) + win bonus for rank 1.
    INSERT INTO public.xp_progress(user_id, game_key, xp, matches_played, wins)
    SELECT gr.user_id, gs.game_key, gr.xp_awarded, 1,
           CASE WHEN gr.rank = 1 THEN 1 ELSE 0 END
      FROM public.game_results gr
      JOIN public.game_sessions gs ON gs.id = gr.session_id
     WHERE gr.session_id = p_session_id
    ON CONFLICT (user_id, game_key) DO UPDATE
        SET xp = public.xp_progress.xp + excluded.xp,
            matches_played = public.xp_progress.matches_played + 1,
            wins = public.xp_progress.wins + excluded.wins,
            updated_at = now();
END;
$$;

-- 8. Disable the old single-device star reward RPC (return 0).
CREATE OR REPLACE FUNCTION public.award_single_device_stars(
    p_game_key        text,
    p_is_win          boolean,
    p_idempotency_key uuid
)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    -- Track XP only; no Stars awarded for normal gameplay anymore.
    INSERT INTO public.xp_progress(user_id, game_key, xp, matches_played, wins)
    VALUES (
        v_uid, p_game_key,
        CASE WHEN p_is_win THEN 50 ELSE 20 END,
        1,
        CASE WHEN p_is_win THEN 1 ELSE 0 END
    )
    ON CONFLICT (user_id, game_key) DO UPDATE
        SET xp = public.xp_progress.xp + excluded.xp,
            matches_played = public.xp_progress.matches_played + 1,
            wins = public.xp_progress.wins + excluded.wins,
            updated_at = now();
    RETURN 0;
END;
$$;

-- 9. Starting balance for new wallets = 0 (matches "no farming" rule).
ALTER TABLE public.wallets ALTER COLUMN stars_balance SET DEFAULT 0;
