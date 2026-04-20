-- Fix: column "updated_at" of relation "friend_requests" does not exist
-- Run this once in the Supabase SQL editor.

alter table public.friend_requests
    add column if not exists updated_at timestamptz not null default now();

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $fn_set_updated_at$
begin
    new.updated_at = now();
    return new;
end;
$fn_set_updated_at$;

drop trigger if exists friend_requests_set_updated_at on public.friend_requests;
create trigger friend_requests_set_updated_at
before update on public.friend_requests
for each row execute function public.set_updated_at();

-- Rewrite the RPCs to be consistent with the column.
create or replace function public.send_friend_request(p_receiver_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $fn_send_fr$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then raise exception 'Not authenticated'; end if;
    if v_uid = p_receiver_id then raise exception 'Cannot friend yourself'; end if;

    if exists (
        select 1 from public.friendships f
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
$fn_send_fr$;

create or replace function public.accept_friend_request(p_request_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $fn_accept_fr$
declare
    v_uid uuid := auth.uid();
    v_sender_id uuid;
begin
    if v_uid is null then raise exception 'Not authenticated'; end if;

    select sender_id into v_sender_id
    from public.friend_requests
    where id = p_request_id and receiver_id = v_uid and status = 'pending';

    if v_sender_id is null then raise exception 'Friend request not found'; end if;

    update public.friend_requests
    set status = 'accepted', updated_at = now()
    where id = p_request_id;

    insert into public.friendships(user_id, friend_id)
    values (least(v_uid, v_sender_id), greatest(v_uid, v_sender_id))
    on conflict (user_id, friend_id) do nothing;
end;
$fn_accept_fr$;

create or replace function public.decline_friend_request(p_request_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $fn_decline_fr$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then raise exception 'Not authenticated'; end if;
    update public.friend_requests
    set status = 'declined', updated_at = now()
    where id = p_request_id and receiver_id = v_uid and status = 'pending';
end;
$fn_decline_fr$;
