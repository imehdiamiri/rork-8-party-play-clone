import Foundation
import Observation

// MARK: - MultiplayerRoomEngine
// The single orchestration layer that ALL multiplayer games share.
// Wraps CasualRoomService (connection / DB / realtime) and exposes a clean,
// reducer-based contract for games: observe `snapshot`, submit events, recover
// via authoritative fetch. This file also hosts the focused coordinators.

@Observable
@MainActor
final class MultiplayerRoomEngine {
    // Authoritative view of the session. UI reacts to this.
    var snapshot: MultiplayerSessionSnapshot?
    var connectionState: MultiplayerConnectionState = .idle
    var lastError: String?

    // Sub-coordinators (composition over inheritance).
    let readyCheck: MultiplayerReadyCheckCoordinator
    let turns: MultiplayerTurnCoordinator
    let reconnect: MultiplayerReconnectManager
    let hostAuthority: MultiplayerHostAuthorityManager
    let spectator: MultiplayerSpectatorSyncManager
    let reducer: MultiplayerEventReducer
    let reconciler: MultiplayerSnapshotReconciler
    let timer: MultiplayerTimerCoordinator
    let inactivity: MultiplayerHostInactivityMonitor
    let revalidator: MultiplayerForegroundRevalidator

    private let roomService: CasualRoomService
    private var reconcileTask: Task<Void, Never>?

    init(roomService: CasualRoomService) {
        self.roomService = roomService
        self.reducer = MultiplayerEventReducer()
        self.reconciler = MultiplayerSnapshotReconciler(roomService: roomService)
        self.readyCheck = MultiplayerReadyCheckCoordinator(roomService: roomService)
        self.turns = MultiplayerTurnCoordinator()
        self.reconnect = MultiplayerReconnectManager(roomService: roomService)
        self.hostAuthority = MultiplayerHostAuthorityManager()
        self.spectator = MultiplayerSpectatorSyncManager()
        self.timer = MultiplayerTimerCoordinator()
        self.inactivity = MultiplayerHostInactivityMonitor()
        self.revalidator = MultiplayerForegroundRevalidator(roomService: roomService)
    }

    // Bootstrap an initial snapshot from a freshly created/joined room.
    func bootstrap(from room: CasualRoom, localPlayerID: UUID) {
        let hostID = room.host?.id ?? localPlayerID
        let phase: MultiplayerPhase = {
            switch room.status {
            case .waiting, .full: return .lobby
            case .starting: return .starting
            case .inProgress: return .inProgress
            case .closed: return .closed
            }
        }()
        snapshot = MultiplayerSessionSnapshot(
            roomID: room.id,
            roomCode: room.code,
            gameKey: room.gameType.rawValue,
            phase: phase,
            revision: 0,
            hostPlayerID: hostID,
            activePlayerID: nil,
            currentTurnIndex: 0,
            readyPlayerIDs: [],
            requiredPlayerIDs: Set(room.players.filter(\.isConnected).map(\.id)),
            lastEventID: nil,
            updatedAt: Date(),
            checksum: nil
        )
        readyCheck.bind(engine: self)
        connectionState = .connected
    }

    /// Apply an incoming event safely with version reconciliation.
    func ingest(_ envelope: MultiplayerEventEnvelope) {
        guard let local = snapshot, local.roomID == envelope.roomID else { return }
        let outcome = reducer.reduce(snapshot: local, event: envelope)
        switch outcome {
        case .applied(let updated):
            snapshot = updated
        case .duplicate:
            return
        case .outOfOrder:
            // Gap detected — trigger authoritative reconciliation.
            triggerReconcile()
        case .rejected(let reason):
            lastError = "Event rejected: \(reason)"
        }
    }

