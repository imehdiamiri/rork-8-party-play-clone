import Foundation
import SwiftUI

nonisolated enum AuthProvider: String, CaseIterable, Hashable, Sendable {
    case username
    case google
    case apple
    case guest

    var title: String {
        switch self {
        case .username: return "Username"
        case .google: return "Google"
        case .apple: return "Apple"
        case .guest: return "Guest"
        }
    }
}

nonisolated enum AppTab: Hashable, Sendable {
    case home
    case cards
    case social
    case generator
}

nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        }
    }
}

nonisolated enum LegalLinks {
    static let privacyPolicyURL: URL = AppConstants.URLs.privacyPolicy
    static let termsOfServiceURL: URL = AppConstants.URLs.termsOfService
}

nonisolated enum GameMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case singleDevice
    case multiDevice
    case teamMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleDevice: return "1 Phone"
        case .multiDevice: return "Multi Phone"
        case .teamMode: return "Team Mode"
        }
    }

    var subtitle: String {
        switch self {
        case .singleDevice: return "Everyone plays on 1 phone"
        case .multiDevice: return "Everyone plays on their own phone"
        case .teamMode: return "Split into 2 teams and compete"
        }
    }

    var icon: String {
        switch self {
        case .singleDevice: return "iphone.gen3"
        case .multiDevice: return "apps.iphone"
        case .teamMode: return "person.line.dotted.person.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .singleDevice: return .blue
        case .multiDevice: return .green
        case .teamMode: return .purple
        }
    }

    var shortLabel: String {
        switch self {
        case .singleDevice: return "1-D"
        case .multiDevice: return "Multi-D"
        case .teamMode: return "Team"
        }
    }
}

