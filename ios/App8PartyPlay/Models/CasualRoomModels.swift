import Foundation

nonisolated struct GuestPlayer: Identifiable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let normalizedName: String
    let isHost: Bool
    let isConnected: Bool
    let sessionToken: String
    let joinedAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        isHost: Bool = false,
        isConnected: Bool = true,
        sessionToken: String = UUID().uuidString,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.normalizedName = Self.normalize(displayName)
        self.isHost = isHost
        self.isConnected = isConnected
        self.sessionToken = sessionToken
        self.joinedAt = joinedAt
    }

    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}

nonisolated struct CasualRoomRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let roomCode: String
    let gameType: String
    let status: String
    let hostGuestPlayerId: UUID?
    let maxPlayers: Int
    let minPlayers: Int
    let settingsRounds: Int
    let settingsAnswerTime: Int
    let settingsVoteTime: Int
    let settingsQuestionPack: String
    let createdAt: Date?
    let startedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case roomCode = "room_code"
        case gameType = "game_type"
        case status
        case hostGuestPlayerId = "host_guest_player_id"
        case maxPlayers = "max_players"
        case minPlayers = "min_players"
        case settingsRounds = "settings_rounds"
        case settingsAnswerTime = "settings_answer_time"
        case settingsVoteTime = "settings_vote_time"
        case settingsQuestionPack = "settings_question_pack"
        case createdAt = "created_at"
        case startedAt = "started_at"
    }
}

nonisolated struct CasualRoomPlayerRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let roomId: UUID
    let guestPlayerId: UUID
    let displayName: String
    let normalizedDisplayName: String
    let isHost: Bool
    let isConnected: Bool
    let sessionToken: String
    let joinedAt: Date?
    let lastSeenAt: Date?
    let readyConfirmedAt: Date?
    let rematchReadyAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case guestPlayerId = "guest_player_id"
        case displayName = "display_name"
        case normalizedDisplayName = "normalized_display_name"
        case isHost = "is_host"
        case isConnected = "is_connected"
        case sessionToken = "session_token"
        case joinedAt = "joined_at"
        case lastSeenAt = "last_seen_at"
        case readyConfirmedAt = "ready_confirmed_at"
        case rematchReadyAt = "rematch_ready_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        roomId = try c.decode(UUID.self, forKey: .roomId)
        guestPlayerId = try c.decode(UUID.self, forKey: .guestPlayerId)
        displayName = try c.decode(String.self, forKey: .displayName)
        normalizedDisplayName = try c.decode(String.self, forKey: .normalizedDisplayName)
        isHost = try c.decode(Bool.self, forKey: .isHost)
        isConnected = try c.decode(Bool.self, forKey: .isConnected)
        sessionToken = try c.decode(String.self, forKey: .sessionToken)
        joinedAt = try c.decodeIfPresent(Date.self, forKey: .joinedAt)
        lastSeenAt = try c.decodeIfPresent(Date.self, forKey: .lastSeenAt)
        readyConfirmedAt = try c.decodeIfPresent(Date.self, forKey: .readyConfirmedAt)
        rematchReadyAt = try? c.decodeIfPresent(Date.self, forKey: .rematchReadyAt)
    }

    func toGuestPlayer() -> GuestPlayer {
        GuestPlayer(
            id: guestPlayerId,
            displayName: displayName,
            isHost: isHost,
            isConnected: isConnected,
            sessionToken: sessionToken,
            joinedAt: joinedAt ?? Date()
        )
    }
}

nonisolated struct GuestPlayerPayload: Codable, Hashable, Sendable {
    let id: String
    let displayName: String
    let normalizedName: String
    let isHost: Bool
    let isConnected: Bool
    let sessionToken: String
    let joinedAt: Double

    init(from player: GuestPlayer) {
        self.id = player.id.uuidString
        self.displayName = player.displayName
        self.normalizedName = player.normalizedName
        self.isHost = player.isHost
        self.isConnected = player.isConnected
        self.sessionToken = player.sessionToken
        self.joinedAt = player.joinedAt.timeIntervalSince1970
    }

    func toGuestPlayer() -> GuestPlayer? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return GuestPlayer(
            id: uuid,
            displayName: displayName,
            isHost: isHost,
            isConnected: isConnected,
            sessionToken: sessionToken,
            joinedAt: Date(timeIntervalSince1970: joinedAt)
        )
    }
}

nonisolated enum CasualRoomStatus: String, Hashable, Sendable {
    case waiting
    case full
    case starting
    case inProgress = "in_progress"
    case closed
}

nonisolated struct CasualRoom: Identifiable, Hashable, Sendable {
    let id: UUID
    let code: String
    let gameType: GameType
    let players: [GuestPlayer]
    let status: CasualRoomStatus
    let maxPlayers: Int
    let minPlayers: Int
    let createdAt: Date
    let playMode: GameMode
    let teamState: TeamState?

    init(
        id: UUID = UUID(),
        code: String,
        gameType: GameType,
        players: [GuestPlayer] = [],
        status: CasualRoomStatus = .waiting,
        maxPlayers: Int? = nil,
        minPlayers: Int? = nil,
        createdAt: Date = Date(),
        playMode: GameMode = .multiDevice,
        teamState: TeamState? = nil
    ) {
        self.id = id
        self.code = code
        self.gameType = gameType
        self.players = players
        self.status = status
        self.maxPlayers = maxPlayers ?? gameType.maxPlayers
        self.minPlayers = minPlayers ?? gameType.minPlayers
        self.createdAt = createdAt
        self.playMode = playMode
        self.teamState = teamState
    }

    var host: GuestPlayer? { players.first(where: \.isHost) }
    var isFull: Bool { players.count >= maxPlayers }
    var connectedCount: Int { players.filter(\.isConnected).count }
    var canStart: Bool {
        if playMode == .teamMode {
            return players.count >= minPlayers && (teamState?.isValid ?? false)
        }
        return players.count >= minPlayers
    }
    var isTeamMode: Bool { playMode == .teamMode }
}