    /// Force a snapshot refresh from the DB.
    func triggerReconcile() {
        guard let current = snapshot else { return }
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            guard let self else { return }
            do {
                if let fresh = try await self.reconciler.fetch(roomID: current.roomID, previous: current) {
                    self.snapshot = fresh
                }
            } catch {
                self.lastError = "Reconcile failed: \(error.localizedDescription)"
            }
        }
    }

    func updatePlayers(_ players: [GuestPlayer]) {
        guard var s = snapshot else { return }
        s.requiredPlayerIDs = Set(players.filter(\.isConnected).map(\.id))
        s.revision += 1
        s.updatedAt = Date()
        snapshot = s
    }

    func setPhase(_ phase: MultiplayerPhase) {
        guard var s = snapshot else { return }
        s.phase = phase
        s.revision += 1
        s.updatedAt = Date()
        snapshot = s
    }

    func tearDown() {
        reconcileTask?.cancel()
        reconcileTask = nil
        snapshot = nil
        connectionState = .idle
        timer.stop()
        inactivity.stop()
    }

    // MARK: - Foreground revalidation entry point
    /// Call when the app returns to foreground OR after a reconnect.
    /// Validates the room still exists, the local player is still in it, the
    /// phase is current, and the local state revision is fresh. If stale, the
    /// local snapshot is replaced by the authoritative one.
    @discardableResult
    func revalidateOnForeground(localPlayerID: UUID) async -> MultiplayerRevalidationResult {
        guard let current = snapshot else { return .roomMissing }
        connectionState = .reconnecting
        let result = await revalidator.revalidate(
            localSnapshot: current,
            localPlayerID: localPlayerID
        )
        switch result {
        case .valid:
            connectionState = .connected
        case .staleButRecovered(let fresh):
            snapshot = fresh
            readyCheck.rehydrate(from: fresh)
            connectionState = .connected
        case .playerRemoved:
            connectionState = .disconnected
        case .roomClosed:
            setPhase(.closed)
            connectionState = .disconnected
        case .roomMissing:
            connectionState = .disconnected
        case .failed:
            connectionState = .stale
        }
        return result.publicResult
    }
}

// MARK: - Ready Check

@Observable
@MainActor
final class MultiplayerReadyCheckCoordinator {
    var isActive: Bool = false
    var localConfirmed: Bool = false
    var confirmedIDs: Set<UUID> = []
    var requiredIDs: Set<UUID> = []
    var startedAt: Date?
    var timeoutSeconds: Int = 60

    private let roomService: CasualRoomService
    private weak var engine: MultiplayerRoomEngine?
    private var timeoutTask: Task<Void, Never>?

    init(roomService: CasualRoomService) {
        self.roomService = roomService
    }

    func bind(engine: MultiplayerRoomEngine) {
        self.engine = engine
    }

    func hostStart(localID: UUID, connected: [UUID]) async {
        isActive = true
        localConfirmed = true
        confirmedIDs = [localID]
        requiredIDs = Set(connected)
        startedAt = Date()
        engine?.setPhase(.readyCheck)
        await roomService.broadcastReadyCheckRequested(hostID: localID)
        await roomService.broadcastReadyCheckConfirmed(playerID: localID)
        scheduleTimeout()
    }

    func remoteRequested() {
        isActive = true
        localConfirmed = false
        startedAt = Date()
        scheduleTimeout()
    }

    func confirmLocal(localID: UUID) async {
        guard isActive, !localConfirmed else { return }
        localConfirmed = true
        confirmedIDs.insert(localID)
        await roomService.broadcastReadyCheckConfirmed(playerID: localID)
    }

    func remoteConfirmed(_ id: UUID) {
        confirmedIDs.insert(id)
    }

    func cancel() async {
        isActive = false
        localConfirmed = false
        confirmedIDs.removeAll()
        timeoutTask?.cancel()
        await roomService.broadcastReadyCheckCancelled()
    }

    func reset() {
        isActive = false
        localConfirmed = false
        confirmedIDs.removeAll()
        requiredIDs.removeAll()
        startedAt = nil
        timeoutTask?.cancel()
    }

    var allReady: Bool {
        !requiredIDs.isEmpty && requiredIDs.isSubset(of: confirmedIDs)
    }

    var readyCount: Int { confirmedIDs.intersection(requiredIDs).count }
    var totalCount: Int { requiredIDs.count }