nonisolated struct GameType: RawRepresentable, Identifiable, Hashable, Sendable {
    let rawValue: String
    let name: String
    let shortDescription: String
    let minPlayers: Int
    let maxPlayers: Int
    let unlockCostStars: Int
    let isFreeForever: Bool
    let hasFreeTrial: Bool
    let isPremium: Bool
    let symbolName: String
    let supportedModes: [GameMode]
    let roundDuration: Int
    let heroImageURL: String?

    static let reverseSinging = GameType(
        rawValue: "reverse_singing",
        name: "Reverse Singing",
        shortDescription: "Pass the phone. Record anything. Hear it reversed. Mimic it. Compare the chaos.",
        minPlayers: 2,
        maxPlayers: 30,
        unlockCostStars: 0,
        isFreeForever: true,
        hasFreeTrial: false,
        symbolName: "backward.fill",
        supportedModes: [.singleDevice],
        roundDuration: 75,
        heroImageURL: "https://r2-pub.rork.com/generated-images/b17e5d76-7bf4-46aa-b32c-34db233473bd.png"
    )

    static let guessTheSeconds = GameType(
        rawValue: "guess_the_seconds",
        name: "Guess the Seconds",
        shortDescription: "Choose a target time, hide it, count in your head, then stop as close as you can.",
        minPlayers: 2,
        maxPlayers: 30,
        unlockCostStars: 0,
        isFreeForever: true,
        hasFreeTrial: false,
        symbolName: "stopwatch.fill",
        supportedModes: [.singleDevice],
        roundDuration: 90,
        heroImageURL: "https://r2-pub.rork.com/generated-images/d8092484-fefa-4921-9732-636c97a59a09.png"
    )

    static let tenTangle = GameType(
        rawValue: "ten_tangle",
        name: "Ten Tangle",
        shortDescription: "Get a secret number 1–10, act it out for a scenario, and fool the guesser.",
        minPlayers: 3,
        maxPlayers: 11,
        unlockCostStars: 0,
        isFreeForever: false,
        hasFreeTrial: false,
        isPremium: true,
        symbolName: "theatermasks.fill",
        supportedModes: [.singleDevice],
        roundDuration: 0,
        heroImageURL: "https://r2-pub.rork.com/generated-images/e877a51b-281e-4b8c-bb95-823ae44216f1.png"
    )

    static let imposter = GameType(
        rawValue: "imposter",
        name: "Imposter",
        shortDescription: "One player is the Imposter — find them before it's too late, or bluff your way to victory.",
        minPlayers: 4,
        maxPlayers: 30,
        unlockCostStars: 0,
        isFreeForever: true,
        hasFreeTrial: false,
        symbolName: "eye.fill",
        supportedModes: [.singleDevice],
        roundDuration: 0,
        heroImageURL: "https://r2-pub.rork.com/generated-images/01a6d899-88d4-4d01-8758-7dd451fd48da.png"
    )

    static let memoryGrid = GameType(
        rawValue: "memory_grid",
        name: "Memory Grid",
        shortDescription: "Flip tiles, find matching pairs, and race the clock — or your friends.",
        minPlayers: 1,
        maxPlayers: 30,
        unlockCostStars: 0,
        isFreeForever: true,
        hasFreeTrial: false,
        symbolName: "square.grid.3x3.fill",
        supportedModes: [.singleDevice, .multiDevice, .teamMode],
        roundDuration: 0,
        heroImageURL: "https://r2-pub.rork.com/generated-images/630d9ac5-1895-4593-9ea2-7cd581f42ce6.png"
    )

    static let memoryPath = GameType(
        rawValue: "memory_path",
        name: "Memory Path",
        shortDescription: "Find the hidden path from start to end — one wrong step and you restart.",
        minPlayers: 2,
        maxPlayers: 30,
        unlockCostStars: 0,
        isFreeForever: false,
        hasFreeTrial: false,
        isPremium: true,
        symbolName: "map.fill",
        supportedModes: [.singleDevice, .multiDevice, .teamMode],
        roundDuration: 0,
        heroImageURL: "https://r2-pub.rork.com/generated-images/8f997aac-f4e2-46f7-92d6-aa55f8b197ff.png"
    )

    static let tapInOrder = GameType(
        rawValue: "tap_in_order",
        name: "Tap in Order",
        shortDescription: "Race against the clock to tap numbered tiles in order. Same board for every player.",
        minPlayers: 1,
        maxPlayers: 30,
        unlockCostStars: 0,
        isFreeForever: false,
        hasFreeTrial: false,
        isPremium: true,
        symbolName: "number.square.fill",
        supportedModes: [.singleDevice, .multiDevice],
        roundDuration: 0,
        heroImageURL: nil
    )

    static let colorTrap = GameType(
        rawValue: "color_trap",
        name: "Color Trap",
        shortDescription: "Tap every color except the forbidden one. Three strikes and you're out.",
        minPlayers: 1,
        maxPlayers: 30,
        unlockCostStars: 0,
        isFreeForever: false,
        hasFreeTrial: false,
        isPremium: true,
        symbolName: "paintpalette.fill",
        supportedModes: [.singleDevice, .multiDevice],
        roundDuration: 0,
        heroImageURL: nil
    )

    static let passGuess = GameType(
        rawValue: "pass_guess",
        name: "Pass & Guess",
        shortDescription: "Pass one phone, write private answers, then guess who wrote each one before the final reveal.",
        minPlayers: 2,
        maxPlayers: 30,
        unlockCostStars: 0,
        isFreeForever: false,
        hasFreeTrial: false,
        isPremium: true,
        symbolName: "text.bubble.fill",
        supportedModes: [.singleDevice],
        roundDuration: 0,
        heroImageURL: "https://r2-pub.rork.com/generated-images/9501d164-3c05-4a45-9d4e-51ffe0fd7aca.png"
    )

    static let spinBottle = GameType(
        rawValue: "spin_bottle",
        name: "Truth & Dare",
        shortDescription: "Spin the bottle, get picked, and pick Truth or Dare. Classic party energy.",
        minPlayers: 3,
        maxPlayers: 12,
        unlockCostStars: 0,
        isFreeForever: true,
        hasFreeTrial: false,
        symbolName: "arrow.triangle.2.circlepath",
        supportedModes: [.singleDevice],
        roundDuration: 0,
        heroImageURL: nil
    )

    static let drawRush = GameType(
        rawValue: "draw_rush",
        name: "Draw & Rush",
        shortDescription: "One player draws a secret concept while everyone else rushes to guess what it is.",
        minPlayers: 2,
        maxPlayers: 12,
        unlockCostStars: 0,
        isFreeForever: false,
        hasFreeTrial: false,
        isPremium: true,
        symbolName: "pencil.and.scribble",
        supportedModes: [.singleDevice, .multiDevice],
        roundDuration: 100,
        heroImageURL: nil
    )

    static let library: [GameType] = [
        .reverseSinging,
        .guessTheSeconds,
        .imposter,
        .memoryGrid,
        .tenTangle,
        .memoryPath,
        .passGuess,
        .tapInOrder,
        .colorTrap,
        .drawRush,
        .spinBottle
    ]


    var id: String { rawValue }

    init(rawValue: String) {
        if let knownGame = Self.library.first(where: { $0.rawValue == rawValue }) {
            self = knownGame
            return
        }
        self.rawValue = rawValue
        self.name = "New Game"
        self.shortDescription = "A new game module can be added here."
        self.minPlayers = 2
        self.maxPlayers = 8
        self.unlockCostStars = 0
        self.isFreeForever = false
        self.hasFreeTrial = false
        self.isPremium = true
        self.symbolName = "sparkles.rectangle.stack.fill"
        self.supportedModes = [.singleDevice]
        self.roundDuration = 30
        self.heroImageURL = nil
    }

    init(
        rawValue: String,
        name: String,
        shortDescription: String,
        minPlayers: Int,
        maxPlayers: Int,
        unlockCostStars: Int,
        isFreeForever: Bool,
        hasFreeTrial: Bool,
        isPremium: Bool = false,
        symbolName: String,
        supportedModes: [GameMode],
        roundDuration: Int,
        heroImageURL: String? = nil
    ) {
        self.rawValue = rawValue
        self.name = name
        self.shortDescription = shortDescription
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.unlockCostStars = unlockCostStars
        self.isFreeForever = isFreeForever
        self.hasFreeTrial = hasFreeTrial
        self.isPremium = isPremium
        self.symbolName = symbolName
        self.supportedModes = supportedModes
        self.roundDuration = roundDuration
        self.heroImageURL = heroImageURL
    }

    var playerCountText: String {
        "\(minPlayers)–\(maxPlayers) players"
    }

    func supports(mode: GameMode) -> Bool {
        supportedModes.contains(mode)
    }
}

