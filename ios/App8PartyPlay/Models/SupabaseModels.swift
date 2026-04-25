import Foundation

nonisolated struct AuthAccount: Hashable, Sendable {
    let id: UUID
    let username: String
    let email: String?
    let provider: AuthProvider
}

nonisolated struct PartyProfileRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let username: String
    let email: String?
    let publicID: Int?
    let displayName: String?
    let avatarURL: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case publicID = "public_id"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
    }
}

nonisolated struct WalletRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userID: UUID
    let starsBalance: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case starsBalance = "stars_balance"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct StarTransactionRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userID: UUID
    let amount: Int
    let transactionType: String
    let reason: String
    let referenceType: String?
    let referenceID: UUID?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case amount
        case transactionType = "transaction_type"
        case reason
        case referenceType = "reference_type"
        case referenceID = "reference_id"
        case createdAt = "created_at"
    }
}

nonisolated struct GameTrialRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userID: UUID
    let gameKey: String
    let timesPlayed: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case gameKey = "game_key"
        case timesPlayed = "times_played"
        case createdAt = "created_at"
    }
}

nonisolated struct GameUnlockRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userID: UUID
    let gameKey: String
    let unlockedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case gameKey = "game_key"
        case unlockedAt = "unlocked_at"
    }
}

nonisolated struct SubscriptionRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userID: UUID
    let tier: String
    let isActive: Bool
    let expiresAt: Date?
    let autoRenews: Bool
    let lastStarGrantDate: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case tier
        case isActive = "is_active"
        case expiresAt = "expires_at"
        case autoRenews = "auto_renews"
        case lastStarGrantDate = "last_star_grant_date"
        case createdAt = "created_at"
    }
}

nonisolated struct RoomRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let code: String
    let gameKey: String
    let hostUserID: UUID
    let status: String
    let access: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case gameKey = "game_key"
        case hostUserID = "host_user_id"
        case status
        case access
        case createdAt = "created_at"
    }
}

nonisolated struct RoomInviteRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let roomID: UUID
    let inviterUserID: UUID
    let invitedUserID: UUID
    let status: String
    let createdAt: Date?
    let room: RoomRecord?

    enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case inviterUserID = "inviter_user_id"
        case invitedUserID = "invited_user_id"
        case status
        case createdAt = "created_at"
        case room = "rooms"
    }
}

nonisolated struct RoomInviteInsertRecord: Codable, Hashable, Sendable {
    let id: UUID
    let roomID: UUID
    let inviterUserID: UUID
    let invitedUserID: UUID
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case inviterUserID = "inviter_user_id"
        case invitedUserID = "invited_user_id"
        case status
    }
}

nonisolated struct RoomMemberRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let roomID: UUID
    let userID: UUID
    let isHost: Bool
    let isReady: Bool
    let joinedAt: Date?
    let profile: PartyProfileRecord?

    enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case userID = "user_id"
        case isHost = "is_host"
        case isReady = "is_ready"
        case joinedAt = "joined_at"
        case profile = "profiles"
    }
}

nonisolated struct GameSessionRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let roomID: UUID?
    let gameKey: String
    let mode: String
    let status: String
    let createdBy: UUID
    let sessionState: SessionStateRecord?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case gameKey = "game_key"
        case mode
        case status
        case createdBy = "created_by"
        case sessionState = "session_state"
        case createdAt = "created_at"
    }
}

nonisolated struct GameResultRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let sessionID: UUID
    let userID: UUID
    let rank: Int
    let score: Int
    let starsAwarded: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case userID = "user_id"
        case rank
        case score
        case starsAwarded = "stars_awarded"
        case createdAt = "created_at"
    }
}

nonisolated struct GameResultUpsertRecord: Codable, Hashable, Sendable {
    let sessionID: UUID
    let userID: UUID
    let rank: Int
    let score: Int
    let starsAwarded: Int

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case userID = "user_id"
        case rank
        case score
        case starsAwarded = "stars_awarded"
    }
}

nonisolated struct SessionStatePlayerRecord: Codable, Hashable, Sendable {
    let id: UUID
    let username: String
    let isHost: Bool
    let isReady: Bool
    let isOnline: Bool
    let score: Int
}

nonisolated struct SessionStateRoundRecord: Codable, Hashable, Sendable {
    let id: UUID
    let index: Int
    let prompt: String
    let activePlayerName: String
    let targetAnswer: String?
    let forbiddenWords: [String]
    let targetSeconds: Double?
}