    /// Reconcile from authoritative snapshot after reconnect / missed event.
    func rehydrate(from snapshot: MultiplayerSessionSnapshot) {
        if snapshot.phase == .readyCheck {
            isActive = true
            confirmedIDs = snapshot.readyPlayerIDs
            requiredIDs = snapshot.requiredPlayerIDs
        } else if snapshot.phase == .lobby {
            reset()
        }
    }

    private func scheduleTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self, timeoutSeconds] in
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            guard !Task.isCancelled, let self else { return }
            if self.isActive && !self.allReady {
                await self.cancel()
            }
        }
    }
}

// MARK: - Turns

@Observable
@MainActor
final class MultiplayerTurnCoordinator {
    var activePlayerID: UUID?
    var turnIndex: Int = 0
    private var completedTurnEventIDs: Set<UUID> = []

    func isActive(_ playerID: UUID) -> Bool { playerID == activePlayerID }

    /// Idempotent turn completion. Returns false if duplicate / not owner.
    func completeTurn(by playerID: UUID, eventID: UUID, nextActive: UUID?) -> Bool {
        guard playerID == activePlayerID else { return false }
        guard !completedTurnEventIDs.contains(eventID) else { return false }
        completedTurnEventIDs.insert(eventID)
        activePlayerID = nextActive
        turnIndex += 1
        return true
    }

    func setActive(_ id: UUID?, index: Int) {
        activePlayerID = id
        turnIndex = index
    }

    func reset() {
        activePlayerID = nil
        turnIndex = 0
        completedTurnEventIDs.removeAll()
    }
}

// MARK: - Reconnect

@Observable
@MainActor
final class MultiplayerReconnectManager {
    var isReconnecting: Bool = false
    var lastReconnectAt: Date?

    private let roomService: CasualRoomService
    private var backoffSeconds: Double = 1.0

    init(roomService: CasualRoomService) {
        self.roomService = roomService
    }

    func evaluatePolicy(phase: MultiplayerPhase) -> MultiplayerRejoinPolicy {
        switch phase {
        case .lobby: return .allowRejoinInLobby
        case .readyCheck: return .allowRejoinInReadyCheck
        case .starting, .inProgress: return .allowRejoinInProgress
        case .completed: return .allowRejoinAsSpectatorOnly
        case .closed: return .denyRejoinIfRoomClosed
        }
    }

    func noteReconnect() {
        lastReconnectAt = Date()
        backoffSeconds = 1.0
    }

    /// Jitter-safe exponential backoff.
    func nextBackoff() -> Duration {
        let jitter = Double.random(in: 0...0.3)
        let wait = min(backoffSeconds + jitter, 30.0)
        backoffSeconds = min(backoffSeconds * 1.7, 30.0)
        return .milliseconds(Int(wait * 1000))
    }
}

// MARK: - Host Authority

@Observable
@MainActor
final class MultiplayerHostAuthorityManager {
    var hostID: UUID?
    var hostChangedAt: Date?
    var graceSeconds: Int = 20

    func isHost(_ id: UUID) -> Bool { id == hostID }

    func setHost(_ id: UUID) {
        hostID = id
        hostChangedAt = Date()
    }

    /// Deterministic promotion: earliest-joined connected player wins.
    func proposeNewHost(from players: [GuestPlayer]) -> UUID? {
        players
            .filter { $0.isConnected }
            .sorted { $0.joinedAt < $1.joinedAt }
            .first?.id
    }
}

// MARK: - Spectator Sync

@Observable
@MainActor
final class MultiplayerSpectatorSyncManager {
    var lastFrame: [String: String] = [:]
    var lastFrameAt: Date?

    func apply(frame: [String: String]) {
        lastFrame = frame
        lastFrameAt = Date()
    }

    func reset() {
        lastFrame = [:]
        lastFrameAt = nil
    }
}

// MARK: - Authoritative Timer Coordinator

@Observable
@MainActor
final class MultiplayerTimerCoordinator {
    var snapshot: MultiplayerTimerSnapshot?
    var displayRemaining: Int = 0
    private var tickTask: Task<Void, Never>?

