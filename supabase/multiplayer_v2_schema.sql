-- Multiplayer v2 — authoritative snapshot + versioned events
-- Additive; does not modify the existing casual_rooms flow.

create table if not exists multiplayer_sessions (
    room_id uuid primary key references casual_rooms(id) on delete cascade,
    phase text not null default 'lobby',
    revision bigint not null default 0,
    host_player_id uuid not null,
    active_player_id uuid,
    current_turn_index int not null default 0,
    ready_player_ids uuid[] not null default '{}',
    required_player_ids uuid[] not null default '{}',
    last_event_id uuid,
    payload jsonb not null default '{}'::jsonb,
    checksum text,
    updated_at timestamptz not null default now()
);

create index if not exists idx_mp_sessions_phase on multiplayer_sessions(phase);

create table if not exists multiplayer_events (
    event_id uuid primary key,
    room_id uuid not null references casual_rooms(id) on delete cascade,
    base_revision bigint not null,
    new_revision bigint not null,
    kind text not null,
    sender_id uuid not null,
    payload jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists idx_mp_events_room_rev on multiplayer_events(room_id, new_revision);

-- RPC: atomically apply an event with version CAS. Prevents duplicate turn completion.
create or replace function mp_apply_event(
    p_event_id uuid,
    p_room_id uuid,
    p_base_revision bigint,
    p_kind text,
    p_sender_id uuid,
    p_payload jsonb
) returns jsonb language plpgsql as $$
declare
    current_rev bigint;
    new_rev bigint;
begin
    select revision into current_rev from multiplayer_sessions where room_id = p_room_id for update;
    if current_rev is null then
        return jsonb_build_object('error','session_not_found');
    end if;
    if p_base_revision <> current_rev then
        return jsonb_build_object('error','out_of_order','current_revision',current_rev);
    end if;
    if exists (select 1 from multiplayer_events where event_id = p_event_id) then
        return jsonb_build_object('error','duplicate');
    end if;
    new_rev := current_rev + 1;
    insert into multiplayer_events(event_id,room_id,base_revision,new_revision,kind,sender_id,payload)
    values (p_event_id,p_room_id,p_base_revision,new_rev,p_kind,p_sender_id,p_payload);
    update multiplayer_sessions
       set revision = new_rev,
           last_event_id = p_event_id,
           updated_at = now()
     where room_id = p_room_id;
    return jsonb_build_object('success',true,'new_revision',new_rev);
end $$;

-- RPC: host-only ready-check start, persisted authoritatively
create or replace function mp_start_ready_check(
    p_room_id uuid,
    p_host_session_token text,
    p_required_player_ids uuid[]
) returns jsonb language plpgsql as $$
begin
    if not exists (
      select 1 from casual_room_players
       where room_id = p_room_id and session_token = p_host_session_token and is_host = true
    ) then
        return jsonb_build_object('error','not_host');
    end if;
    insert into multiplayer_sessions(room_id,phase,revision,host_player_id,required_player_ids,ready_player_ids)
    values (p_room_id,'ready_check',0,
      (select guest_player_id from casual_room_players where room_id = p_room_id and session_token = p_host_session_token),
      p_required_player_ids, '{}')
    on conflict (room_id) do update
      set phase = 'ready_check',
          required_player_ids = excluded.required_player_ids,
          ready_player_ids = '{}'::uuid[],
          revision = multiplayer_sessions.revision + 1,
          updated_at = now();
    return jsonb_build_object('success',true);
end $$;

-- RPC: idempotent ready confirmation
create or replace function mp_confirm_ready(
    p_room_id uuid,
    p_session_token text
) returns jsonb language plpgsql as $$
declare
    pid uuid;
begin
    select guest_player_id into pid from casual_room_players
     where room_id = p_room_id and session_token = p_session_token;
    if pid is null then return jsonb_build_object('error','not_in_room'); end if;
    update multiplayer_sessions
       set ready_player_ids = (select array_agg(distinct x) from unnest(ready_player_ids || pid) x),
           revision = revision + 1,
           updated_at = now()
     where room_id = p_room_id;
    return jsonb_build_object('success',true);
end $$;

-- RPC: authoritative host migration (earliest-joined connected player)
create or replace function mp_migrate_host(p_room_id uuid) returns jsonb language plpgsql as $$
declare new_host uuid;
begin
    select guest_player_id into new_host from casual_room_players
     where room_id = p_room_id and is_connected = true
     order by joined_at asc limit 1;
    if new_host is null then return jsonb_build_object('error','no_candidate'); end if;
    update casual_room_players set is_host = (guest_player_id = new_host) where room_id = p_room_id;
    update multiplayer_sessions set host_player_id = new_host, revision = revision + 1, updated_at = now()
     where room_id = p_room_id;
    return jsonb_build_object('success',true,'new_host_id',new_host);
end $$;