nonisolated struct GameDefinition: Identifiable, Hashable, Sendable {
    let id: GameType
    let accentName: String
}

nonisolated struct PlayerProfile: Identifiable, Hashable, Sendable {
    let id: UUID
    let username: String
    let isHost: Bool
    let isReady: Bool
    let isOnline: Bool
    let score: Int

    init(id: UUID = UUID(), username: String, isHost: Bool = false, isReady: Bool = false, isOnline: Bool = true, score: Int = 0) {
        self.id = id
        self.username = username
        self.isHost = isHost
        self.isReady = isReady
        self.isOnline = isOnline
        self.score = score
    }
}

nonisolated enum RoomStatus: String, CaseIterable, Hashable, Sendable {
    case draft
    case waiting
    case full
    case starting
    case inProgress = "in_progress"
    case completed
    case cancelled

    var displayTitle: String {
        switch self {
        case .draft: return "Draft"
        case .waiting: return "Waiting"
        case .full: return "Full"
        case .starting: return "Starting"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var tint: Color {
        switch self {
        case .draft: return .gray
        case .waiting: return .orange
        case .full: return .yellow
        case .starting: return .blue
        case .inProgress: return .green
        case .completed: return .purple
        case .cancelled: return .red
        }
    }
}

nonisolated enum PlayerRoomState: String, Hashable, Sendable {
    case invited
    case joined
    case ready
    case left
    case kicked
}

nonisolated enum RoomAccess: String, CaseIterable, Identifiable, Hashable, Sendable {
    case privateRoom = "private"
    case publicRoom = "public"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privateRoom: return "Private"
        case .publicRoom: return "Public"
        }
    }

    var subtitle: String {
        switch self {
        case .privateRoom: return "Only invited friends can join"
        case .publicRoom: return "Visible to all online players"
        }
    }

    var systemImage: String {
        switch self {
        case .privateRoom: return "lock.fill"
        case .publicRoom: return "globe"
        }
    }
}

nonisolated struct GameRoom: Identifiable, Hashable, Sendable {
    let id: UUID
    let code: String
    let game: GameType
    let mode: GameMode
    let hostName: String
    let players: [PlayerProfile]
    let message: String
    let access: RoomAccess
    let invitedFriendIDs: Set<UUID>
    let status: RoomStatus
    let minPlayers: Int
    let maxPlayers: Int

    init(
        id: UUID = UUID(),
        code: String,
        game: GameType,
        mode: GameMode = .multiDevice,
        hostName: String,
        players: [PlayerProfile],
        message: String,
        access: RoomAccess = .privateRoom,
        invitedFriendIDs: Set<UUID> = [],
        status: RoomStatus = .waiting,
        minPlayers: Int? = nil,
        maxPlayers: Int? = nil
    ) {
        self.id = id
        self.code = code
        self.game = game
        self.mode = mode
        self.hostName = hostName
        self.players = players
        self.message = message
        self.access = access
        self.invitedFriendIDs = invitedFriendIDs
        self.status = status
        self.minPlayers = minPlayers ?? game.minPlayers
        self.maxPlayers = maxPlayers ?? game.maxPlayers
    }

    var readyCount: Int { players.filter(\.isReady).count }
    var onlineCount: Int { players.filter(\.isOnline).count }
    var allPlayersReady: Bool { players.allSatisfy(\.isReady) }
    var isFull: Bool { players.count >= maxPlayers }
}

nonisolated struct RoomInvite: Identifiable, Hashable, Sendable {
    let id: UUID
    let roomID: UUID
    let roomCode: String
    let game: GameType
    let hostName: String
    let invitedAt: Date?
    let mode: GameMode

    init(id: UUID, roomID: UUID, roomCode: String, game: GameType, hostName: String, invitedAt: Date?, mode: GameMode = .multiDevice) {
        self.id = id
        self.roomID = roomID
        self.roomCode = roomCode
        self.game = game
        self.hostName = hostName
        self.invitedAt = invitedAt
        self.mode = mode
    }
}

nonisolated enum FriendKind: String, Hashable, Sendable {
    case offline
    case online
}

nonisolated struct Friend: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let isOnline: Bool
    let status: String
    let kind: FriendKind
    let publicUserID: Int?
    let avatarURL: String?

    init(id: UUID = UUID(), name: String, isOnline: Bool, status: String, kind: FriendKind, publicUserID: Int? = nil, avatarURL: String? = nil) {
        self.id = id
        self.name = name
        self.isOnline = isOnline
        self.status = status
        self.kind = kind
        self.publicUserID = publicUserID
        self.avatarURL = avatarURL
    }
}