nonisolated struct SessionStateResultRecord: Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let score: Int
    let rank: Int
    let starsWon: Int
}

nonisolated struct SessionStateLiveStateRecord: Codable, Hashable, Sendable {
    let guessText: String
    let hasStartedTiming: Bool
    let measuredElapsedTime: Double
    let hasSubmittedTiming: Bool
    let promptVisibleToPerformer: Bool
}

nonisolated struct SessionStatePassGuessSettingsRecord: Codable, Hashable, Sendable {
    let rounds: Int
    let questionMode: String
    let selectedQuestionID: UUID?
    let customQuestion: String
    let answerTimeLimit: Int
    let guessTimeLimit: Int

    enum CodingKeys: String, CodingKey {
        case rounds
        case questionMode = "question_mode"
        case selectedQuestionID = "selected_question_id"
        case customQuestion = "custom_question"
        case answerTimeLimit = "answer_time_limit"
        case guessTimeLimit = "guess_time_limit"
    }
}

nonisolated struct SessionStatePassGuessQuestionRecord: Codable, Hashable, Sendable {
    let id: UUID
    let text: String
    let type: String
}

nonisolated struct SessionStatePassGuessAnswerRecord: Codable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let text: String

    enum CodingKeys: String, CodingKey {
        case id
        case playerID = "player_id"
        case text
    }
}

nonisolated struct SessionStatePassGuessVoteRecord: Codable, Hashable, Sendable {
    let id: UUID
    let answerID: UUID
    let voterID: UUID
    let guessedPlayerID: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case answerID = "answer_id"
        case voterID = "voter_id"
        case guessedPlayerID = "guessed_player_id"
    }
}

nonisolated struct SessionStatePassGuessRevealItemRecord: Codable, Hashable, Sendable {
    let id: UUID
    let answerID: UUID
    let answerText: String
    let playerID: UUID
    let playerName: String
    let correctGuessCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case answerID = "answer_id"
        case answerText = "answer_text"
        case playerID = "player_id"
        case playerName = "player_name"
        case correctGuessCount = "correct_guess_count"
    }
}

nonisolated struct SessionStatePassGuessArchivedRoundRecord: Codable, Hashable, Sendable {
    let id: UUID
    let roundNumber: Int
    let question: SessionStatePassGuessQuestionRecord
    let answers: [SessionStatePassGuessAnswerRecord]
    let votes: [SessionStatePassGuessVoteRecord]
    let revealItems: [SessionStatePassGuessRevealItemRecord]

    enum CodingKeys: String, CodingKey {
        case id
        case roundNumber = "round_number"
        case question
        case answers
        case votes
        case revealItems = "reveal_items"
    }
}

nonisolated struct SessionStatePassGuessRoundStateRecord: Codable, Hashable, Sendable {
    let settings: SessionStatePassGuessSettingsRecord
    let phase: String
    let question: SessionStatePassGuessQuestionRecord
    let answers: [SessionStatePassGuessAnswerRecord]
    let votes: [SessionStatePassGuessVoteRecord]
    let revealItems: [SessionStatePassGuessRevealItemRecord]
    let archivedRounds: [SessionStatePassGuessArchivedRoundRecord]

    enum CodingKeys: String, CodingKey {
        case settings
        case phase
        case question
        case answers
        case votes
        case revealItems = "reveal_items"
        case archivedRounds = "archived_rounds"
    }
}

nonisolated struct SessionStateGTSTurnResultRecord: Codable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let round: Int
    let targetTime: Double
    let actualTime: Double
    let difference: Double

    enum CodingKeys: String, CodingKey {
        case id
        case playerID = "player_id"
        case playerName = "player_name"
        case round
        case targetTime = "target_time"
        case actualTime = "actual_time"
        case difference
    }
}

nonisolated struct SessionStateGTSRoundTargetRecord: Codable, Hashable, Sendable {
    let round: Int
    let target: Double
}

nonisolated struct SessionStateGuessTheSecondsRecord: Codable, Hashable, Sendable {
    let activeTurnIndex: Int
    let roundTargets: [SessionStateGTSRoundTargetRecord]
    let turnResults: [SessionStateGTSTurnResultRecord]
    let selectedTime: Double
    let roundsPerPlayer: Int
    let totalTurns: Int

    enum CodingKeys: String, CodingKey {
        case activeTurnIndex = "active_turn_index"
        case roundTargets = "round_targets"
        case turnResults = "turn_results"
        case selectedTime = "selected_time"
        case roundsPerPlayer = "rounds_per_player"
        case totalTurns = "total_turns"
    }
}

