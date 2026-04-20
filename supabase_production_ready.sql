-- ============================================================
-- 888Play / PartyGames — Production-ready Supabase schema
-- Aligned with current native iOS code in ios/PartyGames
-- Safe to run in Supabase SQL editor
-- ============================================================

create extension if not exists "pgcrypto";

-- ============================================================
-- 1. TABLES
-- ============================================================

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    username text not null,
    email text,
    public_id integer generated always as identity unique,
    display_name text,
    avatar_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint profiles_username_length check (char_length(trim(username)) between 2 and 24)
);

create unique index if not exists idx_profiles_username_unique on public.profiles (lower(username));
create index if not exists idx_profiles_public_id on public.profiles (public_id);

create table if not exists public.wallets (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null unique references public.profiles(id) on delete cascade,
    stars_balance integer not null default 100 check (stars_balance >= 0),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_wallets_user_id on public.wallets (user_id);

create table if not exists public.star_transactions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    amount integer not null,
    transaction_type text not null,
    reason text not null default '',
    reference_type text,
    reference_id uuid,
    idempotency_key uuid unique,
    created_at timestamptz not null default now(),
    constraint star_transactions_type_check check (
        transaction_type in (
            'reward',
            'purchase',
            'unlockPurchase',
            'gameReward',
            'subscriptionGrant',
            'refund'
        )
    )
);

create index if not exists idx_star_transactions_user_created on public.star_transactions (user_id, created_at desc);
create index if not exists idx_star_transactions_idempotency on public.star_transactions (idempotency_key) where idempotency_key is not null;

create table if not exists public.xp_progress (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    game_key text not null,
    xp integer not null default 0 check (xp >= 0),
    matches_played integer not null default 0 check (matches_played >= 0),
    wins integer not null default 0 check (wins >= 0),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, game_key)
);

create index if not exists idx_xp_progress_user_id on public.xp_progress (user_id);

create table if not exists public.game_trials (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    game_key text not null,
    times_played integer not null default 0 check (times_played >= 0),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, game_key)
);

create index if not exists idx_game_trials_user_id on public.game_trials (user_id);

create table if not exists public.game_unlocks (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    game_key text not null,
    unlocked_at timestamptz not null default now(),
    unique (user_id, game_key)
);

create index if not exists idx_game_unlocks_user_id on public.game_unlocks (user_id);

create table if not exists public.subscriptions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    tier text not null,
    is_active boolean not null default false,
    expires_at timestamptz,
    auto_renews boolean not null default false,
    last_star_grant_date timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id)
);

create index if not exists idx_subscriptions_active on public.subscriptions (user_id) where is_active = true;

create table if not exists public.friendships (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    friend_id uuid not null references public.profiles(id) on delete cascade,
    created_at timestamptz not null default now(),
    constraint friendships_not_same check (user_id <> friend_id),
    constraint friendships_pair_sorted check (user_id < friend_id),
    unique (user_id, friend_id)
);

create index if not exists idx_friendships_user_id on public.friendships (user_id);
create index if not exists idx_friendships_friend_id on public.friendships (friend_id);

create table if not exists public.friend_requests (
    id uuid primary key default gen_random_uuid(),
    sender_id uuid not null references public.profiles(id) on delete cascade,
    receiver_id uuid not null references public.profiles(id) on delete cascade,
    status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint friend_requests_not_same check (sender_id <> receiver_id),
    unique (sender_id, receiver_id)
);

create index if not exists idx_friend_requests_receiver on public.friend_requests (receiver_id, status, created_at desc);
create index if not exists idx_friend_requests_sender on public.friend_requests (sender_id, status, created_at desc);