nonisolated enum FriendRelationshipState: String, Codable, Hashable, Sendable {
    case none
    case existingFriend = "existing_friend"
    case pendingOutgoing = "pending_outgoing"
    case pendingIncoming = "pending_incoming"
    case selfUser = "self"

    var buttonTitle: String {
        switch self {
        case .none: return "Add"
        case .existingFriend: return "Added"
        case .pendingOutgoing: return "Sent"
        case .pendingIncoming: return "Pending"
        case .selfUser: return "You"
        }
    }

    var isActionable: Bool { self == .none }
}

nonisolated struct FriendSearchResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let username: String
    let email: String?
    let publicUserID: Int?
    let avatarURL: String?
    let relationshipState: FriendRelationshipState
}

nonisolated struct FriendRequest: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let mutualFriends: Int
    let publicUserID: Int?
    let avatarURL: String?

    init(id: UUID = UUID(), name: String, mutualFriends: Int, publicUserID: Int? = nil, avatarURL: String? = nil) {
        self.id = id
        self.name = name
        self.mutualFriends = mutualFriends
        self.publicUserID = publicUserID
        self.avatarURL = avatarURL
    }
}

nonisolated enum ActivityAction: Hashable, Sendable {
    case none
    case quickJoin
    case invite
    case replay
}

nonisolated struct ActivityItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let systemImage: String
    let action: ActivityAction

    init(id: UUID = UUID(), title: String, subtitle: String, systemImage: String, action: ActivityAction = .none) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.action = action
    }
}

nonisolated enum EconomyFeedbackStyle: Hashable, Sendable {
    case success
    case info
    case warning
    case error
}

nonisolated struct EconomyFeedback: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let message: String
    let style: EconomyFeedbackStyle

    init(id: UUID = UUID(), title: String, message: String, style: EconomyFeedbackStyle) {
        self.id = id
        self.title = title
        self.message = message
        self.style = style
    }
}

nonisolated struct GameRound: Identifiable, Hashable, Sendable {
    let id: UUID
    let index: Int
    let prompt: String
    let activePlayerName: String
    let targetAnswer: String?
    let forbiddenWords: [String]
    let targetSeconds: Double?

    init(id: UUID = UUID(), index: Int, prompt: String, activePlayerName: String, targetAnswer: String? = nil, forbiddenWords: [String] = [], targetSeconds: Double? = nil) {
        self.id = id
        self.index = index
        self.prompt = prompt
        self.activePlayerName = activePlayerName
        self.targetAnswer = targetAnswer
        self.forbiddenWords = forbiddenWords
        self.targetSeconds = targetSeconds
    }
}

nonisolated struct RoundLiveState: Hashable, Sendable {
    let guessText: String
    let hasStartedTiming: Bool
    let measuredElapsedTime: Double
    let hasSubmittedTiming: Bool
    let promptVisibleToPerformer: Bool

    init(guessText: String = "", hasStartedTiming: Bool = false, measuredElapsedTime: Double = 0, hasSubmittedTiming: Bool = false, promptVisibleToPerformer: Bool = false) {
        self.guessText = guessText
        self.hasStartedTiming = hasStartedTiming
        self.measuredElapsedTime = measuredElapsedTime
        self.hasSubmittedTiming = hasSubmittedTiming
        self.promptVisibleToPerformer = promptVisibleToPerformer
    }
}

nonisolated struct GameResultRow: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let score: Int
    let rank: Int
    let starsWon: Int

    init(id: UUID = UUID(), name: String, score: Int, rank: Int, starsWon: Int = 0) {
        self.id = id
        self.name = name
        self.score = score
        self.rank = rank
        self.starsWon = starsWon
    }
}

nonisolated struct PassGuessSettings: Hashable, Sendable {
    let rounds: Int
    let questionMode: PassGuessQuestionMode
    let selectedQuestionID: UUID?
    let customQuestion: String
    let answerTimeLimit: Int
    let guessTimeLimit: Int

    static let `default` = PassGuessSettings(rounds: 1, questionMode: .predefined, selectedQuestionID: nil, customQuestion: "", answerTimeLimit: 45, guessTimeLimit: 30)
}

nonisolated enum PassGuessQuestionMode: String, Hashable, Sendable {
    case predefined
    case custom
}

nonisolated enum PassGuessRoundPhase: String, Hashable, Sendable {
    case intro
    case answering
    case guessing
    case reveal
    case leaderboard
}

nonisolated struct PassGuessQuestion: Identifiable, Hashable, Sendable {
    let id: UUID
    let text: String
    let type: PassGuessQuestionMode

    init(id: UUID = UUID(), text: String, type: PassGuessQuestionMode) {
        self.id = id
        self.text = text
        self.type = type
    }
}

nonisolated struct PassGuessAnswer: Identifiable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let text: String

    init(id: UUID = UUID(), playerID: UUID, text: String) {
        self.id = id
        self.playerID = playerID
        self.text = text
    }
}

nonisolated struct PassGuessVote: Identifiable, Hashable, Sendable {
    let id: UUID
    let answerID: UUID
    let voterID: UUID
    let guessedPlayerID: UUID

    init(id: UUID = UUID(), answerID: UUID, voterID: UUID, guessedPlayerID: UUID) {
        self.id = id
        self.answerID = answerID
        self.voterID = voterID
        self.guessedPlayerID = guessedPlayerID
    }
}

