-- ============================================================
-- 8PartyPlay — Server-Validated Invite Reward System
-- Run once; safe to re-run. All rewards granted server-side only.
-- ============================================================

-- 1. Allow 'invite_reward' transaction type.
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
            'invite_reward',
            'signup_bonus',
            'refund',
            'admin_adjustment'
        )
    );

-- 2. Add invite_code + invited_by to profiles.
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS invite_code text UNIQUE,
    ADD COLUMN IF NOT EXISTS invited_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_invite_code ON public.profiles (invite_code);
CREATE INDEX IF NOT EXISTS idx_profiles_invited_by  ON public.profiles (invited_by);

-- 3. Invites table — one row per successful redemption.
CREATE TABLE IF NOT EXISTS public.invites (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    inviter_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invited_user_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invite_code      text NOT NULL,
    status           text NOT NULL DEFAULT 'completed' CHECK (status IN ('pending','completed')),
    created_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (invited_user_id),
    CHECK (inviter_id <> invited_user_id)
);

CREATE INDEX IF NOT EXISTS idx_invites_inviter ON public.invites (inviter_id, created_at DESC);

ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS invites_select_own ON public.invites;
CREATE POLICY invites_select_own ON public.invites
    FOR SELECT USING (
        auth.uid() = inviter_id OR auth.uid() = invited_user_id
    );

-- 4. Invite code generator — 6 uppercase alphanumerics, unique.
CREATE OR REPLACE FUNCTION public.generate_invite_code()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    v_code text;
    v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    v_tries int := 0;
BEGIN
    LOOP
        v_code := '';
        FOR i IN 1..6 LOOP
            v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
        END LOOP;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.profiles WHERE invite_code = v_code);
        v_tries := v_tries + 1;
        IF v_tries > 30 THEN RAISE EXCEPTION 'could not generate invite code'; END IF;
    END LOOP;
    RETURN v_code;
END;
$$;

-- 5. Backfill invite codes for existing users missing one.
UPDATE public.profiles
   SET invite_code = public.generate_invite_code()
 WHERE invite_code IS NULL;

-- 6. ensure_profile_and_wallet — extended so every profile gets an invite_code.
--    We don't replace signup-bonus logic here; we just guarantee invite_code.
CREATE OR REPLACE FUNCTION public.ensure_invite_code_for(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code text;
BEGIN
    SELECT invite_code INTO v_code FROM public.profiles WHERE id = p_user_id;
    IF v_code IS NULL OR length(v_code) = 0 THEN
        v_code := public.generate_invite_code();
        UPDATE public.profiles SET invite_code = v_code WHERE id = p_user_id;
    END IF;
    RETURN v_code;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_invite_code_for(uuid) TO authenticated;

-- 7. get_my_invite_code — returns caller's invite code (ensures one exists).
CREATE OR REPLACE FUNCTION public.get_my_invite_code()
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    RETURN public.ensure_invite_code_for(v_uid);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_invite_code() TO authenticated;

-- 8. get_my_invite_summary — total successful invites + stars earned from invites.
CREATE OR REPLACE FUNCTION public.get_my_invite_summary()
RETURNS TABLE(total_invites int, stars_earned int)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    RETURN QUERY
        SELECT
            COALESCE((SELECT count(*)::int FROM public.invites WHERE inviter_id = v_uid AND status = 'completed'), 0),
            COALESCE((SELECT sum(amount)::int FROM public.star_transactions
                       WHERE user_id = v_uid AND transaction_type = 'invite_reward'), 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_invite_summary() TO authenticated;

-- 9. redeem_invite_code — THE critical server-side reward path.
--    Rules enforced:
--      a. caller must be authenticated
--      b. caller must NOT already have invited_by set (one redemption ever)
--      c. code must exist and belong to a different user (no self-invite)
--      d. caller profile must be young (< 7 days since creation) — prevents
--         established accounts from farming codes from fresh devices
--      e. daily cap: inviter may not earn more than 5 invite rewards / day
--    On success:
--      - +30 stars to inviter
--      - +10 stars welcome to invited user
--      - profiles.invited_by set
--      - invites row inserted (UNIQUE invited_user_id prevents double-reward)
--      - star_transactions rows for both parties
CREATE OR REPLACE FUNCTION public.redeem_invite_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_code text;
    v_inviter uuid;
    v_existing_invited_by uuid;
    v_created_at timestamptz;
    v_today_count int;
    v_inviter_reward int := 30;
    v_invitee_reward int := 10;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_code := upper(trim(coalesce(p_code, '')));
    IF length(v_code) = 0 THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'empty_code');
    END IF;

    SELECT invited_by, created_at INTO v_existing_invited_by, v_created_at
      FROM public.profiles WHERE id = v_uid;

    IF v_existing_invited_by IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'already_redeemed');
    END IF;

    IF v_created_at IS NOT NULL AND v_created_at < now() - interval '7 days' THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'account_too_old');
    END IF;

    SELECT id INTO v_inviter FROM public.profiles WHERE invite_code = v_code;
    IF v_inviter IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'invalid_code');
    END IF;

    IF v_inviter = v_uid THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'self_invite');
    END IF;

    IF EXISTS (SELECT 1 FROM public.invites WHERE invited_user_id = v_uid) THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'already_redeemed');
    END IF;

    SELECT count(*) INTO v_today_count
      FROM public.invites
     WHERE inviter_id = v_inviter
       AND created_at >= (now() at time zone 'utc')::date;

    IF v_today_count >= 5 THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'inviter_daily_limit');
    END IF;

    -- Link invited -> inviter.
    UPDATE public.profiles SET invited_by = v_inviter WHERE id = v_uid;

    -- Insert invite row (unique constraint on invited_user_id prevents duplicates).
    INSERT INTO public.invites(inviter_id, invited_user_id, invite_code, status)
    VALUES (v_inviter, v_uid, v_code, 'completed');

    -- Credit inviter.
    INSERT INTO public.wallets(user_id, stars_balance) VALUES (v_inviter, 0)
        ON CONFLICT (user_id) DO NOTHING;
    UPDATE public.wallets
       SET stars_balance = stars_balance + v_inviter_reward, updated_at = now()
     WHERE user_id = v_inviter;
    INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type, reference_id)
    VALUES (v_inviter, v_inviter_reward, 'invite_reward', 'Invite reward', 'invite', v_uid);

    -- Credit invitee.
    INSERT INTO public.wallets(user_id, stars_balance) VALUES (v_uid, 0)
        ON CONFLICT (user_id) DO NOTHING;
    UPDATE public.wallets
       SET stars_balance = stars_balance + v_invitee_reward, updated_at = now()
     WHERE user_id = v_uid;
    INSERT INTO public.star_transactions(user_id, amount, transaction_type, reason, reference_type, reference_id)
    VALUES (v_uid, v_invitee_reward, 'invite_reward', 'Welcome invite bonus', 'invite', v_inviter);

    RETURN jsonb_build_object(
        'ok', true,
        'inviter_reward', v_inviter_reward,
        'invitee_reward', v_invitee_reward
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_invite_code(text) TO authenticated;