create table if not exists public.rooms (
    id uuid primary key default gen_random_uuid(),
    code text not null unique,
    game_key text not null,
    host_user_id uuid not null references public.profiles(id) on delete cascade,
    status text not null default 'lobby' check (status in ('lobby', 'playing', 'finished', 'cancelled')),
    access text not null default 'private' check (access in ('private', 'public')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint rooms_code_format check (code = upper(code) and char_length(code) between 4 and 8)
);

create index if not exists idx_rooms_status_created on public.rooms (status, created_at desc);
create index if not exists idx_rooms_host on public.rooms (host_user_id);

create table if not exists public.room_members (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references public.rooms(id) on delete cascade,
    user_id uuid not null references public.profiles(id) on delete cascade,
    is_host boolean not null default false,
    is_ready boolean not null default false,
    joined_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (room_id, user_id)
);

create index if not exists idx_room_members_room_id on public.room_members (room_id, joined_at asc);
create index if not exists idx_room_members_user_id on public.room_members (user_id);

create table if not exists public.room_invites (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references public.rooms(id) on delete cascade,
    inviter_user_id uuid not null references public.profiles(id) on delete cascade,
    invited_user_id uuid not null references public.profiles(id) on delete cascade,
    status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'revoked')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint room_invites_not_same check (inviter_user_id <> invited_user_id),
    unique (room_id, invited_user_id)
);

create index if not exists idx_room_invites_invited on public.room_invites (invited_user_id, status, created_at desc);
create index if not exists idx_room_invites_room on public.room_invites (room_id);