nonisolated struct PassGuessRevealItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let answerID: UUID
    let answerText: String
    let playerID: UUID
    let playerName: String
    let correctGuessCount: Int

    init(id: UUID = UUID(), answerID: UUID, answerText: String, playerID: UUID, playerName: String, correctGuessCount: Int) {
        self.id = id
        self.answerID = answerID
        self.answerText = answerText
        self.playerID = playerID
        self.playerName = playerName
        self.correctGuessCount = correctGuessCount
    }
}

nonisolated struct PassGuessArchivedRound: Identifiable, Hashable, Sendable {
    let id: UUID
    let roundNumber: Int
    let question: PassGuessQuestion
    let answers: [PassGuessAnswer]
    let votes: [PassGuessVote]
    let revealItems: [PassGuessRevealItem]

    init(id: UUID = UUID(), roundNumber: Int, question: PassGuessQuestion, answers: [PassGuessAnswer], votes: [PassGuessVote], revealItems: [PassGuessRevealItem]) {
        self.id = id
        self.roundNumber = roundNumber
        self.question = question
        self.answers = answers
        self.votes = votes
        self.revealItems = revealItems
    }
}

nonisolated struct PassGuessRoundState: Hashable, Sendable {
    let settings: PassGuessSettings
    let phase: PassGuessRoundPhase
    let question: PassGuessQuestion
    let answers: [PassGuessAnswer]
    let votes: [PassGuessVote]
    let revealItems: [PassGuessRevealItem]
    let archivedRounds: [PassGuessArchivedRound]

    init(
        settings: PassGuessSettings,
        phase: PassGuessRoundPhase,
        question: PassGuessQuestion,
        answers: [PassGuessAnswer] = [],
        votes: [PassGuessVote] = [],
        revealItems: [PassGuessRevealItem] = [],
        archivedRounds: [PassGuessArchivedRound] = []
    ) {
        self.settings = settings
        self.phase = phase
        self.question = question
        self.answers = answers
        self.votes = votes
        self.revealItems = revealItems
        self.archivedRounds = archivedRounds
    }
}

nonisolated enum MatchPhase: Hashable, Sendable {
    case intro
    case passToNextPlayer
    case liveRound
    case roundResult
    case finished

    var realtimeValue: String {
        switch self {
        case .intro: return "intro"
        case .passToNextPlayer: return "pass_to_next_player"
        case .liveRound: return "live_round"
        case .roundResult: return "round_result"
        case .finished: return "finished"
        }
    }

    init?(realtimeValue: String) {
        switch realtimeValue {
        case "intro": self = .intro
        case "pass_to_next_player": self = .passToNextPlayer
        case "live_round": self = .liveRound
        case "round_result": self = .roundResult
        case "finished": self = .finished
        default: return nil
        }
    }
}

nonisolated struct GTSTurnResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let round: Int
    let targetTime: Double
    let actualTime: Double
    let difference: Double

    init(id: UUID = UUID(), playerID: UUID, playerName: String, round: Int, targetTime: Double, actualTime: Double, difference: Double) {
        self.id = id
        self.playerID = playerID
        self.playerName = playerName
        self.round = round
        self.targetTime = targetTime
        self.actualTime = actualTime
        self.difference = difference
    }
}

nonisolated struct GuessTheSecondsGameState: Hashable, Sendable {
    let activeTurnIndex: Int
    let roundTargets: [Int: Double]
    let turnResults: [GTSTurnResult]
    let selectedTime: Double
    let roundsPerPlayer: Int
    let totalTurns: Int

    init(activeTurnIndex: Int = 0, roundTargets: [Int: Double] = [:], turnResults: [GTSTurnResult] = [], selectedTime: Double = 15, roundsPerPlayer: Int = 3, totalTurns: Int = 6) {
        self.activeTurnIndex = activeTurnIndex
        self.roundTargets = roundTargets
        self.turnResults = turnResults
        self.selectedTime = selectedTime
        self.roundsPerPlayer = roundsPerPlayer
        self.totalTurns = totalTurns
    }

    var isFinished: Bool { activeTurnIndex >= totalTurns }

    func currentRoundNumber(playerCount: Int) -> Int {
        guard playerCount > 0 else { return 1 }
        return (activeTurnIndex / playerCount) + 1
    }

    func isFirstPlayerOfRound(playerCount: Int) -> Bool {
        guard playerCount > 0 else { return true }
        return activeTurnIndex % playerCount == 0
    }
}

nonisolated struct MGPlayerResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let elapsedSeconds: Double
    let moveCount: Int

    init(id: UUID = UUID(), playerID: UUID, playerName: String, elapsedSeconds: Double, moveCount: Int) {
        self.id = id
        self.playerID = playerID
        self.playerName = playerName
        self.elapsedSeconds = elapsedSeconds
        self.moveCount = moveCount
    }
}

