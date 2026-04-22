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

// MARK: - Authoritative Timer
// All clients derive `remainingSeconds` from this snapshot. No client-local drift.
// Host may pause/resume (e.g. when backgrounded). When paused, `pausedRemaining`
// is the source of truth; when running, `endsAt - now` is.
nonisolated struct MultiplayerTimerSnapshot: Codable, Sendable, Hashable {
    var revision: Int
    var durationSeconds: Int
    var startedAt: Date
    var endsAt: Date
    var isPaused: Bool
    var pausedAt: Date?
    var pausedRemaining: Int?

    func remaining(now: Date = Date()) -> Int {
        if isPaused { return pausedRemaining ?? 0 }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded()))
    }

    static func start(duration: Int, now: Date = Date()) -> MultiplayerTimerSnapshot {
        MultiplayerTimerSnapshot(
            revision: 0,
            durationSeconds: duration,
            startedAt: now,
            endsAt: now.addingTimeInterval(TimeInterval(duration)),
            isPaused: false,
            pausedAt: nil,
            pausedRemaining: nil
        )
    }

    func paused(now: Date = Date()) -> MultiplayerTimerSnapshot {
        guard !isPaused else { return self }
        return MultiplayerTimerSnapshot(
            revision: revision + 1,
            durationSeconds: durationSeconds,
            startedAt: startedAt,
            endsAt: endsAt,
            isPaused: true,
            pausedAt: now,
            pausedRemaining: remaining(now: now)
        )
    }

    func resumed(now: Date = Date()) -> MultiplayerTimerSnapshot {
        guard isPaused else { return self }
        let rem = pausedRemaining ?? remaining(now: now)
        return MultiplayerTimerSnapshot(
            revision: revision + 1,
            durationSeconds: durationSeconds,
            startedAt: startedAt,
            endsAt: now.addingTimeInterval(TimeInterval(rem)),
            isPaused: false,
            pausedAt: nil,
            pausedRemaining: nil
        )
    }
}

// MARK: - Host Inactivity Policy
// Determines what to do when the host has been silent (no heartbeat) for too long.
// - short window  → keep room alive silently (background is normal)
// - medium window → surface a neutral "syncing" indicator to guests, don't close
// - long window   → promote a new host or close the room depending on phase
nonisolated struct HostInactivityPolicy: Sendable {
    let softSeconds: Int
    let promoteAfterSeconds: Int
    let closeAfterSeconds: Int

    static let `default` = HostInactivityPolicy(
        softSeconds: 15,
        promoteAfterSeconds: 120,
        closeAfterSeconds: 600
    )

    enum Outcome: Sendable, Equatable {
        case healthy
        case softDegraded
        case promoteNewHost
        case closeRoom
    }

    func evaluate(lastSeen: Date, now: Date = Date(), phase: MultiplayerPhase) -> Outcome {
        let elapsed = now.timeIntervalSince(lastSeen)
        if elapsed < Double(softSeconds) { return .healthy }
        if elapsed < Double(promoteAfterSeconds) { return .softDegraded }
        if elapsed < Double(closeAfterSeconds) {
            // Mid-game we try to promote; in lobby without players we close.
            switch phase {
            case .inProgress, .starting, .readyCheck: return .promoteNewHost
            case .lobby, .completed, .closed: return .closeRoom
            }
        }
        return .closeRoom
    }
}

// MARK: - Foreground Revalidation Result
nonisolated enum MultiplayerRevalidationResult: Sendable, Equatable {
    case valid
    case staleButRecovered   // local state replaced from authoritative snapshot
    case playerRemoved       // guest no longer in room (kicked or auto-cleaned)
    case roomClosed          // host explicitly closed the room
    case roomMissing         // record not found
    case failed(String)

    static func == (lhs: MultiplayerRevalidationResult, rhs: MultiplayerRevalidationResult) -> Bool {
        switch (lhs, rhs) {
        case (.valid, .valid),
             (.staleButRecovered, .staleButRecovered),
             (.playerRemoved, .playerRemoved),
             (.roomClosed, .roomClosed),
             (.roomMissing, .roomMissing): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}