nonisolated struct SessionStateMGPlayerResultRecord: Codable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let elapsedSeconds: Double
    let moveCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case playerID = "player_id"
        case playerName = "player_name"
        case elapsedSeconds = "elapsed_seconds"
        case moveCount = "move_count"
    }
}

nonisolated struct SessionStateMGSpectatorTileRecord: Codable, Hashable, Sendable {
    let pairId: Int
    let symbol: String
    let colorIndex: Int
    let isFlipped: Bool
    let isMatched: Bool

    enum CodingKeys: String, CodingKey {
        case pairId = "pair_id"
        case symbol
        case colorIndex = "color_index"
        case isFlipped = "is_flipped"
        case isMatched = "is_matched"
    }
}

nonisolated struct SessionStateMGSpectatorRecord: Codable, Hashable, Sendable {
    let playerID: UUID
    let playerName: String
    let tiles: [SessionStateMGSpectatorTileRecord]
    let matchedPairs: Int
    let moveCount: Int
    let elapsedSeconds: Double

    enum CodingKeys: String, CodingKey {
        case playerID = "player_id"
        case playerName = "player_name"
        case tiles
        case matchedPairs = "matched_pairs"
        case moveCount = "move_count"
        case elapsedSeconds = "elapsed_seconds"
    }
}

nonisolated struct SessionStateMemoryGridRecord: Codable, Hashable, Sendable {
    let gridSize: String
    let currentPlayerIndex: Int
    let playerResults: [SessionStateMGPlayerResultRecord]
    let isFinished: Bool
    let spectator: SessionStateMGSpectatorRecord?

    init(gridSize: String, currentPlayerIndex: Int, playerResults: [SessionStateMGPlayerResultRecord], isFinished: Bool, spectator: SessionStateMGSpectatorRecord? = nil) {
        self.gridSize = gridSize
        self.currentPlayerIndex = currentPlayerIndex
        self.playerResults = playerResults
        self.isFinished = isFinished
        self.spectator = spectator
    }

    enum CodingKeys: String, CodingKey {
        case gridSize = "grid_size"
        case currentPlayerIndex = "current_player_index"
        case playerResults = "player_results"
        case isFinished = "is_finished"
        case spectator
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gridSize = try container.decode(String.self, forKey: .gridSize)
        currentPlayerIndex = try container.decode(Int.self, forKey: .currentPlayerIndex)
        playerResults = try container.decode([SessionStateMGPlayerResultRecord].self, forKey: .playerResults)
        isFinished = try container.decode(Bool.self, forKey: .isFinished)
        spectator = try container.decodeIfPresent(SessionStateMGSpectatorRecord.self, forKey: .spectator)
    }
}

nonisolated struct SessionStateMPPlayerResultRecord: Codable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let progress: Int
    let attempts: Int
    let completionTime: Double?
    let isFinished: Bool
    let score: Int

    enum CodingKeys: String, CodingKey {
        case id
        case playerID = "player_id"
        case playerName = "player_name"
        case progress
        case attempts
        case completionTime = "completion_time"
        case isFinished = "is_finished"
        case score
    }
}

nonisolated struct SessionStateMemoryPathRecord: Codable, Hashable, Sendable {
    let difficulty: String
    let gameMode: String
    let targetSteps: Int
    let pathIndices: [Int]
    let gridSize: Int
    let currentPlayerIndex: Int
    let playerResults: [SessionStateMPPlayerResultRecord]
    let isFinished: Bool

    enum CodingKeys: String, CodingKey {
        case difficulty
        case gameMode = "game_mode"
        case targetSteps = "target_steps"
        case pathIndices = "path_indices"
        case gridSize = "grid_size"
        case currentPlayerIndex = "current_player_index"
        case playerResults = "player_results"
        case isFinished = "is_finished"
    }
}