nonisolated struct MGSpectatorTile: Hashable, Sendable {
    let pairId: Int
    let symbol: String
    let colorIndex: Int
    let isFlipped: Bool
    let isMatched: Bool

    init(pairId: Int, symbol: String, colorIndex: Int, isFlipped: Bool, isMatched: Bool) {
        self.pairId = pairId
        self.symbol = symbol
        self.colorIndex = colorIndex
        self.isFlipped = isFlipped
        self.isMatched = isMatched
    }
}

nonisolated struct MGSpectatorSnapshot: Hashable, Sendable {
    let playerID: UUID
    let playerName: String
    let tiles: [MGSpectatorTile]
    let matchedPairs: Int
    let moveCount: Int
    let elapsedSeconds: Double

    init(playerID: UUID, playerName: String, tiles: [MGSpectatorTile], matchedPairs: Int, moveCount: Int, elapsedSeconds: Double) {
        self.playerID = playerID
        self.playerName = playerName
        self.tiles = tiles
        self.matchedPairs = matchedPairs
        self.moveCount = moveCount
        self.elapsedSeconds = elapsedSeconds
    }
}

nonisolated struct MemoryGridGameState: Hashable, Sendable {
    let gridSize: String
    let currentPlayerIndex: Int
    let playerResults: [MGPlayerResult]
    let isFinished: Bool
    let spectator: MGSpectatorSnapshot?

    init(gridSize: String = "small4x4", currentPlayerIndex: Int = 0, playerResults: [MGPlayerResult] = [], isFinished: Bool = false, spectator: MGSpectatorSnapshot? = nil) {
        self.gridSize = gridSize
        self.currentPlayerIndex = currentPlayerIndex
        self.playerResults = playerResults
        self.isFinished = isFinished
        self.spectator = spectator
    }

    var resolvedGridSize: MemoryGridSize {
        MemoryGridSize(rawValue: gridSize) ?? .small4x4
    }
}

nonisolated struct MPPlayerResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let progress: Int
    let attempts: Int
    let completionTime: Double?
    let isFinished: Bool
    let score: Int

    init(id: UUID = UUID(), playerID: UUID, playerName: String, progress: Int, attempts: Int, completionTime: Double?, isFinished: Bool, score: Int) {
        self.id = id
        self.playerID = playerID
        self.playerName = playerName
        self.progress = progress
        self.attempts = attempts
        self.completionTime = completionTime
        self.isFinished = isFinished
        self.score = score
    }
}

nonisolated struct MemoryPathGameState: Hashable, Sendable {
    let difficulty: String
    let gameMode: String
    let targetSteps: Int
    let pathIndices: [Int]
    let gridSize: Int
    let currentPlayerIndex: Int
    let playerResults: [MPPlayerResult]
    let isFinished: Bool

    init(difficulty: String = "medium", gameMode: String = "timeRace", targetSteps: Int = 6, pathIndices: [Int] = [], gridSize: Int = 6, currentPlayerIndex: Int = 0, playerResults: [MPPlayerResult] = [], isFinished: Bool = false) {
        self.difficulty = difficulty
        self.gameMode = gameMode
        self.targetSteps = targetSteps
        self.pathIndices = pathIndices
        self.gridSize = gridSize
        self.currentPlayerIndex = currentPlayerIndex
        self.playerResults = playerResults
        self.isFinished = isFinished
    }
}

nonisolated struct GameSession: Identifiable, Hashable, Sendable {
    let id: UUID
    let game: GameType
    let mode: GameMode
    let roomCode: String?
    let players: [PlayerProfile]
    let rounds: [GameRound]
    let currentRoundIndex: Int
    let phase: MatchPhase
    let secondsRemaining: Int
    let latestAwardedPoints: Int
    let latestFeedback: String
    let results: [GameResultRow]
    let liveState: RoundLiveState
    let passGuessState: PassGuessRoundState?
    let guessTheSecondsState: GuessTheSecondsGameState?
    let memoryGridState: MemoryGridGameState?
    let memoryPathState: MemoryPathGameState?
    let tapInOrderState: TapInOrderGameState?
    let colorTrapState: ColorTrapGameState?
    let rematchPlayerIDs: [UUID]
    let stateVersion: Int

    init(
        id: UUID = UUID(),
        game: GameType,
        mode: GameMode,
        roomCode: String?,
        players: [PlayerProfile],
        rounds: [GameRound],
        currentRoundIndex: Int,
        phase: MatchPhase,
        secondsRemaining: Int,
        latestAwardedPoints: Int,
        latestFeedback: String,
        results: [GameResultRow],
        liveState: RoundLiveState = RoundLiveState(),
        passGuessState: PassGuessRoundState? = nil,
        guessTheSecondsState: GuessTheSecondsGameState? = nil,
        memoryGridState: MemoryGridGameState? = nil,
        memoryPathState: MemoryPathGameState? = nil,
        tapInOrderState: TapInOrderGameState? = nil,
        colorTrapState: ColorTrapGameState? = nil,
        rematchPlayerIDs: [UUID] = [],
        stateVersion: Int = 0
    ) {
        self.id = id
        self.game = game
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
}

nonisolated enum HomeRoute: Hashable, Sendable {
    case game(GameType)
    case imposterStyleSelection
    case imposterGame(GameType, ImposterGameStyle)
    case lobby(GameRoom)
}

nonisolated enum ImposterGameStyle: String, CaseIterable, Identifiable, Hashable, Sendable {
    case discussion
    case clue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discussion: return "Discussion Mode"
        case .clue: return "Clue Mode"
        }
    }

    var subtitle: String {
        switch self {
        case .discussion: return "Talk together and find the Imposter"
        case .clue: return "Give clues one by one"
        }
    }

    var details: [String] {
        switch self {
        case .discussion: return ["Free discussion", "Timed conversation", "Then voting"]
        case .clue: return ["Turn-based clues", "No discussion", "Then voting"]
        }
    }

    var icon: String {
        switch self {
        case .discussion: return "bubble.left.and.bubble.right.fill"
        case .clue: return "magnifyingglass.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .discussion: return .orange
        case .clue: return .purple
        }
    }
}

