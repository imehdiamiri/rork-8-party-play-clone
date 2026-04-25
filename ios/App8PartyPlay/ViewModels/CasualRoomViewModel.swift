import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class CasualRoomViewModel {
    var room: CasualRoom?
    var localPlayer: GuestPlayer?
    var displayName: String = ""
    var roomCode: String = ""
    var errorMessage: String?
    var isBusy: Bool = false
    var isConnected: Bool = false
    var gameStarted: Bool = false
    var wasKicked: Bool = false
    var roomClosed: Bool = false
    var hostLeft: Bool = false
    private var isStartingGame: Bool = false
    var shouldAutoDismissLobby: Bool = false
    var waitingTooLong: Bool = false
    var isReconnecting: Bool = false
    var resyncBanner: String? = nil
    var readyCheckActive: Bool = false
    var readyCheckLocalConfirmed: Bool = false
    var readyConfirmedPlayerIDs: Set<UUID> = []
    var teamState: TeamState = .default
    var playMode: GameMode = .multiDevice
    var onSessionEnded: (() -> Void)?

    private let roomService: CasualRoomService
    var service: CasualRoomService { roomService }
    private var refreshTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var waitingTimerTask: Task<Void, Never>?
    private var lobbyStartTime: Date?


    var isHost: Bool {
        guard let localPlayer, let room else { return false }
        return room.players.contains { $0.id == localPlayer.id && $0.isHost }
    }

    var canStart: Bool {
        guard isHost, let room else { return false }
        if playMode == .teamMode {
            return room.players.count >= room.minPlayers && teamState.isValid
        }
        return room.players.count >= room.minPlayers
    }

    var unassignedPlayers: [GuestPlayer] {
        guard let room else { return [] }
        let assigned = teamState.allAssignedPlayerIDs
        return room.players.filter { !assigned.contains($0.id) }
    }

    var players: [GuestPlayer] {
        room?.players ?? []
    }

    private var sessionToken: String {
        localPlayer?.sessionToken ?? GuestSessionStore.loadSessionToken() ?? ""
    }

    init() {
        self.roomService = CasualRoomService()
        if let savedName = GuestSessionStore.loadDisplayName(), !savedName.isEmpty {
            self.displayName = savedName
        }
    }

    func handleScenePhaseChange(to phase: ScenePhase) {
        switch phase {
        case .background:
            // Keep room alive in background. The OS may suspend us, but we do NOT
            // tear down the heartbeat, watchdog, or room state. When the user comes
            // back, the same room/game screen is still active. Only explicit
            // leaveRoom() or host closing the room ends the session.
            break
        case .active:
            guard isConnected, let room, let token = localPlayer?.sessionToken, !token.isEmpty else { return }
            isReconnecting = true
            resyncBanner = "Re-syncing room…"
            roomService.startHeartbeat(roomID: room.id, sessionToken: token)
            startLobbyWatchdog()
            startWaitingTimer()
            Task {
                await refreshRoomFromDB()
                isReconnecting = false
                // Keep the banner only while we have an active session; a successful refresh
                // either restored the room or triggered a proper close path.
                if self.room != nil {
                    self.resyncBanner = "Connection restored"
                    try? await Task.sleep(for: .seconds(1))
                    if self.resyncBanner == "Connection restored" {
                        self.resyncBanner = nil
                    }
                }
            }
        default:
            break
        }
    }

    func tryAutoRejoin() {
        guard !isBusy, room == nil else { return }
        guard let token = GuestSessionStore.loadSessionToken(),
              let playerID = GuestSessionStore.loadPlayerID() else { return }

        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                guard let (rejoinedRoom, player) = try await roomService.reconnectPlayer(sessionToken: token) else {
                    GuestSessionStore.clear()
                    return
                }
                shouldAutoDismissLobby = false
                room = rejoinedRoom
                localPlayer = player
                isConnected = true
                setupCallbacks()
                roomService.startHeartbeat(roomID: rejoinedRoom.id, sessionToken: token)
            } catch {
                GuestSessionStore.clear()
            }
        }
    }

    func createRoom(gameType: GameType) {
        guard !isBusy else { return }
        let trimmedName = sanitizeName(displayName)
        if let error = validateName(trimmedName) {
            errorMessage = error.localizedDescription
            return
        }
        createRoomInternal(gameType: gameType, name: trimmedName)
    }

    private func createRoomInternal(gameType: GameType, name: String) {
        shouldAutoDismissLobby = false
        isBusy = true
        errorMessage = nil

        let playerID = GuestSessionStore.loadPlayerID() ?? UUID()
        let token = GuestSessionStore.loadSessionToken() ?? UUID().uuidString
        let host = GuestPlayer(
            id: playerID,
            displayName: name,
            isHost: true,
            sessionToken: token
        )

        localPlayer = host

        Task {
            defer { isBusy = false }
            do {
                let created = try await roomService.createRoom(
                    gameType: gameType,
                    host: host
                )
                room = created
                isConnected = true
                GuestSessionStore.save(playerID: playerID, sessionToken: token, displayName: name, roomID: created.id)
                setupCallbacks()
                roomService.startHeartbeat(roomID: created.id, sessionToken: token)
                startLobbyWatchdog()
                startWaitingTimer()
                MultiplayerTelemetry.shared.setContext(
                    room_id: created.id.uuidString,
                    player_id: playerID.uuidString,
                    user_role: "host",
                    game_type: gameType.rawValue,
                    room_status: created.status.rawValue,
                    player_count: created.players.count,
                    session_token_hash: MultiplayerTelemetry.safeTokenHash(token)
                )
                MultiplayerTelemetry.shared.log(event: "room_create_succeeded", source: "ui", success: true)
            } catch {
                errorMessage = error.localizedDescription
                localPlayer = nil
            }
        }
    }

    func joinRoom() {
        guard !isBusy else { return }
        let trimmedName = sanitizeName(displayName)
        let trimmedCode = roomCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedCode.count >= 4 else {
            errorMessage = CasualRoomError.invalidRoomCode.localizedDescription
            return
        }

        if let error = validateName(trimmedName) {
            errorMessage = error.localizedDescription
            return
        }

        shouldAutoDismissLobby = false
        isBusy = true
        errorMessage = nil

        let playerID = GuestSessionStore.loadPlayerID() ?? UUID()
        let token = GuestSessionStore.loadSessionToken() ?? UUID().uuidString
        let player = GuestPlayer(
            id: playerID,
            displayName: trimmedName,
            sessionToken: token
        )

        localPlayer = player

        Task {
            defer { isBusy = false }
            do {
                let joined = try await roomService.joinRoom(code: trimmedCode, player: player)
                room = joined
                playMode = joined.playMode
                teamState = joined.teamState ?? .default
                gameStarted = joined.status == .starting || joined.status == .inProgress
                isConnected = true
                GuestSessionStore.save(playerID: playerID, sessionToken: token, displayName: trimmedName, roomID: joined.id)
                setupCallbacks()
                roomService.startHeartbeat(roomID: joined.id, sessionToken: token)
                startLobbyWatchdog()
                startWaitingTimer()
                MultiplayerTelemetry.shared.setContext(
                    room_id: joined.id.uuidString,
                    player_id: playerID.uuidString,
                    user_role: "guest",
                    game_type: joined.gameType.rawValue,
                    room_status: joined.status.rawValue,
                    player_count: joined.players.count,
                    session_token_hash: MultiplayerTelemetry.safeTokenHash(token)
                )
                MultiplayerTelemetry.shared.log(event: "room_join_succeeded", source: "ui", success: true)
            } catch {
                MultiplayerTelemetry.shared.log(
                    event: "room_join_failed",
                    source: "ui",
                    success: false,
                    failure_reason: String(describing: error),
                    props: ["code": trimmedCode]
                )
                errorMessage = error.localizedDescription
                localPlayer = nil
            }
        }
    }

    func kickPlayer(_ player: GuestPlayer) {
        guard isHost, let room, player.id != localPlayer?.id else { return }
        // Safety: only allow kicks before the match starts.
        guard room.status == .waiting || room.status == .full else { return }
        Task {
            do {
                try await roomService.kickPlayer(
                    roomID: room.id,
                    guestPlayerID: player.id,
                    hostSessionToken: sessionToken
                )
                await refreshRoomFromDB()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func startGame() {
        guard !isStartingGame else { return }
        guard canStart, let room, let localPlayer else { return }
        guard room.status == .waiting || room.status == .full else { return }
        isStartingGame = true
        readyCheckActive = true
        readyCheckLocalConfirmed = true
        readyConfirmedPlayerIDs = [localPlayer.id]
        MultiplayerTelemetry.shared.log(event: "ready_check_started", source: "ui", props: ["player_count": "\(room.players.count)"])
        MultiplayerTelemetry.shared.log(event: "player_ready_submitted", source: "ui")
        Task {
            await roomService.clearAllReady(roomID: room.id, hostSessionToken: sessionToken)
            await roomService.setPlayerReady(roomID: room.id, sessionToken: sessionToken, isReady: true)
            await roomService.broadcastRoomRefresh()
            for attempt in 0..<3 {
                await roomService.broadcastReadyCheckRequested(hostID: localPlayer.id)
                await roomService.broadcastReadyCheckConfirmed(playerID: localPlayer.id)
                await roomService.broadcastRoomState(room)
                if attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(600))
                }
            }
        }
        checkAllReadyAndStart()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { self?.isStartingGame = false }
        }
    }

    func confirmReady() {
        guard readyCheckActive, let localPlayer, let room else { return }
        if !readyCheckLocalConfirmed {
            readyCheckLocalConfirmed = true
            readyConfirmedPlayerIDs.insert(localPlayer.id)
            MultiplayerTelemetry.shared.log(event: "player_ready_submitted", source: "ui")
            Task {
                await roomService.setPlayerReady(roomID: room.id, sessionToken: sessionToken, isReady: true)
                // Retry broadcasts so the host reliably sees our ready vote even
                // if the realtime channel briefly drops a packet.
                for attempt in 0..<3 {
                    await roomService.broadcastReadyCheckConfirmed(playerID: localPlayer.id)
                    await roomService.broadcastRoomRefresh()
                    if attempt < 2 {
                        try? await Task.sleep(for: .milliseconds(400))
                    }
                }
            }
        }
        checkAllReadyAndStart()
    }

    func cancelReadyCheck() {
        guard isHost, let room else { return }
        readyCheckActive = false
        readyCheckLocalConfirmed = false
        readyConfirmedPlayerIDs.removeAll()
        Task {
            await roomService.clearAllReady(roomID: room.id, hostSessionToken: sessionToken)
            await roomService.broadcastReadyCheckCancelled()
            await roomService.broadcastRoomRefresh()
        }
    }

    private func checkAllReadyAndStart() {
        guard isHost, readyCheckActive, let room else { return }
        guard room.status == .waiting || room.status == .full else { return }
        let connectedIDs = Set(room.players.filter { $0.isConnected }.map { $0.id })
        guard !connectedIDs.isEmpty else { return }
        guard connectedIDs.isSubset(of: readyConfirmedPlayerIDs) else { return }

        let startingRoom = CasualRoom(
            id: room.id,
            code: room.code,
            gameType: room.gameType,
            players: room.players,
            status: .starting,
            maxPlayers: room.maxPlayers,
            minPlayers: room.minPlayers,
            createdAt: room.createdAt,
            playMode: playMode,
            teamState: playMode == .teamMode ? teamState : nil
        )
        self.room = startingRoom
        readyCheckActive = false
        gameStarted = true
        MultiplayerTelemetry.shared.setContext(room_status: startingRoom.status.rawValue, player_count: startingRoom.players.count)
        MultiplayerTelemetry.shared.markSessionStarted()
        MultiplayerTelemetry.shared.log(event: "match_start_succeeded", source: "host", success: true, props: ["player_count": "\(startingRoom.players.count)"])
        Task {
            try? await roomService.startGame(room: startingRoom, hostSessionToken: sessionToken)
        }
    }

    func assignPlayer(_ playerID: UUID, toTeam teamID: String) {
        guard isHost else { return }
        teamState = teamState.assigning(playerID, to: teamID)
        broadcastTeamState()
    }

    func unassignPlayer(_ playerID: UUID) {
        guard isHost else { return }
        teamState = teamState.unassigning(playerID)
        broadcastTeamState()
    }

    func randomizeTeams() {
        guard isHost, let room else { return }
        let ids = room.players.map { $0.id }
        teamState = teamState.randomized(playerIDs: ids)
        broadcastTeamState()
    }

    func autoBalanceTeams() {
        guard isHost, let room else { return }
        let allIDs = room.players.map { $0.id }
        let currentA = teamState.teamA.playerIDs
        let currentB = teamState.teamB.playerIDs
        let unassigned = allIDs.filter { !currentA.contains($0) && !currentB.contains($0) }

        var aList = currentA
        var bList = currentB
        for id in unassigned {
            if aList.count <= bList.count {
                aList.append(id)
            } else {
                bList.append(id)
            }
        }
        teamState = TeamState(teams: [
            TeamAssignment(id: "team_a", name: "Team A", playerIDs: aList),
            TeamAssignment(id: "team_b", name: "Team B", playerIDs: bList)
        ])
        broadcastTeamState()
    }

    private func broadcastTeamState() {
        guard let room else { return }
        let updated = CasualRoom(
            id: room.id,
            code: room.code,
            gameType: room.gameType,
            players: room.players,
            status: room.status,
            maxPlayers: room.maxPlayers,
            minPlayers: room.minPlayers,
            createdAt: room.createdAt,
            playMode: playMode,
            teamState: teamState
        )
        self.room = updated
        Task { await roomService.broadcastRoomState(updated) }
    }

    func leaveRoom() {
        guard let room, let localPlayer else {
            disconnect()
            return
        }

        Task {
            try? await roomService.leaveRoom(
                roomID: room.id,
                playerID: localPlayer.id,
                sessionToken: localPlayer.sessionToken
            )
            await disconnect()
        }
    }

    func disconnect() {
        refreshTask?.cancel()
        refreshTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        waitingTimerTask?.cancel()
        waitingTimerTask = nil
        lobbyStartTime = nil
        waitingTooLong = false
        if MultiplayerTelemetry.shared.elapsedSessionMs() != nil {
            MultiplayerTelemetry.shared.classify(outcome: gameStarted ? .abandoned_by_players : .failed_to_start, phaseAtExit: room?.status.rawValue)
        }
        Task { await MultiplayerTelemetry.shared.flush() }
        MultiplayerTelemetry.shared.clearContext()
        roomService.stopHeartbeat()
        Task {
            if let room, let localPlayer {
                await roomService.markPlayerDisconnected(
                    roomID: room.id,
                    guestPlayerID: localPlayer.id,
                    sessionToken: localPlayer.sessionToken
                )
            }
            await roomService.disconnect()
        }
        room = nil
        localPlayer = nil
        isConnected = false
        gameStarted = false
        readyCheckActive = false
        readyCheckLocalConfirmed = false
        readyConfirmedPlayerIDs.removeAll()
        errorMessage = nil
        // NOTE: wasKicked / roomClosed / hostLeft are one-shot alert flags.
        // They MUST stay true until the alert is dismissed (binding resets them).
        // Don't reset them here or the notification alerts never appear.
    }

    func buildPlayersForSession() -> [PlayerProfile] {
        guard let room else { return [] }
        return room.players.map { guest in
            PlayerProfile(
                id: guest.id,
                username: guest.displayName,
                isHost: guest.isHost,
                isReady: true,
                isOnline: guest.isConnected
            )
        }
    }

    private func setupCallbacks() {
        roomService.onRoomUpdated = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshRoomFromDB()
            }
        }

        roomService.onSyncError = { [weak self] message in
            guard let self else { return }
            self.errorMessage = message
        }

        roomService.onGameStarting = { [weak self] room in
            guard let self else { return }
            self.room = room
            self.playMode = room.playMode
            self.teamState = room.teamState ?? .default
            self.gameStarted = true
            self.readyCheckActive = false
        }

        roomService.onRoomStateBroadcast = { [weak self] room in
            guard let self else { return }
            if self.isHost { return }
            self.room = room
            self.playMode = room.playMode
            self.teamState = room.teamState ?? .default
            self.gameStarted = room.status == .starting || room.status == .inProgress
            if room.status == .starting || room.status == .inProgress {
                self.readyCheckActive = false
            }
        }

        roomService.onPlayerKicked = { [weak self] playerID in
            guard let self else { return }
            if self.localPlayer?.id == playerID {
                MultiplayerTelemetry.shared.log(event: "forced_return_home", source: "kick", props: ["reason": "kicked"])
                MultiplayerTelemetry.shared.classify(outcome: .kicked_player_exit, phaseAtExit: self.room?.status.rawValue)
                if self.gameStarted {
                    self.shouldAutoDismissLobby = true
                    self.onSessionEnded?()
                }
                self.wasKicked = true
                // Invalidate the stored guest session so the kicked player can
                // not silently auto-rejoin this room from a cached session token.
                GuestSessionStore.clear()
                self.disconnect()
            }
        }

        roomService.onRoomClosed = { [weak self] in
            guard let self else { return }
            if !self.isHost {
                MultiplayerTelemetry.shared.log(event: "forced_return_home", source: "room_closed", props: ["reason": "host_closed"])
                MultiplayerTelemetry.shared.classify(outcome: .closed_by_host, phaseAtExit: self.room?.status.rawValue)
                if self.gameStarted {
                    self.shouldAutoDismissLobby = true
                    self.onSessionEnded?()
                }
                self.hostLeft = true
                self.disconnect()
            }
        }

        roomService.onHostChanged = { [weak self] newHostID in
            guard let self else { return }
            if let local = self.localPlayer, local.id == newHostID {
                self.localPlayer = GuestPlayer(
                    id: local.id,
                    displayName: local.displayName,
                    isHost: true,
                    isConnected: local.isConnected,
                    sessionToken: local.sessionToken,
                    joinedAt: local.joinedAt
                )
            }
            Task { @MainActor in
                await self.refreshRoomFromDB()
            }
        }

        roomService.onReadyCheckRequested = { [weak self] hostID in
            guard let self else { return }
            if !self.isHost {
                self.readyCheckActive = true
                self.readyCheckLocalConfirmed = false
                self.readyConfirmedPlayerIDs = [hostID]
            }
        }

        roomService.onReadyCheckConfirmed = { [weak self] playerID in
            guard let self else { return }
            self.readyConfirmedPlayerIDs.insert(playerID)
            if self.isHost {
                self.checkAllReadyAndStart()
            }
        }

        roomService.onReadyCheckCancelled = { [weak self] in
            guard let self else { return }
            self.readyCheckActive = false
            self.readyCheckLocalConfirmed = false
            self.readyConfirmedPlayerIDs.removeAll()
        }
    }

    private func refreshRoomFromDB() async {
        guard let currentRoom = room else { return }
        do {
            let (roomRecord, playerRecords) = try await roomService.fetchRoomFromDB(roomID: currentRoom.id)
            let status = CasualRoomStatus(rawValue: roomRecord.status) ?? .waiting

            // Only an explicit room close (host pressed Leave) ends the session for guests.
            // A host going to background / losing network momentarily does NOT close the room.
            if status == .closed && !isHost {
                if gameStarted {
                    shouldAutoDismissLobby = true
                    onSessionEnded?()
                }
                hostLeft = true
                disconnect()
                return
            }

            let players = playerRecords.map { $0.toGuestPlayer() }
            let confirmedIDs = Set(playerRecords.compactMap { record in
                record.readyConfirmedAt == nil ? nil : record.guestPlayerId
            })

            // DB-fallback kick detection: if we (non-host) are no longer in the player list,
            // the host kicked us. Fires even if the broadcast was missed.
            if !isHost, let localID = localPlayer?.id,
               !players.contains(where: { $0.id == localID }) {
                if gameStarted {
                    shouldAutoDismissLobby = true
                    onSessionEnded?()
                }
                wasKicked = true
                GuestSessionStore.clear()
                disconnect()
                return
            }
            let resolvedPlayMode = currentRoom.playMode
            let resolvedTeamState = resolvedPlayMode == .teamMode ? (currentRoom.teamState ?? teamState) : nil
            room = CasualRoom(
                id: roomRecord.id,
                code: roomRecord.roomCode,
                gameType: currentRoom.gameType,
                players: players,
                status: status,
                maxPlayers: roomRecord.maxPlayers,
                minPlayers: roomRecord.minPlayers,
                createdAt: roomRecord.createdAt ?? Date(),
                playMode: resolvedPlayMode,
                teamState: resolvedTeamState
            )
            readyConfirmedPlayerIDs = confirmedIDs
            if status == .waiting || status == .full {
                readyCheckActive = !confirmedIDs.isEmpty
            } else {
                readyCheckActive = false
            }
            // Host-disconnect banner: show a gentle recovery banner for guests when the
            // host is momentarily offline, but do NOT tear down the room. The host's
            // heartbeat keeps the backend record alive; only an explicit host leave
            // closes the room.
            if !isHost {
                let hostOnline = players.first(where: { $0.isHost })?.isConnected ?? false
                if !hostOnline && status != .closed {
                    if resyncBanner == nil || resyncBanner == "Connection restored" {
                        resyncBanner = "Host disconnected. Reconnecting…"
                    }
                } else if resyncBanner == "Host disconnected. Reconnecting…" {
                    resyncBanner = "Connection restored"
                    Task { [weak self] in
                        try? await Task.sleep(for: .seconds(1))
                        await MainActor.run {
                            if self?.resyncBanner == "Connection restored" {
                                self?.resyncBanner = nil
                            }
                        }
                    }
                }
            }
            if let localID = localPlayer?.id {
                readyCheckLocalConfirmed = confirmedIDs.contains(localID)
            }
            playMode = resolvedPlayMode
            teamState = resolvedTeamState ?? .default
            gameStarted = status == .starting || status == .inProgress
            if isHost {
                checkAllReadyAndStart()
            }
        } catch {
            errorMessage = "Connection lost. Reconnecting…"
        }
    }

    private func startLobbyWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            // Fast watchdog while in lobby / ready-check so state transitions
            // (new joins, ready votes, status=starting) surface quickly even if
            // a realtime broadcast was missed. Slows down once the match is
            // in progress to avoid hammering the DB.
            while !Task.isCancelled {
                let interval: Duration = await MainActor.run {
                    guard let status = self?.room?.status else { return Duration.seconds(3) }
                    switch status {
                    case .waiting, .full, .starting:
                        return Duration.seconds(3)
                    default:
                        return Duration.seconds(8)
                    }
                }
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                await self?.refreshRoomFromDB()
            }
        }
    }

    private func startWaitingTimer() {
        waitingTimerTask?.cancel()
        lobbyStartTime = Date()
        waitingTooLong = false
        waitingTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, let room = self.room, let start = self.lobbyStartTime else { return }
                    let elapsed = Date().timeIntervalSince(start)
                    let hasEnough = room.players.count >= room.minPlayers
                    if hasEnough {
                        self.waitingTooLong = false
                    } else if elapsed >= 30 {
                        self.waitingTooLong = true
                    }
                }
            }
        }
    }

    private func sanitizeName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func validateName(_ name: String) -> CasualRoomError? {
        if name.isEmpty { return .emptyName }
        if name.count < 2 { return .nameTooShort }
        if name.count > 20 { return .nameTooLong }
        return nil
    }

    func createRoom(gameType: GameType, completion: @escaping () -> Void) {
        let trimmedName = sanitizeName(displayName)
        if let error = validateName(trimmedName) {
            errorMessage = error.localizedDescription
            return
        }
        createRoomInternal(gameType: gameType, name: trimmedName)
    }
}
