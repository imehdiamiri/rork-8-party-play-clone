# 26 — Multiplayer (CasualRoom create / join / sync)

Files: `Services/CasualRoomService.swift`, `Services/SupabaseRealtimeService.swift`, `Services/SessionResilienceService.swift`, `Services/MultiplayerTelemetry.swift`, `ViewModels/CasualRoomViewModel.swift`, `Views/CasualRoomViews.swift`.

## High-level flow
1. **Host taps "Create Room"** in a multi-device-supported game.
2. App generates a random 6-char alphanumeric `code` (uppercase, ambiguous chars removed: 0, O, I, 1).
3. Host calls `casual_create_room` RPC. Returns `CasualRoom`. App opens `WaitingRoomView`.
4. Host's app subscribes to `casual:{code}` realtime channel for broadcasts.
5. **Joiner taps "Join"** with the code. App calls `casual_join_room` RPC. On success, joiner subscribes to the same channel.
6. Realtime broadcasts (host → joiners): `players_changed`, `state_changed`, `team_state_changed`, `host_left`.
7. Joiners broadcast back **only**: `player_action` events (their tap, their answer, their guess). The host owns authoritative state.
8. When all players Ready and host taps Start, host transitions room status to `in_progress`, builds initial `GameSession` and broadcasts `state_changed`.
9. Each joiner receives the session and pushes it to their `appModel.activeSession`.
10. Player actions during the game flow back to host as broadcasts; host updates state and re-broadcasts.

## `CasualRoomService`
- `createRoom(code:, game:, mode:, message:, isPublic:)` — calls RPC.
- `joinRoom(code:, playerName:)` — RPC + auto-anonymous-sign-in if needed.
- `leaveRoom(roomID:)` — RPC; host triggers `host_left` broadcast first.
- `setReady(roomID:, isReady:)`.
- `updateStatus(roomID:, status:, version:)` — optimistic-lock (Postgres update with `WHERE version = ?`).

## `SupabaseRealtimeService`
- Singleton wrapping `realtime.channel(name:)`.
- Methods: `subscribeRoom(code:, onPlayersChanged:, onStateChanged:, onTeamStateChanged:, onHostLeft:)` returns a `Channel` handle. Auto-reconnects with exponential backoff (1s → 30s cap).
- `broadcastPlayers(_:)`, `broadcastState(_:)`, `broadcastTeamState(_:)`, `broadcastHostLeft()`.
- Falls back to Postgres listen on `casual_rooms` and `casual_room_players` if broadcast fails.

## `SessionResilienceService`
- Tracks `connectionState: .connected / .reconnecting / .disconnected` (published via `@Observable`).
- Heartbeats: ping the realtime socket every 25s; if no ack for 8s → `.reconnecting`.
- Resumes the channel and re-pushes the latest local state on reconnect.
- Drives the `ConnectionBannerView` at the top of `ContentView`.

## `MultiplayerTelemetry`
Lightweight counters for debugging only (no analytics SDK). Logs to OSLog: room created, joined, dropped, reconnected, host left, state version mismatches.

## `CasualRoomViewModel`
- `@Observable` class held by `CasualCreateRoomView` / `WaitingRoomView`.
- Owns: `currentRoom: CasualRoom?`, `players: [CasualRoomPlayer]`, `teamState: TeamState`, `error: String?`, `isStarting: Bool`.
- Subscribes to realtime on `attach(roomCode:)`.
- Exposes: `setMessage(_:)`, `setIsPublic(_:)`, `kickPlayer(id:)` (host only), `start()`, `leave()`.
- Builds the initial `GameSession` from the current room when `start()` is called and broadcasts it.

## Views
- **`CasualCreateRoomView`** — header with game name + mode chip, generated room code shown big with Copy + Share buttons, message TextField (optional "What's up?"), Public/Private toggle, players list (live), team picker (team mode), "Start" button (host only, requires min players + everyone ready).
- **`CasualJoinRoomView`** — text field for code (6-character segmented input), "Join" button, error inline, then transitions to `WaitingRoomView` on success.
- **`WaitingRoomView`** — generic lobby view used by both host and joiners. Shows room code, mode, message, full player list with ready toggles, Leave (host: ends room, joiner: leaves), Start (host) or "Waiting for host…" (joiner).

## Team mode setup
- After "Start" in team rooms, host first goes to `TeamSetupView` (`Views/TeamSetupView.swift`):
  - 2 columns "Team A" and "Team B".
  - Drag-or-tap each player to assign. `TeamModeEntryView` is the entry/intro card explaining the rules.
  - When `TeamState.isValid` (≥1 each side), Start becomes enabled.

## Host migration
If the host disconnects (`host_left` broadcast OR no heartbeat for 30s):
- The earliest-joined player still online becomes the new host.
- Their app starts broadcasting state.
- Other players see a "Host changed to {name}" toast (file 30).
- If no host can take over within 15s, room is cancelled and a "Host Left" alert appears.

## Public rooms list
`appModel.visibleRooms` is a Postgres-changes subscription on `casual_rooms` filtered `is_public = true AND status = 'waiting'`. Updated live as rooms appear/fill/start.