nonisolated enum ImposterCategoryPack: String, CaseIterable, Identifiable, Hashable, Sendable {
    case animals
    case food
    case places
    case jobs
    case movies
    case random

    var id: String { rawValue }

    var title: String {
        switch self {
        case .animals: return "Animals"
        case .food: return "Food & Drinks"
        case .places: return "Places"
        case .jobs: return "Jobs"
        case .movies: return "Movies"
        case .random: return "Random"
        }
    }

    var words: [String] {
        switch self {
        case .animals: return ["Lion", "Eagle", "Dolphin", "Elephant", "Penguin", "Tiger", "Shark", "Owl", "Wolf", "Panda", "Giraffe", "Crocodile"]
        case .food: return ["Pizza", "Sushi", "Burger", "Pasta", "Taco", "Ice Cream", "Steak", "Chocolate", "Pancake", "Salad", "Soup", "Sandwich"]
        case .places: return ["Paris", "Tokyo", "New York", "Beach", "Mountain", "Desert", "Library", "Hospital", "Airport", "Museum", "Stadium", "Castle"]
        case .jobs: return ["Doctor", "Pilot", "Chef", "Teacher", "Firefighter", "Astronaut", "Detective", "Artist", "Engineer", "Nurse", "Lawyer", "Farmer"]
        case .movies: return ["Titanic", "Avatar", "Batman", "Frozen", "Inception", "Jaws", "Matrix", "Shrek", "Gladiator", "Alien", "Rocky", "Joker"]
        case .random: return ["Rainbow", "Guitar", "Volcano", "Diamond", "Tornado", "Rocket", "Camera", "Mirror", "Compass", "Candle", "Treasure", "Shadow"]
        }
    }
}

nonisolated struct ImposterSettings: Hashable, Sendable {
    let gameStyle: ImposterGameStyle
    let rounds: Int
    let discussionDuration: Int
    let categoryPack: ImposterCategoryPack

    static let `default` = ImposterSettings(gameStyle: .discussion, rounds: 3, discussionDuration: 60, categoryPack: .random)
}

nonisolated enum ImposterPhase: String, Hashable, Sendable {
    case roleReveal
    case ready
    case discussion
    case clueGiving
    case voting
    case result
}

nonisolated struct ImposterRoundState: Hashable, Sendable {
    let settings: ImposterSettings
    let phase: ImposterPhase
    let secretWord: String
    let imposterPlayerID: UUID
    let revealedPlayerIDs: Set<UUID>
    let readyPlayerIDs: Set<UUID>
    let currentCluePlayerIndex: Int
    let clues: [ImposterClue]
    let votes: [ImposterVote]
    let discussionTimeRemaining: Int

    init(
        settings: ImposterSettings,
        phase: ImposterPhase,
        secretWord: String,
        imposterPlayerID: UUID,
        revealedPlayerIDs: Set<UUID> = [],
        readyPlayerIDs: Set<UUID> = [],
        currentCluePlayerIndex: Int = 0,
        clues: [ImposterClue] = [],
        votes: [ImposterVote] = [],
        discussionTimeRemaining: Int = 0
    ) {
        self.settings = settings
        self.phase = phase
        self.secretWord = secretWord
        self.imposterPlayerID = imposterPlayerID
        self.revealedPlayerIDs = revealedPlayerIDs
        self.readyPlayerIDs = readyPlayerIDs
        self.currentCluePlayerIndex = currentCluePlayerIndex
        self.clues = clues
        self.votes = votes
        self.discussionTimeRemaining = discussionTimeRemaining
    }
}

nonisolated enum MemoryGridSize: String, CaseIterable, Identifiable, Hashable, Sendable {
    case tiny3x4
    case small4x4
    case medium4x5
    case large5x6
    case xl6x6

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiny3x4: return "3×4"
        case .small4x4: return "4×4"
        case .medium4x5: return "4×5"
        case .large5x6: return "5×6"
        case .xl6x6: return "6×6"
        }
    }

    var subtitle: String {
        switch self {
        case .tiny3x4: return "6 pairs"
        case .small4x4: return "8 pairs"
        case .medium4x5: return "10 pairs"
        case .large5x6: return "15 pairs"
        case .xl6x6: return "18 pairs"
        }
    }

    var rows: Int {
        switch self {
        case .tiny3x4: return 4
        case .small4x4: return 4
        case .medium4x5: return 5
        case .large5x6: return 6
        case .xl6x6: return 6
        }
    }

    var cols: Int {
        switch self {
        case .tiny3x4: return 3
        case .small4x4: return 4
        case .medium4x5: return 4
        case .large5x6: return 5
        case .xl6x6: return 6
        }
    }

    var pairCount: Int { (rows * cols) / 2 }
    var tileCount: Int { rows * cols }
}