    /// Host-only: start a new round timer.
    func hostStart(duration: Int) {
        let snap = MultiplayerTimerSnapshot.start(duration: duration)
        snapshot = snap
        displayRemaining = duration
        startTicking()
    }

    /// Host-only: pause the timer (e.g. backgrounded).
    func hostPause() {
        guard let s = snapshot else { return }
        snapshot = s.paused()
        displayRemaining = snapshot?.remaining() ?? 0
        tickTask?.cancel()
        tickTask = nil
    }

    /// Host-only: resume after pause.
    func hostResume() {
        guard let s = snapshot else { return }
        snapshot = s.resumed()
        displayRemaining = snapshot?.remaining() ?? 0
        startTicking()
    }

    /// Any client: adopt authoritative timer snapshot (from DB or broadcast).
    /// Used to resync drift and to restore after foreground.
    func adopt(_ snap: MultiplayerTimerSnapshot) {
        if let existing = snapshot, snap.revision < existing.revision { return }
        snapshot = snap
        displayRemaining = snap.remaining()
        if snap.isPaused {
            tickTask?.cancel()
            tickTask = nil
        } else {
            startTicking()
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
        snapshot = nil
        displayRemaining = 0
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                guard let s = self.snapshot, !s.isPaused else { return }
                self.displayRemaining = s.remaining()
                if self.displayRemaining == 0 { return }
            }
        }
    }
}

// MARK: - Host Inactivity Monitor

@Observable
@MainActor
final class MultiplayerHostInactivityMonitor {
    var lastHostSeenAt: Date = Date()
    var outcome: HostInactivityPolicy.Outcome = .healthy
    var policy: HostInactivityPolicy = .default
    private var watchTask: Task<Void, Never>?

    func noteHostSeen(_ date: Date = Date()) {
        lastHostSeenAt = date
        if outcome != .healthy { outcome = .healthy }
    }

    func start(phaseProvider: @MainActor @escaping () -> MultiplayerPhase,
               onChange: @MainActor @escaping (HostInactivityPolicy.Outcome) -> Void) {
        stop()
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { return }
                let phase = phaseProvider()
                let next = self.policy.evaluate(lastSeen: self.lastHostSeenAt, phase: phase)
                if next != self.outcome {
                    self.outcome = next
                    onChange(next)
                }
            }
        }
    }

    func stop() {
        watchTask?.cancel()
        watchTask = nil
    }
}

// MARK: - Foreground Revalidator

nonisolated enum _ForegroundRevalidationInternal: Sendable {
    case valid
    case staleButRecovered(MultiplayerSessionSnapshot)
    case playerRemoved
    case roomClosed
    case roomMissing
    case failed(String)

    var publicResult: MultiplayerRevalidationResult {
        switch self {
        case .valid: return .valid
        case .staleButRecovered: return .staleButRecovered
        case .playerRemoved: return .playerRemoved
        case .roomClosed: return .roomClosed
        case .roomMissing: return .roomMissing
        case .failed(let s): return .failed(s)
        }
    }
}

@MainActor
final class MultiplayerForegroundRevalidator {
    private let roomService: CasualRoomService

    init(roomService: CasualRoomService) {
        self.roomService = roomService
    }

