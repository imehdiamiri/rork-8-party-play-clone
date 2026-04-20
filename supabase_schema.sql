-- ============================================================
-- PartyGames — Production-Safe Supabase Schema
-- Paste into Supabase SQL Editor and run once.
-- Idempotent: safe to re-run (DROP IF EXISTS before CREATE).
-- ============================================================

-- 0. Extensions
create extension if not exists "pgcrypto";

-- ============================================================
-- 1. TABLES
-- ============================================================

-- 1a. profiles
create table if not exists public.profiles (
    id           uuid primary key references auth.users(id) on delete cascade,
    username     text not null,
    email        text,
    public_id    integer unique generated always as identity,
    display_name text,
    avatar_url   text,
    created_at   timestamptz not null default now()
);

create index if not exists idx_profiles_username  on public.profiles (lower(username));
create index if not exists idx_profiles_public_id on public.profiles (public_id);

-- 1b. wallets
create table if not exists public.wallets (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null unique references public.profiles(id) on delete cascade,
    coins_balance   integer not null default 500  check (coins_balance   >= 0),
    credits_balance integer not null default 25   check (credits_balance >= 0),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create index if not exists idx_wallets_user_id on public.wallets (user_id);

-- 1c. coin_transactions
create table if not exists public.coin_transactions (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references public.profiles(id) on delete cascade,
    amount          integer not null,
    reason          text not null default '',
    reference_type  text,
    reference_id    uuid,
    idempotency_key uuid unique,
    created_at      timestamptz not null default now()
);

create index if not exists idx_coin_tx_user       on public.coin_transactions (user_id, created_at desc);
create index if not exists idx_coin_tx_idempotency on public.coin_transactions (idempotency_key) where idempotency_key is not null;

-- 1d. credit_transactions
create table if not exists public.credit_transactions (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references public.profiles(id) on delete cascade,
    amount          integer not null,
    reason          text not null default '',
    reference_type  text,
    reference_id    uuid,
    idempotency_key uuid unique,
    created_at      timestamptz not null default now()
);

create index if not exists idx_credit_tx_user       on public.credit_transactions (user_id, created_at desc);
create index if not exists idx_credit_tx_idempotency on public.credit_transactions (idempotency_key) where idempotency_key is not null;

-- 1e. friendships
create table if not exists public.friendships (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references public.profiles(id) on delete cascade,
    friend_id  uuid not null references public.profiles(id) on delete cascade,
    created_at timestamptz not null default now(),
    unique (user_id, friend_id),
    check (user_id <> friend_id)
);

create index if not exists idx_friendships_user   on public.friendships (user_id);
create index if not exists idx_friendships_friend on public.friendships (friend_id);

-- 1f. friend_requests
create table if not exists public.friend_requests (
    id          uuid primary key default gen_random_uuid(),
    sender_id   uuid not null references public.profiles(id) on delete cascade,
    receiver_id uuid not null references public.profiles(id) on delete cascade,
    status      text not null default 'pending' check (status in ('pending','accepted','declined')),
    created_at  timestamptz not null default now(),
    unique (sender_id, receiver_id),
    check (sender_id <> receiver_id)
);

create index if not exists idx_fr_receiver on public.friend_requests (receiver_id, status);
create index if not exists idx_fr_sender   on public.friend_requests (sender_id, status);

-- 1g. rooms
create table if not exists public.rooms (
    id           uuid primary key default gen_random_uuid(),
    code         text not null unique,
    game_key     text not null,
    host_user_id uuid not null references public.profiles(id) on delete cascade,
    status       text not null default 'lobby' check (status in ('lobby','playing','finished','cancelled')),
    access       text not null default 'private' check (access in ('private','public')),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

create index if not exists idx_rooms_code    on public.rooms (code);
create index if not exists idx_rooms_status  on public.rooms (status) where status = 'lobby';
create index if not exists idx_rooms_host    on public.rooms (host_user_id);

-- 1h. room_members
create table if not exists public.room_members (
    id        uuid primary key default gen_random_uuid(),
    room_id   uuid not null references public.rooms(id) on delete cascade,
    user_id   uuid not null references public.profiles(id) on delete cascade,
    is_host   boolean not null default false,
    is_ready  boolean not null default false,
    joined_at timestamptz not null default now(),
    unique (room_id, user_id)
);

create index if not exists idx_rm_room on public.room_members (room_id);
create index if not exists idx_rm_user on public.room_members (user_id);

-- 1i. room_invites
create table if not exists public.room_invites (
    id              uuid primary key default gen_random_uuid(),
    room_id         uuid not null references public.rooms(id) on delete cascade,
    inviter_user_id uuid not null references public.profiles(id) on delete cascade,
    invited_user_id uuid not null references public.profiles(id) on delete cascade,
    status          text not null default 'pending' check (status in ('pending','accepted','declined','revoked')),
    created_at      timestamptz not null default now(),
    unique (room_id, invited_user_id)
);

create index if not exists idx_ri_invited on public.room_invites (invited_user_id, status);
create index if not exists idx_ri_room    on public.room_invites (room_id);
create index if not exists idx_ri_inviter on public.room_invites (inviter_user_id);

-- 1j. game_sessions
create table if not exists public.game_sessions (
    id            uuid primary key default gen_random_uuid(),
    room_id       uuid references public.rooms(id) on delete set null,
    game_key      text not null,
    mode          text not null,
    status        text not null default 'active' check (status in ('active','finalized','cancelled')),
    created_by    uuid not null references public.profiles(id) on delete cascade,
    session_state jsonb,
    created_at    timestamptz not null default now()
);

create index if not exists idx_gs_room       on public.game_sessions (room_id);
create index if not exists idx_gs_created_by on public.game_sessions (created_by);
create index if not exists idx_gs_status     on public.game_sessions (status) where status = 'active';

-- 1k. game_results
create table if not exists public.game_results (
    id               uuid primary key default gen_random_uuid(),
    session_id       uuid not null references public.game_sessions(id) on delete cascade,
    user_id          uuid not null references public.profiles(id) on delete cascade,
    rank             integer not null default 0,
    score            integer not null default 0,
    coins_awarded    integer not null default 0 check (coins_awarded   >= 0),
    credits_awarded  integer not null default 0 check (credits_awarded >= 0),
    created_at       timestamptz not null default now(),
    unique (session_id, user_id)
);

create index if not exists idx_gr_session on public.game_results (session_id);
create index if not exists idx_gr_user    on public.game_results (user_id);

-- 1l. unlock_items (store / cosmetic unlocks)
create table if not exists public.unlock_items (
    id            uuid primary key default gen_random_uuid(),
    item_key      text not null unique,
    title         text not null,
    description   text,
    price_coins   integer not null default 0 check (price_coins   >= 0),
    price_credits integer not null default 0 check (price_credits >= 0),
    created_at    timestamptz not null default now()
);

-- 1m. user_unlocks
create table if not exists public.user_unlocks (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references public.profiles(id) on delete cascade,
    item_key        text not null references public.unlock_items(item_key) on delete cascade,
    idempotency_key uuid unique,
    created_at      timestamptz not null default now(),
    unique (user_id, item_key)
);

create index if not exists idx_uu_user on public.user_unlocks (user_id);

-- ============================================================
-- 2. TRIGGERS
-- ============================================================

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists trg_wallets_updated_at on public.wallets;
create trigger trg_wallets_updated_at
    before update on public.wallets
    for each row execute function public.set_updated_at();

drop trigger if exists trg_rooms_updated_at on public.rooms;
create trigger trg_rooms_updated_at
    before update on public.rooms
    for each row execute function public.set_updated_at();

-- ============================================================
-- 3. RPC / FUNCTIONS
-- ============================================================

-- 3a. ensure_profile_and_wallet
create or replace function public.ensure_profile_and_wallet(
    p_username text,
    p_email    text default null
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    insert into public.profiles (id, username, email)
    values (v_uid, p_username, p_email)
    on conflict (id) do update
        set username = coalesce(nullif(excluded.username, ''), profiles.username),
            email    = coalesce(excluded.email, profiles.email);

    insert into public.wallets (user_id, coins_balance, credits_balance)
    values (v_uid, 500, 25)
    on conflict (user_id) do nothing;
end;
$$;

-- 3b. search_profiles
create or replace function public.search_profiles(p_query text)
returns table (
    id                 uuid,
    username           text,
    email              text,
    public_id          integer,
    avatar_url         text,
    relationship_state text
)
language plpgsql security definer stable
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    return query
    select
        p.id,
        p.username,
        p.email,
        p.public_id,
        p.avatar_url,
        case
            when p.id = v_uid then 'self'
            when exists (
                select 1 from public.friendships f
                where (f.user_id = v_uid and f.friend_id = p.id)
                   or (f.friend_id = v_uid and f.user_id = p.id)
            ) then 'existing_friend'
            when exists (
                select 1 from public.friend_requests fr
                where fr.sender_id = v_uid and fr.receiver_id = p.id and fr.status = 'pending'
            ) then 'pending_outgoing'
            when exists (
                select 1 from public.friend_requests fr
                where fr.sender_id = p.id and fr.receiver_id = v_uid and fr.status = 'pending'
            ) then 'pending_incoming'
            else 'none'
        end as relationship_state
    from public.profiles p
    where p.id <> v_uid
      and (
        p.username ilike '%' || p_query || '%'
        or p.display_name ilike '%' || p_query || '%'
        or p.public_id::text = p_query
      )
    order by p.username
    limit 25;
end;
$$;

-- 3c. send_friend_request
create or replace function public.send_friend_request(p_receiver_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    if v_uid = p_receiver_id then
        raise exception 'Cannot send a friend request to yourself.';
    end if;

    if not exists (select 1 from public.profiles where id = p_receiver_id) then
        raise exception 'User not found.';
    end if;

    if exists (
        select 1 from public.friendships
        where (user_id = v_uid and friend_id = p_receiver_id)
           or (friend_id = v_uid and user_id = p_receiver_id)
    ) then
        raise exception 'Already friends.';
    end if;

    insert into public.friend_requests (sender_id, receiver_id, status)
    values (v_uid, p_receiver_id, 'pending')
    on conflict (sender_id, receiver_id) do update
        set status     = 'pending',
            created_at = now()
        where friend_requests.status = 'declined';

    if not found then
        insert into public.friend_requests (sender_id, receiver_id, status)
        values (v_uid, p_receiver_id, 'pending')
        on conflict (sender_id, receiver_id) do nothing;
    end if;
end;
$$;

-- 3d. accept_friend_request
create or replace function public.accept_friend_request(p_request_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid       uuid := auth.uid();
    v_sender_id uuid;
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    select sender_id into v_sender_id
    from public.friend_requests
    where id = p_request_id and receiver_id = v_uid and status = 'pending';

    if v_sender_id is null then
        raise exception 'Friend request not found or already handled.';
    end if;

    update public.friend_requests
    set status = 'accepted'
    where id = p_request_id;

    insert into public.friendships (user_id, friend_id)
    values (least(v_sender_id, v_uid), greatest(v_sender_id, v_uid))
    on conflict (user_id, friend_id) do nothing;
end;
$$;

-- 3e. decline_friend_request
create or replace function public.decline_friend_request(p_request_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    update public.friend_requests
    set status = 'declined'
    where id = p_request_id and receiver_id = v_uid and status = 'pending';
end;
$$;

-- 3f. remove_friend
create or replace function public.remove_friend(p_friend_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    delete from public.friendships
    where (user_id = v_uid and friend_id = p_friend_id)
       or (friend_id = v_uid and user_id = p_friend_id);

    update public.friend_requests
    set status = 'declined'
    where ((sender_id = v_uid and receiver_id = p_friend_id)
        or (sender_id = p_friend_id and receiver_id = v_uid))
      and status = 'accepted';
end;
$$;

-- 3g. update_profile_settings
create or replace function public.update_profile_settings(
    p_username     text,
    p_display_name text,
    p_public_id    integer default null,
    p_avatar_url   text default null
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    update public.profiles
    set username     = coalesce(nullif(p_username, ''), username),
        display_name = coalesce(nullif(p_display_name, ''), display_name),
        avatar_url   = coalesce(p_avatar_url, avatar_url)
    where id = v_uid;
end;
$$;

-- 3h. finalize_game_results
create or replace function public.finalize_game_results(
    p_session_id      uuid,
    p_idempotency_key uuid
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    if not exists (
        select 1 from public.game_sessions
        where id = p_session_id and created_by = v_uid
    ) then
        raise exception 'Not the session owner.';
    end if;

    if exists (select 1 from public.coin_transactions where idempotency_key = p_idempotency_key) then
        return;
    end if;

    update public.game_sessions
    set status = 'finalized'
    where id = p_session_id and status = 'active';
end;
$$;

-- 3i. distribute_prize_pool
create or replace function public.distribute_prize_pool(
    p_session_id      uuid,
    p_idempotency_key uuid
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    r     record;
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    if not exists (
        select 1 from public.game_sessions
        where id = p_session_id and created_by = v_uid
    ) then
        raise exception 'Not the session owner.';
    end if;

    if exists (select 1 from public.coin_transactions where idempotency_key = p_idempotency_key) then
        return;
    end if;

    for r in
        select gr.user_id, gr.coins_awarded
        from public.game_results gr
        where gr.session_id = p_session_id and gr.coins_awarded > 0
    loop
        insert into public.coin_transactions (user_id, amount, reason, reference_type, reference_id, idempotency_key)
        values (r.user_id, r.coins_awarded, 'prize_payout', 'game_session', p_session_id, gen_random_uuid());

        update public.wallets
        set coins_balance = coins_balance + r.coins_awarded
        where user_id = r.user_id;
    end loop;

    insert into public.coin_transactions (user_id, amount, reason, reference_type, reference_id, idempotency_key)
    values (v_uid, 0, 'prize_payout_marker', 'game_session', p_session_id, p_idempotency_key);
end;
$$;

-- 3j. grant_reward_credits
create or replace function public.grant_reward_credits(
    p_session_id      uuid,
    p_idempotency_key uuid
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    r     record;
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    if not exists (
        select 1 from public.game_sessions
        where id = p_session_id and created_by = v_uid
    ) then
        raise exception 'Not the session owner.';
    end if;

    if exists (select 1 from public.credit_transactions where idempotency_key = p_idempotency_key) then
        return;
    end if;

    for r in
        select gr.user_id, gr.credits_awarded
        from public.game_results gr
        where gr.session_id = p_session_id and gr.credits_awarded > 0
    loop
        insert into public.credit_transactions (user_id, amount, reason, reference_type, reference_id, idempotency_key)
        values (r.user_id, r.credits_awarded, 'game_reward', 'game_session', p_session_id, gen_random_uuid());

        update public.wallets
        set credits_balance = credits_balance + r.credits_awarded
        where user_id = r.user_id;
    end loop;

    insert into public.credit_transactions (user_id, amount, reason, reference_type, reference_id, idempotency_key)
    values (v_uid, 0, 'reward_marker', 'game_session', p_session_id, p_idempotency_key);
end;
$$;

-- 3k. create_entry_fee_record
create or replace function public.create_entry_fee_record(
    p_room_id         uuid,
    p_amount          integer,
    p_currency        text,
    p_idempotency_key uuid
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    if p_amount <= 0 then
        raise exception 'Entry fee must be positive.';
    end if;

    if p_currency = 'coins' then
        if exists (select 1 from public.coin_transactions where idempotency_key = p_idempotency_key) then
            return;
        end if;

        update public.wallets
        set coins_balance = coins_balance - p_amount
        where user_id = v_uid and coins_balance >= p_amount;

        if not found then
            raise exception 'Insufficient coin balance for entry fee.';
        end if;

        insert into public.coin_transactions (user_id, amount, reason, reference_type, reference_id, idempotency_key)
        values (v_uid, -p_amount, 'entry_fee', 'room', p_room_id, p_idempotency_key);

    elsif p_currency = 'credits' then
        if exists (select 1 from public.credit_transactions where idempotency_key = p_idempotency_key) then
            return;
        end if;

        update public.wallets
        set credits_balance = credits_balance - p_amount
        where user_id = v_uid and credits_balance >= p_amount;

        if not found then
            raise exception 'Insufficient credit balance for entry fee.';
        end if;

        insert into public.credit_transactions (user_id, amount, reason, reference_type, reference_id, idempotency_key)
        values (v_uid, -p_amount, 'entry_fee', 'room', p_room_id, p_idempotency_key);

    else
        raise exception 'Unknown currency: %', p_currency;
    end if;
end;
$$;

-- 3l. convert_coins_to_credits
create or replace function public.convert_coins_to_credits(
    p_amount          integer,
    p_idempotency_key uuid
)
returns public.wallets
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid     uuid := auth.uid();
    v_credits integer;
    v_wallet  public.wallets;
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    if exists (select 1 from public.coin_transactions where idempotency_key = p_idempotency_key) then
        select * into v_wallet from public.wallets where user_id = v_uid;
        return v_wallet;
    end if;

    if p_amount < 10 then
        raise exception 'Minimum 10 coins required for conversion.';
    end if;

    v_credits := p_amount / 10;

    update public.wallets
    set coins_balance   = coins_balance - p_amount,
        credits_balance = credits_balance + v_credits
    where user_id = v_uid and coins_balance >= p_amount;

    if not found then
        raise exception 'Insufficient coin balance for conversion.';
    end if;

    insert into public.coin_transactions (user_id, amount, reason, reference_type, reference_id, idempotency_key)
    values (v_uid, -p_amount, 'conversion_to_credits', 'wallet', v_uid, p_idempotency_key);

    insert into public.credit_transactions (user_id, amount, reason, reference_type, reference_id, idempotency_key)
    values (v_uid, v_credits, 'conversion_from_coins', 'wallet', v_uid, gen_random_uuid());

    select * into v_wallet from public.wallets where user_id = v_uid;
    return v_wallet;
end;
$$;

-- 3m. purchase_unlock_item
drop function if exists public.purchase_unlock_item(text, uuid);
create or replace function public.purchase_unlock_item(
    p_item_key        text,
    p_idempotency_key uuid
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
    v_uid         uuid := auth.uid();
    v_price_coins integer;
    v_price_creds integer;
begin
    if v_uid is null then
        raise exception 'Not authenticated.';
    end if;

    if exists (select 1 from public.user_unlocks where user_id = v_uid and item_key = p_item_key) then
        return;
    end if;

    select price_coins, price_credits into v_price_coins, v_price_creds
    from public.unlock_items
    where item_key = p_item_key;

    if not found then
        raise exception 'Item not found: %', p_item_key;
    end if;

    if v_price_coins > 0 then
        update public.wallets
        set coins_balance = coins_balance - v_price_coins
        where user_id = v_uid and coins_balance >= v_price_coins;

        if not found then
            raise exception 'Insufficient coins for this item.';
        end if;

        insert into public.coin_transactions (user_id, amount, reason, reference_type, reference_id, idempotency_key)
        values (v_uid, -v_price_coins, 'unlock_purchase', 'unlock_item', null, p_idempotency_key);
    end if;

    if v_price_creds > 0 then
        update public.wallets
        set credits_balance = credits_balance - v_price_creds
        where user_id = v_uid and credits_balance >= v_price_creds;

        if not found then
            raise exception 'Insufficient credits for this item.';
        end if;

        insert into public.credit_transactions (user_id, amount, reason, reference_type, reference_id, idempotency_key)
        values (v_uid, -v_price_creds, 'unlock_purchase', 'unlock_item', null, gen_random_uuid());
    end if;

    insert into public.user_unlocks (user_id, item_key, idempotency_key)
    values (v_uid, p_item_key, p_idempotency_key)
    on conflict (user_id, item_key) do nothing;
end;
$$;

-- ============================================================
-- 4. ROW LEVEL SECURITY (RLS)
-- ============================================================

alter table public.profiles             enable row level security;
alter table public.wallets              enable row level security;
alter table public.coin_transactions    enable row level security;
alter table public.credit_transactions  enable row level security;
alter table public.friendships          enable row level security;
alter table public.friend_requests      enable row level security;
alter table public.rooms                enable row level security;
alter table public.room_members         enable row level security;
alter table public.room_invites         enable row level security;
alter table public.game_sessions        enable row level security;
alter table public.game_results         enable row level security;
alter table public.unlock_items         enable row level security;
alter table public.user_unlocks         enable row level security;

-- ── profiles ────────────────────────────────────────────────
drop policy if exists "profiles_select" on public.profiles;
drop policy if exists "profiles_insert" on public.profiles;
drop policy if exists "profiles_update" on public.profiles;

create policy "profiles_select" on public.profiles for select using (true);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- ── wallets ─────────────────────────────────────────────────
-- SELECT only. All balance mutations via security-definer RPCs.
-- INSERT kept for bootstrap upsert fallback from app code.
drop policy if exists "wallets_select_own" on public.wallets;
drop policy if exists "wallets_insert_own" on public.wallets;
drop policy if exists "wallets_update_own" on public.wallets;

create policy "wallets_select_own" on public.wallets for select
    using (auth.uid() = user_id);
create policy "wallets_insert_own" on public.wallets for insert
    with check (auth.uid() = user_id AND coins_balance = 500 AND credits_balance = 25);

-- ── coin_transactions ───────────────────────────────────────
-- SELECT only. All inserts via security-definer RPCs.
drop policy if exists "coin_tx_select_own" on public.coin_transactions;
drop policy if exists "coin_tx_insert_own" on public.coin_transactions;

create policy "coin_tx_select_own" on public.coin_transactions for select
    using (auth.uid() = user_id);

-- ── credit_transactions ─────────────────────────────────────
-- SELECT only. All inserts via security-definer RPCs.
drop policy if exists "credit_tx_select_own" on public.credit_transactions;
drop policy if exists "credit_tx_insert_own" on public.credit_transactions;

create policy "credit_tx_select_own" on public.credit_transactions for select
    using (auth.uid() = user_id);

-- ── friendships ─────────────────────────────────────────────
-- SELECT + DELETE only. Inserts via accept_friend_request RPC.
drop policy if exists "friendships_select" on public.friendships;
drop policy if exists "friendships_insert" on public.friendships;
drop policy if exists "friendships_delete" on public.friendships;

create policy "friendships_select" on public.friendships for select
    using (auth.uid() = user_id or auth.uid() = friend_id);
create policy "friendships_delete" on public.friendships for delete
    using (auth.uid() = user_id or auth.uid() = friend_id);

-- ── friend_requests ─────────────────────────────────────────
-- SELECT only. All mutations via security-definer RPCs.
drop policy if exists "fr_select" on public.friend_requests;
drop policy if exists "fr_insert" on public.friend_requests;
drop policy if exists "fr_update" on public.friend_requests;

create policy "fr_select" on public.friend_requests for select
    using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- ── rooms ───────────────────────────────────────────────────
drop policy if exists "rooms_select" on public.rooms;
drop policy if exists "rooms_insert" on public.rooms;
drop policy if exists "rooms_update" on public.rooms;

create policy "rooms_select" on public.rooms for select using (true);
create policy "rooms_insert" on public.rooms for insert
    with check (auth.uid() = host_user_id);
create policy "rooms_update" on public.rooms for update
    using (auth.uid() = host_user_id);

-- ── room_members ────────────────────────────────────────────
drop policy if exists "rm_select" on public.room_members;
drop policy if exists "rm_insert" on public.room_members;
drop policy if exists "rm_update" on public.room_members;
drop policy if exists "rm_delete" on public.room_members;

create policy "rm_select" on public.room_members for select using (true);
create policy "rm_insert" on public.room_members for insert
    with check (auth.uid() = user_id);
create policy "rm_update" on public.room_members for update
    using (auth.uid() = user_id);
create policy "rm_delete" on public.room_members for delete
    using (auth.uid() = user_id);

-- ── room_invites ────────────────────────────────────────────
drop policy if exists "ri_select" on public.room_invites;
drop policy if exists "ri_insert" on public.room_invites;
drop policy if exists "ri_update" on public.room_invites;

create policy "ri_select" on public.room_invites for select
    using (auth.uid() = inviter_user_id or auth.uid() = invited_user_id);
create policy "ri_insert" on public.room_invites for insert
    with check (auth.uid() = inviter_user_id);
create policy "ri_update" on public.room_invites for update
    using (auth.uid() = inviter_user_id or auth.uid() = invited_user_id);

-- ── game_sessions ───────────────────────────────────────────
drop policy if exists "gs_select" on public.game_sessions;
drop policy if exists "gs_insert" on public.game_sessions;
drop policy if exists "gs_update" on public.game_sessions;

create policy "gs_select" on public.game_sessions for select using (true);
create policy "gs_insert" on public.game_sessions for insert
    with check (auth.uid() = created_by);
create policy "gs_update" on public.game_sessions for update
    using (auth.uid() = created_by);

-- ── game_results ────────────────────────────────────────────
drop policy if exists "gr_select" on public.game_results;
drop policy if exists "gr_insert" on public.game_results;
drop policy if exists "gr_update" on public.game_results;

create policy "gr_select" on public.game_results for select using (true);
create policy "gr_insert" on public.game_results for insert with check (
    exists (select 1 from public.game_sessions gs where gs.id = session_id and gs.created_by = auth.uid())
);
create policy "gr_update" on public.game_results for update using (
    exists (select 1 from public.game_sessions gs where gs.id = session_id and gs.created_by = auth.uid())
);

-- ── unlock_items ────────────────────────────────────────────
drop policy if exists "ui_select" on public.unlock_items;

create policy "ui_select" on public.unlock_items for select using (true);

-- ── user_unlocks ────────────────────────────────────────────
drop policy if exists "uu_select_own" on public.user_unlocks;
drop policy if exists "uu_insert_own" on public.user_unlocks;

create policy "uu_select_own" on public.user_unlocks for select
    using (auth.uid() = user_id);

-- ============================================================
-- 5. REALTIME
-- ============================================================

do $$
begin
    alter publication supabase_realtime add table public.rooms;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter publication supabase_realtime add table public.room_members;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter publication supabase_realtime add table public.game_sessions;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter publication supabase_realtime add table public.friendships;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter publication supabase_realtime add table public.friend_requests;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter publication supabase_realtime add table public.room_invites;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter publication supabase_realtime add table public.wallets;
exception when duplicate_object then null;
end $$;

-- ============================================================
-- 6. GRANTS (ensure supabase_auth_admin can call RPCs)
-- ============================================================

grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant execute on all functions in schema public to anon, authenticated, service_role;