nonisolated struct MemoryGridSettings: Hashable, Sendable {
    let gridSize: MemoryGridSize

    static let `default` = MemoryGridSettings(gridSize: .small4x4)
    static let teamDefault = MemoryGridSettings(gridSize: .large5x6)
}

nonisolated struct MemoryTile: Identifiable, Hashable, Sendable {
    let id: UUID
    let pairId: Int
    let symbol: String
    let colorIndex: Int
    var isFlipped: Bool
    var isMatched: Bool

    init(id: UUID = UUID(), pairId: Int, symbol: String, colorIndex: Int = 0, isFlipped: Bool = false, isMatched: Bool = false) {
        self.id = id
        self.pairId = pairId
        self.symbol = symbol
        self.colorIndex = colorIndex
        self.isFlipped = isFlipped
        self.isMatched = isMatched
    }
}

nonisolated struct ImposterClue: Identifiable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let clueText: String

    init(id: UUID = UUID(), playerID: UUID, clueText: String) {
        self.id = id
        self.playerID = playerID
        self.clueText = clueText
    }
}

nonisolated struct ImposterVote: Identifiable, Hashable, Sendable {
    let id: UUID
    let voterID: UUID
    let suspectID: UUID

    init(id: UUID = UUID(), voterID: UUID, suspectID: UUID) {
        self.id = id
        self.voterID = voterID
        self.suspectID = suspectID
    }
}

nonisolated enum LobbyRoute: Hashable, Sendable {
    case online(GameType)
    case room(GameRoom)
}

nonisolated struct TeamAssignment: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let playerIDs: [UUID]

    init(id: String, name: String, playerIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.playerIDs = playerIDs
    }

    var isEmpty: Bool { playerIDs.isEmpty }
    var count: Int { playerIDs.count }

    func contains(_ playerID: UUID) -> Bool {
        playerIDs.contains(playerID)
    }

    func adding(_ playerID: UUID) -> TeamAssignment {
        guard !playerIDs.contains(playerID) else { return self }
        return TeamAssignment(id: id, name: name, playerIDs: playerIDs + [playerID])
    }

    func removing(_ playerID: UUID) -> TeamAssignment {
        TeamAssignment(id: id, name: name, playerIDs: playerIDs.filter { $0 != playerID })
    }
}

nonisolated struct TeamState: Hashable, Codable, Sendable {
    let teams: [TeamAssignment]

    init(teams: [TeamAssignment] = [TeamAssignment(id: "team_a", name: "Team A"), TeamAssignment(id: "team_b", name: "Team B")]) {
        self.teams = teams
    }

    static let `default` = TeamState()

    var teamA: TeamAssignment { teams.first { $0.id == "team_a" } ?? TeamAssignment(id: "team_a", name: "Team A") }
    var teamB: TeamAssignment { teams.first { $0.id == "team_b" } ?? TeamAssignment(id: "team_b", name: "Team B") }

    var allAssignedPlayerIDs: Set<UUID> {
        Set(teams.flatMap { $0.playerIDs })
    }

    var isValid: Bool {
        teamA.count >= 1 && teamB.count >= 1
    }

    func teamFor(playerID: UUID) -> TeamAssignment? {
        teams.first { $0.contains(playerID) }
    }

    func teammates(of playerID: UUID) -> [UUID] {
        guard let team = teamFor(playerID: playerID) else { return [] }
        return team.playerIDs.filter { $0 != playerID }
    }

    func opponents(of playerID: UUID) -> [UUID] {
        guard let myTeam = teamFor(playerID: playerID) else { return [] }
        return teams.filter { $0.id != myTeam.id }.flatMap { $0.playerIDs }
    }

    func assigning(_ playerID: UUID, to teamID: String) -> TeamState {
        var updated = teams.map { $0.removing(playerID) }
        if let idx = updated.firstIndex(where: { $0.id == teamID }) {
            updated[idx] = updated[idx].adding(playerID)
        }
        return TeamState(teams: updated)
    }

    func unassigning(_ playerID: UUID) -> TeamState {
        TeamState(teams: teams.map { $0.removing(playerID) })
    }

    func randomized(playerIDs: [UUID]) -> TeamState {
        var shuffled = playerIDs.shuffled()
        let halfCount = shuffled.count / 2
        let aIDs = Array(shuffled.prefix(halfCount))
        let bIDs = Array(shuffled.suffix(from: halfCount))
        return TeamState(teams: [
            TeamAssignment(id: "team_a", name: "Team A", playerIDs: aIDs),
            TeamAssignment(id: "team_b", name: "Team B", playerIDs: bIDs)
        ])
    }
}
