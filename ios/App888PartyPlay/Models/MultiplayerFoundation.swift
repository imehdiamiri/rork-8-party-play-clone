import Foundation

// MARK: - Multiplayer Foundation Models
// Shared, reusable multiplayer architecture for ALL multi-phone games in the app.
// DB is source of truth. Realtime events are low-latency UI sync.
// Every critical state change is versioned and reconcilable from authoritative snapshot.

nonisolated enum MultiplayerPhase: String, Codable, Sendable, Hashable {
    case lobby
    case readyCheck = "ready_check"
    case starting
    case inProgress = "in_progress"
    case completed
    case closed
}

nonisolated enum MultiplayerRejoinPolicy: String, Codable, Sendable {
    case allowRejoinInLobby = "allow_rejoin_in_lobby"
    case allowRejoinInReadyCheck = "allow_rejoin_in_ready_check"
    case allowRejoinInProgress = "allow_rejoin_in_progress"
    case allowRejoinAsSpectatorOnly = "allow_rejoin_as_spectator_only"
    case denyRejoinIfRoomClosed = "deny_rejoin_if_room_closed"
}

nonisolated enum MultiplayerConnectionState: String, Sendable, Hashable {
    case idle
    case connecting
    case connected
    case reconnecting
    case disconnected
    case stale
}

/// Authoritative, versioned session snapshot.
/// Every mutation increments `revision`. Clients apply events only if version
/// progression is valid; otherwise they fall back to snapshot fetch.
nonisolated struct MultiplayerSessionSnapshot: Codable, Sendable, Hashable {
    let roomID: UUID
    let roomCode: String
    let gameKey: String
    var phase: MultiplayerPhase
    var revision: Int
    var hostPlayerID: UUID
    var activePlayerID: UUID?
    var currentTurnIndex: Int
    var readyPlayerIDs: Set<UUID>
    var requiredPlayerIDs: Set<UUID>
    var lastEventID: UUID?
    var updatedAt: Date
    var checksum: String?
}

/// Universal per-event envelope. Every multiplayer event is wrapped in this.
/// Receivers discard events with `baseRevision != localRevision` and trigger
/// snapshot reconciliation instead of applying blindly.
nonisolated struct MultiplayerEventEnvelope: Codable, Sendable, Hashable {
    let eventID: UUID
    let roomID: UUID
    let baseRevision: Int
    let newRevision: Int
    let kind: String
    let senderID: UUID
    let timestamp: Date
    let payload: [String: String]
}

nonisolated enum MultiplayerEventKind: String, Sendable {
    case readyCheckStarted = "ready_check_started"
    case readyCheckConfirmed = "ready_check_confirmed"
    case readyCheckCancelled = "ready_check_cancelled"
    case gameStarting = "game_starting"
    case gameStarted = "game_started"
    case turnStarted = "turn_started"
    case turnCompleted = "turn_completed"
    case scoreCommitted = "score_committed"
    case timerUpdated = "timer_updated"
    case roundAdvanced = "round_advanced"
    case gameCompleted = "game_completed"
    case hostMigrated = "host_migrated"
    case playerKicked = "player_kicked"
    case roomClosed = "room_closed"
    case spectatorFrame = "spectator_frame"
    case inputEvent = "input_event"
    case visualActionEvent = "visual_action_event"
    case snapshotRequested = "snapshot_requested"
}

nonisolated struct MultiplayerError: Error, Sendable {
    let code: String
    let message: String
}