create table if not exists public.game_sessions (
    id uuid primary key,
    room_id uuid references public.rooms(id) on delete set null,
    game_key text not null,
    mode text not null,
    status text not null default 'active' check (status in ('active', 'finalized', 'cancelled')),
    created_by uuid not null references public.profiles(id) on delete cascade,
    session_state jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_game_sessions_room on public.game_sessions (room_id, created_at desc);
create index if not exists idx_game_sessions_created_by on public.game_sessions (created_by);
create index if not exists idx_game_sessions_status on public.game_sessions (status);

create table if not exists public.game_results (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references public.game_sessions(id) on delete cascade,
    user_id uuid not null references public.profiles(id) on delete cascade,
    rank integer not null check (rank >= 1),
    score integer not null default 0,
    stars_awarded integer not null default 0 check (stars_awarded >= 0),
    xp_awarded integer not null default 0 check (xp_awarded >= 0),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (session_id, user_id)
);

create index if not exists idx_game_results_session on public.game_results (session_id, rank asc);
create index if not exists idx_game_results_user on public.game_results (user_id, created_at desc);

create table if not exists public.unlock_items (
    id uuid primary key default gen_random_uuid(),
    item_key text not null unique,
    title text not null,
    description text,
    price_stars integer not null default 0 check (price_stars >= 0),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.user_unlocks (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    item_key text not null references public.unlock_items(item_key) on delete cascade,
    created_at timestamptz not null default now(),
    unique (user_id, item_key)
);

create index if not exists idx_user_unlocks_user on public.user_unlocks (user_id, created_at desc);

create table if not exists public.reward_idempotency (
    key uuid primary key,
    scope text not null,
    owner_user_id uuid references public.profiles(id) on delete cascade,
    created_at timestamptz not null default now()
);

create index if not exists idx_reward_idempotency_owner on public.reward_idempotency (owner_user_id, created_at desc);

-- ============================================================
-- 2. TRIGGERS
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists wallets_set_updated_at on public.wallets;
create trigger wallets_set_updated_at before update on public.wallets
for each row execute function public.set_updated_at();

drop trigger if exists xp_progress_set_updated_at on public.xp_progress;
create trigger xp_progress_set_updated_at before update on public.xp_progress
for each row execute function public.set_updated_at();

drop trigger if exists game_trials_set_updated_at on public.game_trials;
create trigger game_trials_set_updated_at before update on public.game_trials
for each row execute function public.set_updated_at();

drop trigger if exists subscriptions_set_updated_at on public.subscriptions;
create trigger subscriptions_set_updated_at before update on public.subscriptions
for each row execute function public.set_updated_at();

drop trigger if exists friend_requests_set_updated_at on public.friend_requests;
create trigger friend_requests_set_updated_at before update on public.friend_requests
for each row execute function public.set_updated_at();

drop trigger if exists rooms_set_updated_at on public.rooms;
create trigger rooms_set_updated_at before update on public.rooms
for each row execute function public.set_updated_at();

drop trigger if exists room_members_set_updated_at on public.room_members;
create trigger room_members_set_updated_at before update on public.room_members
for each row execute function public.set_updated_at();

drop trigger if exists room_invites_set_updated_at on public.room_invites;
create trigger room_invites_set_updated_at before update on public.room_invites
for each row execute function public.set_updated_at();

drop trigger if exists game_sessions_set_updated_at on public.game_sessions;
create trigger game_sessions_set_updated_at before update on public.game_sessions
for each row execute function public.set_updated_at();

drop trigger if exists game_results_set_updated_at on public.game_results;
create trigger game_results_set_updated_at before update on public.game_results
for each row execute function public.set_updated_at();

drop trigger if exists unlock_items_set_updated_at on public.unlock_items;
create trigger unlock_items_set_updated_at before update on public.unlock_items
for each row execute function public.set_updated_at();

-- ============================================================
-- 3. HELPERS
-- ============================================================

create or replace function public.room_is_visible_to_user(p_room_id uuid, p_user_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
    select exists (
        select 1
        from public.rooms r
        where r.id = p_room_id
          and (
              r.access = 'public'
              or r.host_user_id = p_user_id
              or exists (
                  select 1
                  from public.room_members rm
                  where rm.room_id = r.id
                    and rm.user_id = p_user_id
              )
              or exists (
                  select 1
                  from public.room_invites ri
                  where ri.room_id = r.id
                    and ri.invited_user_id = p_user_id
                    and ri.status in ('pending', 'accepted')
              )
          )
    );
$$;

create or replace function public.is_room_host(p_room_id uuid, p_user_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
    select exists (
        select 1
        from public.rooms r
        where r.id = p_room_id
          and r.host_user_id = p_user_id
    );
$$;

create or replace function public.claim_idempotency_key(p_key uuid, p_scope text, p_owner_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.reward_idempotency(key, scope, owner_user_id)
    values (p_key, p_scope, p_owner_user_id);
    return true;
exception
    when unique_violation then
        return false;
end;
$$;

-- ============================================================
-- 4. RPC FUNCTIONS USED BY THE iOS APP
-- ============================================================

create or replace function public.ensure_profile_and_wallet(
    p_username text,
    p_email text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_username text := lower(trim(coalesce(p_username, '')));
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    if v_username = '' then
        raise exception 'Username is required';
    end if;

    insert into public.profiles(id, username, email, display_name)
    values (v_uid, v_username, p_email, v_username)
    on conflict (id) do update
        set username = excluded.username,
            email = coalesce(excluded.email, public.profiles.email),
            display_name = coalesce(public.profiles.display_name, excluded.display_name);

    insert into public.wallets(user_id, stars_balance)
    values (v_uid, 100)
    on conflict (user_id) do nothing;
end;
$$;

create or replace function public.update_profile_settings(
    p_username text,
    p_display_name text,
    p_public_id integer default null,
    p_avatar_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_username text := lower(trim(coalesce(p_username, '')));
    v_display_name text := trim(coalesce(p_display_name, ''));
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    if v_username = '' then
        raise exception 'Username is required';
    end if;

    update public.profiles
    set username = v_username,
        display_name = case when v_display_name = '' then username else v_display_name end,
        avatar_url = p_avatar_url
    where id = v_uid;
end;
$$;

create or replace function public.search_profiles(p_query text)
returns table (
    id uuid,
    username text,
    email text,
    public_id integer,
    avatar_url text,
    relationship_state text
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_query text := trim(coalesce(p_query, ''));
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    if v_query = '' then
        return;
    end if;

    return query
    select
        p.id,
        p.username,
        p.email,
        p.public_id,
        p.avatar_url,
        case
            when exists (
                select 1
                from public.friendships f
                where (f.user_id = least(v_uid, p.id) and f.friend_id = greatest(v_uid, p.id))
            ) then 'existing_friend'
            when exists (
                select 1
                from public.friend_requests fr
                where fr.sender_id = v_uid and fr.receiver_id = p.id and fr.status = 'pending'
            ) then 'pending_outgoing'
            when exists (
                select 1
                from public.friend_requests fr
                where fr.sender_id = p.id and fr.receiver_id = v_uid and fr.status = 'pending'
            ) then 'pending_incoming'
            else 'none'
        end as relationship_state
    from public.profiles p
    where p.id <> v_uid
      and (
          p.username ilike '%' || v_query || '%'
          or coalesce(p.display_name, '') ilike '%' || v_query || '%'
          or p.public_id::text = v_query
      )
    order by p.username asc
    limit 25;
end;
$$;

create or replace function public.send_friend_request(p_receiver_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    if v_uid = p_receiver_id then
        raise exception 'Cannot friend yourself';
    end if;

    if exists (
        select 1
        from public.friendships f
        where f.user_id = least(v_uid, p_receiver_id)
          and f.friend_id = greatest(v_uid, p_receiver_id)
    ) then
        return;
    end if;

    insert into public.friend_requests(sender_id, receiver_id, status)
    values (v_uid, p_receiver_id, 'pending')
    on conflict (sender_id, receiver_id) do update
        set status = 'pending',
            updated_at = now();
end;
$$;

create or replace function public.accept_friend_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_sender_id uuid;
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    select sender_id into v_sender_id
    from public.friend_requests
    where id = p_request_id
      and receiver_id = v_uid
      and status = 'pending';

    if v_sender_id is null then
        raise exception 'Friend request not found';
    end if;

    update public.friend_requests
    set status = 'accepted',
        updated_at = now()
    where id = p_request_id;

    insert into public.friendships(user_id, friend_id)
    values (least(v_uid, v_sender_id), greatest(v_uid, v_sender_id))
    on conflict (user_id, friend_id) do nothing;
end;
$$;

create or replace function public.decline_friend_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    update public.friend_requests
    set status = 'declined',
        updated_at = now()
    where id = p_request_id
      and receiver_id = v_uid
      and status = 'pending';
end;
$$;

create or replace function public.create_entry_fee_record(
    p_room_id uuid,
    p_amount integer,
    p_currency text,
    p_idempotency_key uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_claimed boolean;
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    if p_currency <> 'stars' then
        raise exception 'Unsupported currency: %', p_currency;
    end if;

    if p_amount < 0 then
        raise exception 'Amount must be non-negative';
    end if;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'entry_fee', v_uid);
    if not v_claimed then
        return;
    end if;

    if p_amount = 0 then
        return;
    end if;

    update public.wallets
    set stars_balance = stars_balance - p_amount
    where user_id = v_uid
      and stars_balance >= p_amount;

    if not found then
        raise exception 'Insufficient Stars';
    end if;

    insert into public.star_transactions(
        user_id,
        amount,
        transaction_type,
        reason,
        reference_type,
        reference_id,
        idempotency_key
    )
    values (
        v_uid,
        -p_amount,
        'unlockPurchase',
        'Room entry fee',
        'room',
        p_room_id,
        p_idempotency_key
    );
end;
$$;

create or replace function public.purchase_unlock_item(
    p_item_key text,
    p_idempotency_key uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_price integer;
    v_claimed boolean;
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    select price_stars into v_price
    from public.unlock_items
    where item_key = p_item_key;

    if v_price is null then
        raise exception 'Unlock item not found';
    end if;

    if exists (
        select 1
        from public.user_unlocks
        where user_id = v_uid
          and item_key = p_item_key
    ) then
        return;
    end if;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'purchase_unlock_item', v_uid);
    if not v_claimed then
        return;
    end if;

    update public.wallets
    set stars_balance = stars_balance - v_price
    where user_id = v_uid
      and stars_balance >= v_price;

    if not found then
        raise exception 'Insufficient Stars';
    end if;

    insert into public.star_transactions(
        user_id,
        amount,
        transaction_type,
        reason,
        reference_type,
        reference_id,
        idempotency_key
    )
    values (
        v_uid,
        -v_price,
        'unlockPurchase',
        'Store unlock purchase',
        'unlock_item',
        null,
        p_idempotency_key
    );

    insert into public.user_unlocks(user_id, item_key)
    values (v_uid, p_item_key)
    on conflict (user_id, item_key) do nothing;
end;
$$;

create or replace function public.finalize_game_results(
    p_session_id uuid,
    p_idempotency_key uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_claimed boolean;
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    if not exists (
        select 1
        from public.game_sessions gs
        where gs.id = p_session_id
          and gs.created_by = v_uid
    ) then
        raise exception 'Only session owner can finalize';
    end if;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'finalize_game_results', v_uid);
    if not v_claimed then
        return;
    end if;

    update public.game_sessions
    set status = 'finalized',
        updated_at = now()
    where id = p_session_id
      and status <> 'finalized';
end;
$$;

create or replace function public.distribute_prize_pool(
    p_session_id uuid,
    p_idempotency_key uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_claimed boolean;
    v_row record;
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    if not exists (
        select 1
        from public.game_sessions gs
        where gs.id = p_session_id
          and gs.created_by = v_uid
    ) then
        raise exception 'Only session owner can distribute rewards';
    end if;

    v_claimed := public.claim_idempotency_key(p_idempotency_key, 'distribute_prize_pool', v_uid);
    if not v_claimed then
        return;
    end if;

    for v_row in
        select gr.user_id, gr.stars_awarded, gr.xp_awarded, gs.game_key
        from public.game_results gr
        join public.game_sessions gs on gs.id = gr.session_id
        where gr.session_id = p_session_id
    loop
        if v_row.stars_awarded > 0 then
            update public.wallets
            set stars_balance = stars_balance + v_row.stars_awarded
            where user_id = v_row.user_id;

            insert into public.star_transactions(
                user_id,
                amount,
                transaction_type,
                reason,
                reference_type,
                reference_id
            )
            values (
                v_row.user_id,
                v_row.stars_awarded,
                'gameReward',
                'Game reward payout',
                'game_session',
                p_session_id
            );
        end if;

        insert into public.xp_progress(user_id, game_key, xp, matches_played, wins)
        values (
            v_row.user_id,
            v_row.game_key,
            v_row.xp_awarded,
            1,
            case when exists (
                select 1
                from public.game_results gr2
                where gr2.session_id = p_session_id
                  and gr2.user_id = v_row.user_id
                  and gr2.rank = 1
            ) then 1 else 0 end
        )
        on conflict (user_id, game_key) do update
            set xp = public.xp_progress.xp + excluded.xp,
                matches_played = public.xp_progress.matches_played + 1,
                wins = public.xp_progress.wins + excluded.wins,
                updated_at = now();
    end loop;
end;
$$;

-- Optional backend helper for App Store account deletion flow.
-- iOS still needs UI + auth deletion orchestration.
create or replace function public.delete_my_account_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    delete from public.room_invites where invited_user_id = v_uid or inviter_user_id = v_uid;
    delete from public.room_members where user_id = v_uid;
    delete from public.rooms where host_user_id = v_uid;
    delete from public.friend_requests where sender_id = v_uid or receiver_id = v_uid;
    delete from public.friendships where user_id = v_uid or friend_id = v_uid;
    delete from public.user_unlocks where user_id = v_uid;
    delete from public.game_unlocks where user_id = v_uid;
    delete from public.game_trials where user_id = v_uid;
    delete from public.xp_progress where user_id = v_uid;
    delete from public.subscriptions where user_id = v_uid;
    delete from public.star_transactions where user_id = v_uid;
    delete from public.wallets where user_id = v_uid;
    delete from public.profiles where id = v_uid;
end;
$$;

-- ============================================================
-- 5. ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.star_transactions enable row level security;
alter table public.xp_progress enable row level security;
alter table public.game_trials enable row level security;
alter table public.game_unlocks enable row level security;
alter table public.subscriptions enable row level security;
alter table public.friendships enable row level security;
alter table public.friend_requests enable row level security;
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.room_invites enable row level security;
alter table public.game_sessions enable row level security;
alter table public.game_results enable row level security;
alter table public.unlock_items enable row level security;
alter table public.user_unlocks enable row level security;
alter table public.reward_idempotency enable row level security;

drop policy if exists profiles_select_authenticated on public.profiles;
drop policy if exists profiles_insert_self on public.profiles;
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_select_authenticated on public.profiles
for select to authenticated
using (true);
create policy profiles_insert_self on public.profiles
for insert to authenticated
with check (auth.uid() = id);
create policy profiles_update_self on public.profiles
for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists wallets_select_own on public.wallets;
drop policy if exists wallets_insert_own on public.wallets;
create policy wallets_select_own on public.wallets
for select to authenticated
using (auth.uid() = user_id);
create policy wallets_insert_own on public.wallets
for insert to authenticated
with check (auth.uid() = user_id and stars_balance = 100);

drop policy if exists star_transactions_select_own on public.star_transactions;
create policy star_transactions_select_own on public.star_transactions
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists xp_progress_select_own on public.xp_progress;
create policy xp_progress_select_own on public.xp_progress
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists game_trials_select_own on public.game_trials;
create policy game_trials_select_own on public.game_trials
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists game_unlocks_select_own on public.game_unlocks;
create policy game_unlocks_select_own on public.game_unlocks
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists subscriptions_select_own on public.subscriptions;
create policy subscriptions_select_own on public.subscriptions
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists friendships_select_participant on public.friendships;
drop policy if exists friendships_delete_participant on public.friendships;
create policy friendships_select_participant on public.friendships
for select to authenticated
using (auth.uid() = user_id or auth.uid() = friend_id);
create policy friendships_delete_participant on public.friendships
for delete to authenticated
using (auth.uid() = user_id or auth.uid() = friend_id);

drop policy if exists friend_requests_select_participant on public.friend_requests;
create policy friend_requests_select_participant on public.friend_requests
for select to authenticated
using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists rooms_select_visible on public.rooms;
drop policy if exists rooms_insert_host on public.rooms;
drop policy if exists rooms_update_host on public.rooms;
create policy rooms_select_visible on public.rooms
for select to authenticated
using (
    access = 'public'
    or host_user_id = auth.uid()
    or public.room_is_visible_to_user(id, auth.uid())
);
create policy rooms_insert_host on public.rooms
for insert to authenticated
with check (auth.uid() = host_user_id);
create policy rooms_update_host on public.rooms
for update to authenticated
using (auth.uid() = host_user_id)
with check (auth.uid() = host_user_id);

drop policy if exists room_members_select_visible on public.room_members;
drop policy if exists room_members_insert_self on public.room_members;
drop policy if exists room_members_update_self_or_host on public.room_members;
drop policy if exists room_members_delete_self_or_host on public.room_members;
create policy room_members_select_visible on public.room_members
for select to authenticated
using (public.room_is_visible_to_user(room_id, auth.uid()));
create policy room_members_insert_self on public.room_members
for insert to authenticated
with check (
    auth.uid() = user_id
    and public.room_is_visible_to_user(room_id, auth.uid())
);
create policy room_members_update_self_or_host on public.room_members
for update to authenticated
using (
    auth.uid() = user_id
    or public.is_room_host(room_id, auth.uid())
)
with check (
    auth.uid() = user_id
    or public.is_room_host(room_id, auth.uid())
);
create policy room_members_delete_self_or_host on public.room_members
for delete to authenticated
using (
    auth.uid() = user_id
    or public.is_room_host(room_id, auth.uid())
);

drop policy if exists room_invites_select_participant on public.room_invites;
drop policy if exists room_invites_insert_inviter on public.room_invites;
drop policy if exists room_invites_update_participant on public.room_invites;
create policy room_invites_select_participant on public.room_invites
for select to authenticated
using (auth.uid() = inviter_user_id or auth.uid() = invited_user_id);
create policy room_invites_insert_inviter on public.room_invites
for insert to authenticated
with check (
    auth.uid() = inviter_user_id
    and public.is_room_host(room_id, auth.uid())
);
create policy room_invites_update_participant on public.room_invites
for update to authenticated
using (auth.uid() = inviter_user_id or auth.uid() = invited_user_id)
with check (auth.uid() = inviter_user_id or auth.uid() = invited_user_id);

drop policy if exists game_sessions_select_visible on public.game_sessions;
drop policy if exists game_sessions_insert_room_member on public.game_sessions;
drop policy if exists game_sessions_update_creator on public.game_sessions;
create policy game_sessions_select_visible on public.game_sessions
for select to authenticated
using (
    room_id is not null
    and public.room_is_visible_to_user(room_id, auth.uid())
);
create policy game_sessions_insert_room_member on public.game_sessions
for insert to authenticated
with check (
    auth.uid() = created_by
    and room_id is not null
    and public.room_is_visible_to_user(room_id, auth.uid())
);
create policy game_sessions_update_creator on public.game_sessions
for update to authenticated
using (auth.uid() = created_by)
with check (auth.uid() = created_by);

drop policy if exists game_results_select_room_member on public.game_results;
drop policy if exists game_results_insert_creator on public.game_results;
drop policy if exists game_results_update_creator on public.game_results;
create policy game_results_select_room_member on public.game_results
for select to authenticated
using (
    exists (
        select 1
        from public.game_sessions gs
        where gs.id = game_results.session_id
          and gs.room_id is not null
          and public.room_is_visible_to_user(gs.room_id, auth.uid())
    )
);
create policy game_results_insert_creator on public.game_results
for insert to authenticated
with check (
    exists (
        select 1
        from public.game_sessions gs
        where gs.id = game_results.session_id
          and gs.created_by = auth.uid()
    )
);
create policy game_results_update_creator on public.game_results
for update to authenticated
using (
    exists (
        select 1
        from public.game_sessions gs
        where gs.id = game_results.session_id
          and gs.created_by = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.game_sessions gs
        where gs.id = game_results.session_id
          and gs.created_by = auth.uid()
    )
);

drop policy if exists unlock_items_select_all on public.unlock_items;
create policy unlock_items_select_all on public.unlock_items
for select to authenticated
using (true);

drop policy if exists user_unlocks_select_own on public.user_unlocks;
create policy user_unlocks_select_own on public.user_unlocks
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists reward_idempotency_owner_only on public.reward_idempotency;
create policy reward_idempotency_owner_only on public.reward_idempotency
for select to authenticated
using (auth.uid() = owner_user_id);

-- ============================================================
-- 6. REALTIME TABLES
-- ============================================================

do $$ begin
    alter publication supabase_realtime add table public.rooms;
exception when duplicate_object then null; end $$;

do $$ begin
    alter publication supabase_realtime add table public.room_members;
exception when duplicate_object then null; end $$;

do $$ begin
    alter publication supabase_realtime add table public.room_invites;
exception when duplicate_object then null; end $$;

do $$ begin
    alter publication supabase_realtime add table public.friendships;
exception when duplicate_object then null; end $$;

do $$ begin
    alter publication supabase_realtime add table public.friend_requests;
exception when duplicate_object then null; end $$;

do $$ begin
    alter publication supabase_realtime add table public.game_sessions;
exception when duplicate_object then null; end $$;

-- ============================================================
-- 7. FUNCTION EXECUTION GRANTS
-- ============================================================

revoke all on all functions in schema public from public;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on function public.ensure_profile_and_wallet(text, text) to authenticated;
grant execute on function public.update_profile_settings(text, text, integer, text) to authenticated;
grant execute on function public.search_profiles(text) to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.accept_friend_request(uuid) to authenticated;
grant execute on function public.decline_friend_request(uuid) to authenticated;
grant execute on function public.create_entry_fee_record(uuid, integer, text, uuid) to authenticated;
grant execute on function public.purchase_unlock_item(text, uuid) to authenticated;
grant execute on function public.finalize_game_results(uuid, uuid) to authenticated;
grant execute on function public.distribute_prize_pool(uuid, uuid) to authenticated;
grant execute on function public.delete_my_account_data() to authenticated;

-- ============================================================
-- 8. SEED OPTIONAL STORE ITEMS
-- ============================================================

insert into public.unlock_items (item_key, title, description, price_stars)
values
    ('memory_path', 'Memory Path', 'Permanent unlock for Memory Path', 120),
    ('pass_guess', 'Pass & Guess', 'Permanent unlock for Pass & Guess', 120),
    ('guess_the_fake_answer', 'Guess the Fake Answer', 'Permanent unlock for Guess the Fake Answer', 120),
    ('reverse_singing', 'Reverse Singing', 'Permanent unlock for Reverse Singing', 120)
on conflict (item_key) do nothing;