nonisolated struct SessionStateTIOResultRecord: Codable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let elapsedSeconds: Double
    let missTaps: Int
    let didFinish: Bool

    let variant: String
    let correctCount: Int
    let totalTargets: Int

    init(id: UUID, playerID: UUID, playerName: String, variant: String, elapsedSeconds: Double, correctCount: Int, totalTargets: Int, missTaps: Int, didFinish: Bool) {
        self.id = id
        self.playerID = playerID
        self.playerName = playerName
        self.variant = variant
        self.elapsedSeconds = elapsedSeconds
        self.correctCount = correctCount
        self.totalTargets = totalTargets
        self.missTaps = missTaps
        self.didFinish = didFinish
    }

    enum CodingKeys: String, CodingKey {
        case id
        case playerID = "player_id"
        case playerName = "player_name"
        case variant
        case elapsedSeconds = "elapsed_seconds"
        case correctCount = "correct_count"
        case totalTargets = "total_targets"
        case missTaps = "miss_taps"
        case didFinish = "did_finish"
    }
}

nonisolated struct SessionStateTapInOrderRecord: Codable, Hashable, Sendable {
    let variant: String
    let gridSize: Int
    let tileCount: Int
    let seed: String
    let selectedCells: [Int]
    let currentPlayerIndex: Int
    let playerResults: [SessionStateTIOResultRecord]
    let isFinished: Bool

    enum CodingKeys: String, CodingKey {
        case variant
        case gridSize = "grid_size"
        case tileCount = "tile_count"
        case seed
        case selectedCells = "selected_cells"
        case currentPlayerIndex = "current_player_index"
        case playerResults = "player_results"
        case isFinished = "is_finished"
    }

    init(variant: String, gridSize: Int, tileCount: Int, seed: String, selectedCells: [Int], currentPlayerIndex: Int, playerResults: [SessionStateTIOResultRecord], isFinished: Bool) {
        self.variant = variant
        self.gridSize = gridSize
        self.tileCount = tileCount
        self.seed = seed
        self.selectedCells = selectedCells
        self.currentPlayerIndex = currentPlayerIndex
        self.playerResults = playerResults
        self.isFinished = isFinished
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.variant = try c.decodeIfPresent(String.self, forKey: .variant) ?? "number_memory"
        self.gridSize = try c.decodeIfPresent(Int.self, forKey: .gridSize) ?? 4
        self.tileCount = try c.decodeIfPresent(Int.self, forKey: .tileCount) ?? 6
        self.seed = try c.decodeIfPresent(String.self, forKey: .seed) ?? "0"
        self.selectedCells = try c.decodeIfPresent([Int].self, forKey: .selectedCells) ?? []
        self.currentPlayerIndex = try c.decodeIfPresent(Int.self, forKey: .currentPlayerIndex) ?? 0
        self.playerResults = try c.decodeIfPresent([SessionStateTIOResultRecord].self, forKey: .playerResults) ?? []
        self.isFinished = try c.decodeIfPresent(Bool.self, forKey: .isFinished) ?? false
    }
}

nonisolated struct SessionStateCTResultRecord: Codable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let hits: Int
    let fails: Int
    let survivalTime: Double
    let eliminated: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case playerID = "player_id"
        case playerName = "player_name"
        case hits
        case fails
        case survivalTime = "survival_time"
        case eliminated
    }
}

nonisolated struct SessionStateColorTrapRecord: Codable, Hashable, Sendable {
    let difficulty: String
    let seed: String
    let forbiddenColorIndex: Int
    let currentPlayerIndex: Int
    let playerResults: [SessionStateCTResultRecord]
    let isFinished: Bool

    enum CodingKeys: String, CodingKey {
        case difficulty
        case seed
        case forbiddenColorIndex = "forbidden_color_index"
        case currentPlayerIndex = "current_player_index"
        case playerResults = "player_results"
        case isFinished = "is_finished"
    }
}

