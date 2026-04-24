# 8PartyPlay — Multi-Device System Build Prompt

This prompt describes the realtime multi-device infrastructure that powers rooms, lobbies, and synced gameplay in **8PartyPlay**. Games themselves are described in a separate prompt. Pick whatever realtime backend/tech you think fits best — just cover all behaviors below.

## Core Idea

Players can play any multi-device game together on their own phones. One player hosts, others join. The system must handle room creation, guest identity, realtime lobby, live game state sync, reconnection after crashes or backgrounding, host migration, and graceful room closure.

## Identity Model

- Users can play signed-in (username / Google / Apple) **or as guests**.
- Every device gets a persistent **guest player ID** (UUID) and a **session token** stored locally. These survive app restarts and are used to reclaim a seat if the device reconnects.
- Display name is chosen per session (auto-suggested from account name if signed in).
- Normalize names (trim, collapse whitespace, lowercase) for duplicate detection inside a room.

## Rooms

### Create
- Host picks a game, optional settings (rounds, timers, difficulty), min/max players, and access type.
- App generates a **6-character room code** (A–Z, 0–9, avoid ambiguous chars like 0/O, 1/I).
- Room states: `draft`, `waiting`, `full`, `starting`, `in_progress`, `completed`, `cancelled`.
- Access types:
  - **Private:** only joinable via code or direct invite.
  - **Public:** visible in the "Public Rooms" list for all online users.
- Host can invite friends from their friend list; invited players get a push-style in-app invite.

### Join
- By **code** (enter in Join sheet), from **public rooms list**, from a **friend invite**, or via deep link `8partyplay://room/<code>`.
- Reject joins if: room full, status not `waiting`, code invalid, or player is banned/kicked.
- On successful join, player gets a `PlayerProfile` with `isHost=false`, `isReady=false`, `isOnline=true`.

### Waiting Room (Lobby)
- Shows: game title, room code (big, tap-to-copy, share button), mode badge, player list with avatars, online dot, ready state, host crown, host-only kick button.
- Chat / quick message slot (optional text the host sets: "Playing in 5 min").
- Host controls: change settings, kick, transfer host, start when all ready and min players met.
- Non-host controls: Ready toggle, Leave.
- Auto-advance to game when host taps **Start** and minimum-player / all-ready conditions pass.

## Realtime Sync

Use a realtime pub/sub system with the following channels per room:

1. **Room channel** — presence, player list, ready state, settings, chat, kicks, host changes, room lifecycle.
2. **Game state channel** — authoritative per-game state broadcast by the host (or server), versioned with a monotonically increasing `stateVersion`.
3. **Actions channel** — small messages from clients (e.g. "tapped tile 5", "submitted answer", "finished"). Host applies them and re-broadcasts new state.

Guarantees to implement:
- **At-most-once UI updates per version.** Drop any incoming state with a `stateVersion` less than the one already applied.
- **Snapshot on demand.** New joiners or reconnects can request a full snapshot; host replies with the current state.
- **Heartbeat every ~5s** from each client. If a client misses 3 beats, mark them offline. If they recover within grace period (30s), mark online again.
- **Broadcast coalescing** on the host: batch rapid updates (e.g. drawing strokes) to avoid flooding.

## Reconnection & Resilience

- If the app is backgrounded or network drops, reconnect automatically on foreground / when connectivity returns.
- On reconnect: rejoin channels using the saved session token, request a state snapshot, hydrate UI without flicker.
- If the host drops for longer than grace period, trigger **host migration**: promote the earliest-joined connected player, re-broadcast state, everyone re-subscribes to the new host.
- If all players drop, mark the room `cancelled` after a server-side timeout.
- Keep a per-client local mirror of the last applied state so UI can survive very brief disconnects without spinner.

## Turn / Action Ordering

- Actions that must be ordered (turns, taps) go through a **turn advance** handshake:
  - Client sends `requestAdvance(round, playerID)`.
  - Host/server validates (right player, right phase, not duplicate), increments `turn_version`, broadcasts new active player.
  - Clients ignore any advance message whose `turn_version` is not strictly greater than current.
- Rejects return an error code the client shows as a toast (e.g. "Not your turn").

## Session State Per Game

Each game has its own state struct synced over the game channel. Reference shapes:
- `MatchPhase`: `intro | passToNextPlayer | liveRound | roundResult | finished`.
- Per-game sub-state (memory grid tiles, memory path indices, tap-in-order board, color-trap forbidden color, draw-rush strokes, imposter role / clues / votes, pass-guess answers + votes, etc.).
- Current round index, seconds remaining, results list, latest awarded points, rematch player IDs.
- Always stamp every state with `stateVersion` and the authoritative host's player ID.

## Friends & Invites (multiplayer-related)

- Signed-in users can search other users (by username / email / public numeric ID) and send friend requests.
- Relationship states: `none`, `pending_outgoing`, `pending_incoming`, `existing_friend`, `self`.
- From a lobby a host can tap a friend to send a direct room invite; the friend sees a sheet with Accept / Decline.
- Public rooms list is scoped to currently online players and `waiting`-status public rooms.

## Public Rooms Feed

- Query all `public` rooms with status `waiting` and available seats, sorted by most recent activity.
- Live subscribe so the list updates as rooms open/close/fill.
- Each row shows game, mode badge, "players/max", and host name. Tap = go to waiting room (join on confirm).

## Security / Fair Play

- Validate on the server that the person sending an action is actually in the room and matches the claimed player ID (use session token).
- Rate-limit chat, joins, and room creation per device.
- Sanitize all display names and chat messages before rendering.
- Don't trust clients with score calculation — host or server computes scoring from raw actions.

## Edge Cases to Cover

- Duplicate display names in a room → auto-append `#2`, `#3`.
- Player joins while game is mid-round → park them as spectator until the round ends, then seat for next round (per-game decision).
- Player closes app in the middle of a game → keep their seat reserved for grace period, reconnect and resume at the current phase.
- Host leaves mid-game → host migration + brief "Reconnecting…" overlay.
- Room code collisions → regenerate on insert conflict (retry up to 3 times).
- Network offline → disable Join / Create buttons, show a banner, queue retries.

## UI Components to Build

- **Join sheet:** big code field (auto-uppercase, segmented digits), paste button, recent codes.
- **Create sheet:** game picker, mode picker (Multi / Team), access toggle (Private/Public), settings per game, invite-friends inline list.
- **Waiting room:** header with code + copy/share, player grid, settings, start button with validation tooltip.
- **In-game connection banner:** top thin bar that appears when sync degrades ("Reconnecting…", "Host left, migrating…").
- **Spectator view:** optional side panel during multi-device games showing other players' progress (used by Memory Grid, Tap in Order, Color Trap, Draw & Rush).

Wire every game marked Multi-Device or Team in the games prompt to this system.