nonisolated struct CasualRoomStatePayload: Codable, Hashable, Sendable {
    let roomId: String
    let code: String
    let gameKey: String
    let players: [GuestPlayerPayload]
    let status: String
    let maxPlayers: Int
    let minPlayers: Int
    let createdAt: Double
    let playMode: String
    let teamState: TeamState?

    init(from room: CasualRoom) {
        self.roomId = room.id.uuidString
        self.code = room.code
        self.gameKey = room.gameType.rawValue
        self.players = room.players.map { GuestPlayerPayload(from: $0) }
        self.status = room.status.rawValue
        self.maxPlayers = room.maxPlayers
        self.minPlayers = room.minPlayers
        self.createdAt = room.createdAt.timeIntervalSince1970
        self.playMode = room.playMode.rawValue
        self.teamState = room.teamState
    }

    func toCasualRoom() -> CasualRoom? {
        guard let uuid = UUID(uuidString: roomId) else { return nil }
        let guestPlayers = players.compactMap { $0.toGuestPlayer() }
        let roomStatus = CasualRoomStatus(rawValue: status) ?? .waiting
        let resolvedPlayMode = GameMode(rawValue: playMode) ?? .multiDevice
        return CasualRoom(
            id: uuid,
            code: code,
            gameType: GameType(rawValue: gameKey),
            players: guestPlayers,
            status: roomStatus,
            maxPlayers: maxPlayers,
            minPlayers: minPlayers,
            createdAt: Date(timeIntervalSince1970: createdAt),
            playMode: resolvedPlayMode,
            teamState: resolvedPlayMode == .teamMode ? teamState : nil
        )
    }
}

nonisolated enum CasualRoomError: LocalizedError, Sendable {
    case invalidRoomCode
    case roomNotFound
    case roomFull
    case roomAlreadyStarted
    case duplicateName
    case emptyName
    case nameTooShort
    case nameTooLong
    case connectionFailed
    case databaseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidRoomCode: return "Please enter a valid room code."
        case .roomNotFound: return "Room not found. Check the code and try again."
        case .roomFull: return "This room is full."
        case .roomAlreadyStarted: return "This game has already started."
        case .duplicateName: return "This name is already taken in this room. Please choose a different name."
        case .emptyName: return "Please enter a display name."
        case .nameTooShort: return "Name must be at least 2 characters."
        case .nameTooLong: return "Name must be 20 characters or fewer."
        case .connectionFailed: return "Could not connect to the room. Please try again."
        case .databaseError(let msg): return msg
        }
    }
}

nonisolated enum CasualBroadcastEvent: String, Sendable {
    case roomStateSync = "room_state_sync"
    case playerJoined = "player_joined"
    case playerLeft = "player_left"
    case gameStarting = "game_starting"
    case playerKicked = "player_kicked"
    case roomClosed = "room_closed"
    case hostChanged = "host_changed"
    case readyCheckRequested = "ready_check_requested"
    case readyCheckConfirmed = "ready_check_confirmed"
    case readyCheckCancelled = "ready_check_cancelled"
    case roomStateFull = "room_state_full"
    case gameStateSync = "game_state_sync"
    case snapshotRequest = "snapshot_request"
}

nonisolated struct CasualPlayerEventPayload: Codable, Sendable {
    let playerId: String
}

nonisolated struct CasualHostChangedPayload: Codable, Sendable {
    let newHostId: String
}

nonisolated struct CasualReadyCheckRequestPayload: Codable, Sendable {
    let hostId: String
}

nonisolated struct CasualGameStatePayload: Codable, Sendable {
    let sessionId: String
    let originPlayerId: String
    let state: SessionStateRecord
}

nonisolated struct GuestSessionStore {
    private static let tokenKey = "casual_session_token"
    private static let nameKey = "casual_display_name"
    private static let playerIdKey = "casual_player_id"
    private static let roomIdKey = "casual_room_id"

    static func save(playerID: UUID, sessionToken: String, displayName: String, roomID: UUID? = nil) {
        UserDefaults.standard.set(playerID.uuidString, forKey: playerIdKey)
        UserDefaults.standard.set(sessionToken, forKey: tokenKey)
        UserDefaults.standard.set(displayName, forKey: nameKey)
        if let roomID {
            UserDefaults.standard.set(roomID.uuidString, forKey: roomIdKey)
        }
    }

    static func loadPlayerID() -> UUID? {
        guard let str = UserDefaults.standard.string(forKey: playerIdKey) else { return nil }
        return UUID(uuidString: str)
    }

    static func loadSessionToken() -> String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    static func loadDisplayName() -> String? {
        UserDefaults.standard.string(forKey: nameKey)
    }

    static func loadRoomID() -> UUID? {
        guard let str = UserDefaults.standard.string(forKey: roomIdKey) else { return nil }
        return UUID(uuidString: str)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: playerIdKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
        UserDefaults.standard.removeObject(forKey: roomIdKey)
    }
}