nonisolated struct SessionStateRecord: Codable, Hashable, Sendable {
    let gameKey: String
    let mode: String
    let roomCode: String?
    let players: [SessionStatePlayerRecord]
    let rounds: [SessionStateRoundRecord]
    let currentRoundIndex: Int
    let phase: String
    let secondsRemaining: Int
    let latestAwardedPoints: Int
    let latestFeedback: String
    let results: [SessionStateResultRecord]
    let liveState: SessionStateLiveStateRecord
    let passGuessState: SessionStatePassGuessRoundStateRecord?
    let guessTheSecondsState: SessionStateGuessTheSecondsRecord?
    let memoryGridState: SessionStateMemoryGridRecord?
    let memoryPathState: SessionStateMemoryPathRecord?
    let tapInOrderState: SessionStateTapInOrderRecord?
    let colorTrapState: SessionStateColorTrapRecord?
    let rematchPlayerIDs: [String]
    let stateVersion: Int

    init(
        gameKey: String,
        mode: String,
        roomCode: String?,
        players: [SessionStatePlayerRecord],
        rounds: [SessionStateRoundRecord],
        currentRoundIndex: Int,
        phase: String,
        secondsRemaining: Int,
        latestAwardedPoints: Int,
        latestFeedback: String,
        results: [SessionStateResultRecord],
        liveState: SessionStateLiveStateRecord,
        passGuessState: SessionStatePassGuessRoundStateRecord? = nil,
        guessTheSecondsState: SessionStateGuessTheSecondsRecord? = nil,
        memoryGridState: SessionStateMemoryGridRecord? = nil,
        memoryPathState: SessionStateMemoryPathRecord? = nil,
        tapInOrderState: SessionStateTapInOrderRecord? = nil,
        colorTrapState: SessionStateColorTrapRecord? = nil,
        rematchPlayerIDs: [String] = [],
        stateVersion: Int = 0
    ) {
        self.gameKey = gameKey
        self.mode = mode
        self.roomCode = roomCode
        self.players = players
        self.rounds = rounds
        self.currentRoundIndex = currentRoundIndex
        self.phase = phase
        self.secondsRemaining = secondsRemaining
        self.latestAwardedPoints = latestAwardedPoints
        self.latestFeedback = latestFeedback
        self.results = results
        self.liveState = liveState
        self.passGuessState = passGuessState
        self.guessTheSecondsState = guessTheSecondsState
        self.memoryGridState = memoryGridState
        self.memoryPathState = memoryPathState
        self.tapInOrderState = tapInOrderState
        self.colorTrapState = colorTrapState
        self.rematchPlayerIDs = rematchPlayerIDs
        self.stateVersion = stateVersion
    }

    enum CodingKeys: String, CodingKey {
        case gameKey
        case mode
        case roomCode
        case players
        case rounds
        case currentRoundIndex
        case phase
        case secondsRemaining
        case latestAwardedPoints
        case latestFeedback
        case results
        case liveState
        case passGuessState = "pass_guess_state"
        case guessTheSecondsState = "guess_the_seconds_state"
        case memoryGridState = "memory_grid_state"
        case memoryPathState = "memory_path_state"
        case tapInOrderState = "tap_in_order_state"
        case colorTrapState = "color_trap_state"
        case rematchPlayerIDs = "rematch_player_ids"
        case stateVersion = "state_version"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gameKey = try c.decode(String.self, forKey: .gameKey)
        mode = try c.decode(String.self, forKey: .mode)
        roomCode = try c.decodeIfPresent(String.self, forKey: .roomCode)
        players = try c.decode([SessionStatePlayerRecord].self, forKey: .players)
        rounds = try c.decode([SessionStateRoundRecord].self, forKey: .rounds)
        currentRoundIndex = try c.decode(Int.self, forKey: .currentRoundIndex)
        phase = try c.decode(String.self, forKey: .phase)
        secondsRemaining = try c.decode(Int.self, forKey: .secondsRemaining)
        latestAwardedPoints = try c.decode(Int.self, forKey: .latestAwardedPoints)
        latestFeedback = try c.decode(String.self, forKey: .latestFeedback)
        results = try c.decode([SessionStateResultRecord].self, forKey: .results)
        liveState = try c.decode(SessionStateLiveStateRecord.self, forKey: .liveState)
        passGuessState = try c.decodeIfPresent(SessionStatePassGuessRoundStateRecord.self, forKey: .passGuessState)
        guessTheSecondsState = try c.decodeIfPresent(SessionStateGuessTheSecondsRecord.self, forKey: .guessTheSecondsState)
        memoryGridState = try c.decodeIfPresent(SessionStateMemoryGridRecord.self, forKey: .memoryGridState)
        memoryPathState = try c.decodeIfPresent(SessionStateMemoryPathRecord.self, forKey: .memoryPathState)
        tapInOrderState = try c.decodeIfPresent(SessionStateTapInOrderRecord.self, forKey: .tapInOrderState)
        colorTrapState = try c.decodeIfPresent(SessionStateColorTrapRecord.self, forKey: .colorTrapState)
        rematchPlayerIDs = (try? c.decodeIfPresent([String].self, forKey: .rematchPlayerIDs)) ?? []
        stateVersion = (try? c.decodeIfPresent(Int.self, forKey: .stateVersion)) ?? 0
    }
}