    func revalidate(localSnapshot: MultiplayerSessionSnapshot, localPlayerID: UUID) async -> _ForegroundRevalidationInternal {
        do {
            let (record, players) = try await roomService.fetchRoomFromDB(roomID: localSnapshot.roomID)
            let status = CasualRoomStatus(rawValue: record.status) ?? .waiting
            if status == .closed { return .roomClosed }
            guard players.contains(where: { $0.guestPlayerId == localPlayerID && $0.isConnected }) else {
                return .playerRemoved
            }
            let phase: MultiplayerPhase = {
                switch status {
                case .waiting, .full: return .lobby
                case .starting: return .starting
                case .inProgress: return .inProgress
                case .closed: return .closed
                }
            }()
            let hostID = players.first(where: \.isHost)?.guestPlayerId ?? localSnapshot.hostPlayerID
            let required = Set(players.filter(\.isConnected).map(\.guestPlayerId))
            let phaseChanged = phase != localSnapshot.phase
            let hostChanged = hostID != localSnapshot.hostPlayerID
            let requiredChanged = required != localSnapshot.requiredPlayerIDs
            if !phaseChanged && !hostChanged && !requiredChanged {
                return .valid
            }
            var updated = localSnapshot
            updated.phase = phase
            updated.hostPlayerID = hostID
            updated.requiredPlayerIDs = required
            updated.updatedAt = Date()
            updated.revision += 1
            return .staleButRecovered(updated)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

// MARK: - Reducer

nonisolated struct MultiplayerEventReducer: Sendable {
    enum Outcome {
        case applied(MultiplayerSessionSnapshot)
        case duplicate
        case outOfOrder
        case rejected(String)
    }

    func reduce(snapshot: MultiplayerSessionSnapshot, event: MultiplayerEventEnvelope) -> Outcome {
        if let lastID = snapshot.lastEventID, lastID == event.eventID { return .duplicate }
        if event.baseRevision != snapshot.revision { return .outOfOrder }
        if event.newRevision <= snapshot.revision { return .outOfOrder }

        var updated = snapshot
        updated.revision = event.newRevision
        updated.lastEventID = event.eventID
        updated.updatedAt = event.timestamp

        guard let kind = MultiplayerEventKind(rawValue: event.kind) else {
            return .applied(updated)
        }

        switch kind {
        case .readyCheckStarted:
            updated.phase = .readyCheck
            updated.readyPlayerIDs = []
        case .readyCheckConfirmed:
            if let s = event.payload["playerId"], let id = UUID(uuidString: s) {
                updated.readyPlayerIDs.insert(id)
            }
        case .readyCheckCancelled:
            updated.phase = .lobby
            updated.readyPlayerIDs = []
        case .gameStarting, .gameStarted:
            updated.phase = .inProgress
        case .turnStarted:
            if let s = event.payload["activePlayerId"], let id = UUID(uuidString: s) {
                updated.activePlayerID = id
            }
            if let s = event.payload["turnIndex"], let n = Int(s) {
                updated.currentTurnIndex = n
            }
        case .turnCompleted:
            updated.currentTurnIndex += 1
            updated.activePlayerID = nil
        case .hostMigrated:
            if let s = event.payload["newHostId"], let id = UUID(uuidString: s) {
                updated.hostPlayerID = id
            }
        case .roomClosed:
            updated.phase = .closed
        case .gameCompleted:
            updated.phase = .completed
        case .scoreCommitted, .timerUpdated, .roundAdvanced, .playerKicked,
             .spectatorFrame, .inputEvent, .visualActionEvent, .snapshotRequested:
            break
        }
        return .applied(updated)
    }
}

// MARK: - Snapshot Reconciler

@MainActor
final class MultiplayerSnapshotReconciler {
    private let roomService: CasualRoomService

    init(roomService: CasualRoomService) {
        self.roomService = roomService
    }

    func fetch(roomID: UUID, previous: MultiplayerSessionSnapshot) async throws -> MultiplayerSessionSnapshot? {
        let (record, players) = try await roomService.fetchRoomFromDB(roomID: roomID)
        let phase: MultiplayerPhase = {
            switch CasualRoomStatus(rawValue: record.status) ?? .waiting {
            case .waiting, .full: return .lobby
            case .starting: return .starting
            case .inProgress: return .inProgress
            case .closed: return .closed
            }
        }()
        let hostID = players.first(where: \.isHost)?.guestPlayerId ?? previous.hostPlayerID
        var updated = previous
        updated.phase = phase
        updated.hostPlayerID = hostID
        updated.requiredPlayerIDs = Set(players.filter(\.isConnected).map(\.guestPlayerId))
        updated.updatedAt = Date()
        updated.revision = max(previous.revision + 1, previous.revision)
        return updated
    }
}
