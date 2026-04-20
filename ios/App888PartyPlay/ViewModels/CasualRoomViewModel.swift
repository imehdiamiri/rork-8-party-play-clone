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
    var waitingTooLong: Bool = false
    var isReconnecting: Bool = false
    var fakeAnswerSettings: FakeAnswerSettings = .default
    var teamState: TeamState = .default
    var playMode: GameMode = .multiDevice

    private let roomService: CasualRoomService
    private var refreshTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var waitingTimerTask: Task<Void, Never>?
    private var lobbyStartTime: Date?
    private let hostTimeoutSeconds: TimeInterval = 15

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
            refreshTask?.cancel()
            refreshTask = nil
            watchdogTask?.cancel()
            watchdogTask = nil
            waitingTimerTask?.cancel()
            waitingTimerTask = nil
            roomService.stopHeartbeat()
        case .active:
            guard isConnected, let room, let token = localPlayer?.sessionToken, !token.isEmpty else { return }
            isReconnecting = true
            roomService.startHeartbeat(roomID: room.id, sessionToken: token)
            startLobbyWatchdog()
            startWaitingTimer()
            Task {
                await refreshRoomFromDB()
                isReconnecting = false
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
                room = rejoinedRoom
                localPlayer = player
                isConnected = true
                fakeAnswerSettings = rejoinedRoom.settings
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
                    host: host,
                    settings: fakeAnswerSettings
                )
                room = created
                isConnected = true
                GuestSessionStore.save(playerID: playerID, sessionToken: token, displayName: name, roomID: created.id)
                setupCallbacks()
                roomService.startHeartbeat(roomID: created.id, sessionToken: token)
                startLobbyWatchdog()
                startWaitingTimer()
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
                isConnected = true
                GuestSessionStore.save(playerID: playerID, sessionToken: token, displayName: trimmedName, roomID: joined.id)
                setupCallbacks()
                roomService.startHeartbeat(roomID: joined.id, sessionToken: token)
                startLobbyWatchdog()
                startWaitingTimer()
            } catch {
                errorMessage = error.localizedDescription
                localPlayer = nil
            }
        }
    }

    func kickPlayer(_ player: GuestPlayer) {
        guard isHost, let room, player.id != localPlayer?.id else { return }
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
        guard canStart, let room else { return }
        let startingRoom = CasualRoom(
            id: room.id,
            code: room.code,
            gameType: room.gameType,
            players: room.players,
            status: .starting,
            maxPlayers: room.maxPlayers,
            minPlayers: room.minPlayers,
            createdAt: room.createdAt,
            settings: room.settings,
            playMode: playMode,
            teamState: playMode == .teamMode ? teamState : nil
        )
        self.room = startingRoom
        gameStarted = true
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
            settings: room.settings,
            playMode: playMode,
            teamState: teamState
        )
        self.room = updated
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
        wasKicked = false
        roomClosed = false
        errorMessage = nil
    }

    func updateSettings(_ settings: FakeAnswerSettings) {
        fakeAnswerSettings = settings
        guard isHost, let room else { return }
        let updated = CasualRoom(
            id: room.id,
            code: room.code,
            gameType: room.gameType,
            players: room.players,
            status: room.status,
            maxPlayers: room.maxPlayers,
            minPlayers: room.minPlayers,
            createdAt: room.createdAt,
            settings: settings,
            playMode: playMode,
            teamState: playMode == .teamMode ? teamState : nil
        )
        self.room = updated
        Task {
            try? await roomService.updateRoomSettings(
                roomID: room.id,
                settings: settings,
                hostSessionToken: sessionToken
            )
        }
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
            self.gameStarted = true
        }

        roomService.onPlayerKicked = { [weak self] playerID in
            guard let self else { return }
            if self.localPlayer?.id == playerID {
                self.wasKicked = true
                self.disconnect()
            }
        }

        roomService.onRoomClosed = { [weak self] in
            guard let self else { return }
            if !self.isHost {
                self.roomClosed = true
                self.disconnect()
            }
        }

        roomService.onHostChanged = { [weak self] newHostID in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshRoomFromDB()
            }
        }
    }

    private func refreshRoomFromDB() async {
        guard let currentRoom = room else { return }
        do {
            let (roomRecord, playerRecords) = try await roomService.fetchRoomFromDB(roomID: currentRoom.id)
            let status = CasualRoomStatus(rawValue: roomRecord.status) ?? .waiting

            if status == .closed && !isHost {
                roomClosed = true
                disconnect()
                return
            }

            if !isHost, let hostRecord = playerRecords.first(where: { $0.isHost }) {
                let hostLastSeen = hostRecord.lastSeenAt ?? hostRecord.joinedAt ?? Date()
                let staleFor = Date().timeIntervalSince(hostLastSeen)
                if !hostRecord.isConnected || staleFor > hostTimeoutSeconds {
                    hostLeft = true
                    disconnect()
                    return
                }
            }

            let players = playerRecords.map { $0.toGuestPlayer() }
            let settings = FakeAnswerSettings(
                rounds: roomRecord.settingsRounds,
                answerTime: roomRecord.settingsAnswerTime,
                voteTime: roomRecord.settingsVoteTime,
                questionPack: FakeAnswerQuestionPack(rawValue: roomRecord.settingsQuestionPack) ?? .random
            )
            room = CasualRoom(
                id: roomRecord.id,
                code: roomRecord.roomCode,
                gameType: currentRoom.gameType,
                players: players,
                status: status,
                maxPlayers: roomRecord.maxPlayers,
                minPlayers: roomRecord.minPlayers,
                createdAt: roomRecord.createdAt ?? Date(),
                settings: settings,
                playMode: playMode,
                teamState: playMode == .teamMode ? teamState : nil
            )
        } catch {
            errorMessage = "Connection lost. Reconnecting…"
        }
    }

    private func startLobbyWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
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
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if let room = self.room, room.players.count < room.minPlayers {
                    self.waitingTooLong = true
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
