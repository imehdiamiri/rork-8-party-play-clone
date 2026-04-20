-- ============================================================
-- Star System Hardening
-- Adds server-side RPCs so ALL star mutations go through the DB.
-- Safe to run repeatedly.
-- ============================================================

-- Ensure all Swift-side transaction types are accepted.
ALTER TABLE public.star_transactions
    DROP CONSTRAINT IF EXISTS star_transactions_type_check;

ALTER TABLE public.star_transactions
    ADD CONSTRAINT star_transactions_type_check CHECK (
        transaction_type IN (
            'purchase',
            'reward',
            'tournament_entry',
            'tournament_reward',
            'unlock_purchase',
            'refund',
            'subscription_grant',
            'admin_adjustment',
            'game_reward'
        )
    );

-- 1. award_single_device_stars
-- Called from the client after a single-device match finishes.
-- Grants +2 participation, +10 win, idempotent per idempotency key.
CREATE OR REPLACE FUNCTION public.award_single_device_stars(
    p_game_key        text,
    p_is_win          boolean,
    p_idempotency_key uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_amount integer;
    v_claimed boolean;
    v_reason text;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF p_game_key IS NULL OR length(trim(p_game_key)) = 0 THEN
        RAISE EXCEPTION 'game_key is required';
    END IF;

    v_amount := CASE WHEN p_is_win THEN 10 ELSE 2 END;
    v_reason := CASE WHEN p_is_win
        THEN 'Single-device win reward'
        ELSE 'Single-device participation reward'
    END;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'award_single_device_stars', v_uid);
    IF NOT v_claimed THEN RETURN 0; END IF;

    INSERT INTO public.wallets(user_id, stars_balance)
    VALUES (v_uid, 100)
    ON CONFLICT (user_id) DO NOTHING;

    UPDATE public.wallets
       SET stars_balance = stars_balance + v_amount
     WHERE user_id = v_uid;

    INSERT INTO public.star_transactions(
        user_id, amount, transaction_type, reason,
        reference_type, reference_id, idempotency_key
    )
    VALUES (
        v_uid, v_amount, 'game_reward', v_reason,
        'single_device', NULL, p_idempotency_key
    );

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

    RETURN v_amount;
END;
$$;

GRANT EXECUTE ON FUNCTION public.award_single_device_stars(text, boolean, uuid) TO authenticated;

-- 2. grant_subscription_stars
-- Called on successful RevenueCat purchase / renewal.
-- Idempotent per billing period (p_period_key, e.g. expiration date + product id).
CREATE OR REPLACE FUNCTION public.grant_subscription_stars(
    p_amount     integer,
    p_tier       text,
    p_period_key text,
    p_expires_at timestamptz DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_already integer;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN RETURN 0; END IF;
    IF p_period_key IS NULL OR length(trim(p_period_key)) = 0 THEN
        RAISE EXCEPTION 'period_key is required';
    END IF;

    -- One grant per (user, period_key).
    SELECT count(*) INTO v_already
      FROM public.star_transactions
     WHERE user_id = v_uid
       AND transaction_type = 'subscription_grant'
       AND reference_type = 'billing_period'
       AND reason = p_period_key;

    IF v_already > 0 THEN
        -- Keep subscription record fresh even if we already granted.
        INSERT INTO public.subscriptions(user_id, tier, is_active, expires_at, auto_renews, last_star_grant_date)
        VALUES (v_uid, coalesce(p_tier, 'basic'), true, p_expires_at, true, now())
        ON CONFLICT (user_id) DO UPDATE
            SET tier = coalesce(p_tier, public.subscriptions.tier),
                is_active = true,
                expires_at = coalesce(p_expires_at, public.subscriptions.expires_at),
                auto_renews = true,
                updated_at = now();
        RETURN 0;
    END IF;

    INSERT INTO public.wallets(user_id, stars_balance)
    VALUES (v_uid, 100)
    ON CONFLICT (user_id) DO NOTHING;

    UPDATE public.wallets
       SET stars_balance = stars_balance + p_amount
     WHERE user_id = v_uid;

    INSERT INTO public.star_transactions(
        user_id, amount, transaction_type, reason,
        reference_type, reference_id
    )
    VALUES (
        v_uid, p_amount, 'subscription_grant', p_period_key,
        'billing_period', NULL
    );

    INSERT INTO public.subscriptions(user_id, tier, is_active, expires_at, auto_renews, last_star_grant_date)
    VALUES (v_uid, coalesce(p_tier, 'basic'), true, p_expires_at, true, now())
    ON CONFLICT (user_id) DO UPDATE
        SET tier = coalesce(p_tier, public.subscriptions.tier),
            is_active = true,
            expires_at = coalesce(p_expires_at, public.subscriptions.expires_at),
            auto_renews = true,
            last_star_grant_date = now(),
            updated_at = now();

    RETURN p_amount;
END;
$$;

GRANT EXECUTE ON FUNCTION public.grant_subscription_stars(integer, text, text, timestamptz) TO authenticated;

-- 3. Fix existing RPCs to emit snake_case transaction types (match Swift enum).
CREATE OR REPLACE FUNCTION public.purchase_unlock_item(
    p_item_key        text,
    p_idempotency_key uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $
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
    VALUES (v_uid, -v_price, 'unlock_purchase', 'Store unlock purchase', 'unlock_item', NULL, p_idempotency_key);

    INSERT INTO public.user_unlocks(user_id, item_key)
    VALUES (v_uid, p_item_key)
    ON CONFLICT (user_id, item_key) DO NOTHING;
END;
$;

CREATE OR REPLACE FUNCTION public.distribute_prize_pool(
    p_session_id      uuid,
    p_idempotency_key uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $
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
            VALUES (v_row.user_id, v_row.stars_awarded, 'tournament_reward', 'Tournament payout', 'game_session', p_session_id);
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
$;