nonisolated struct FriendRequestRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let senderID: UUID
    let receiverID: UUID
    let status: String
    let createdAt: Date?
    let senderProfile: PartyProfileRecord?

    enum CodingKeys: String, CodingKey {
        case id
        case senderID = "sender_id"
        case receiverID = "receiver_id"
        case status
        case createdAt = "created_at"
        case senderProfile = "sender"
    }
}

nonisolated struct FriendRequestInsertPayload: Encodable, Hashable, Sendable {
    let receiverID: UUID

    init(receiverID: UUID) {
        self.receiverID = receiverID
    }

    enum CodingKeys: String, CodingKey {
        case receiverID = "p_receiver_id"
    }
}

nonisolated struct FriendshipRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userID: UUID
    let friendID: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case friendID = "friend_id"
        case createdAt = "created_at"
    }
}

nonisolated struct FriendSearchResponseRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let username: String
    let email: String?
    let publicID: Int?
    let avatarURL: String?
    let relationshipState: FriendRelationshipState

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case publicID = "public_id"
        case avatarURL = "avatar_url"
        case relationshipState = "relationship_state"
    }
}

nonisolated struct ProfileBootstrapPayload: Encodable, Hashable, Sendable {
    let username: String
    let email: String?

    enum CodingKeys: String, CodingKey {
        case username = "p_username"
        case email = "p_email"
    }
}

nonisolated struct ProfileUpdatePayload: Encodable, Hashable, Sendable {
    let username: String
    let displayName: String
    let publicID: Int?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case username = "p_username"
        case displayName = "p_display_name"
        case publicID = "p_public_id"
        case avatarURL = "p_avatar_url"
    }
}

nonisolated struct RewardRPCPayload: Encodable, Hashable, Sendable {
    let sessionId: UUID
    let idempotencyKey: UUID

    enum CodingKeys: String, CodingKey {
        case sessionId = "p_session_id"
        case idempotencyKey = "p_idempotency_key"
    }
}

nonisolated struct WalletRPCPayload: Encodable, Hashable, Sendable {
    let amount: Int
    let idempotencyKey: UUID

    enum CodingKeys: String, CodingKey {
        case amount = "p_amount"
        case idempotencyKey = "p_idempotency_key"
    }
}

nonisolated struct FriendRequestActionPayload: Encodable, Hashable, Sendable {
    let requestID: UUID

    enum CodingKeys: String, CodingKey {
        case requestID = "p_request_id"
    }
}

nonisolated struct InviteSummaryRecord: Codable, Hashable, Sendable {
    let totalInvites: Int
    let starsEarned: Int

    enum CodingKeys: String, CodingKey {
        case totalInvites = "total_invites"
        case starsEarned = "stars_earned"
    }
}

nonisolated struct RedeemInviteResponse: Codable, Hashable, Sendable {
    let ok: Bool
    let reason: String?
    let inviterReward: Int?
    let inviteeReward: Int?

    enum CodingKeys: String, CodingKey {
        case ok
        case reason
        case inviterReward = "inviter_reward"
        case inviteeReward = "invitee_reward"
    }
}

nonisolated struct RedeemInvitePayload: Encodable, Hashable, Sendable {
    let code: String

    enum CodingKeys: String, CodingKey {
        case code = "p_code"
    }
}

nonisolated struct DeviceTokenRecord: Codable, Hashable, Sendable {
    let userID: UUID
    let token: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case token
        case platform
    }
}

nonisolated struct SessionStateUpdatePayload: Encodable, Hashable, Sendable {
    let sessionID: UUID
    let status: String
    let sessionState: SessionStateRecord

    enum CodingKeys: String, CodingKey {
        case sessionID = "id"
        case status
        case sessionState = "session_state"
    }
}

nonisolated struct SessionResultsPersistencePayload: Hashable, Sendable {
    let status: String
    let results: [GameResultUpsertRecord]
}

nonisolated struct GrantSubscriptionStarsPayload: Encodable, Hashable, Sendable {
    let amount: Int
    let tier: String
    let periodKey: String
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case amount = "p_amount"
        case tier = "p_tier"
        case periodKey = "p_period_key"
        case expiresAt = "p_expires_at"
    }
}

nonisolated struct GrantPurchasedStarsPayload: Encodable, Hashable, Sendable {
    let amount: Int
    let productID: String
    let idempotencyKey: UUID

    enum CodingKeys: String, CodingKey {
        case amount = "p_amount"
        case productID = "p_product_id"
        case idempotencyKey = "p_idempotency_key"
    }
}
