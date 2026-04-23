import Foundation

protocol GameEngineProtocol: AnyObject, Sendable {
    var gameKey: String { get }
    var gameName: String { get }

    func buildRounds(players: [PlayerProfile], settings: GameSettings) -> [GameRound]
    func calculateScore(for round: GameRound, playerAction: PlayerAction) -> RoundScore
    func determineWinCondition(players: [PlayerProfile], rounds: [GameRound]) -> [GameResultRow]
    func roundDuration(for settings: GameSettings) -> Int
}

nonisolated struct GameSettings: Hashable, Sendable {
    let roundCount: Int
    let timePerRound: Int
    let customOptions: [String: String]

    init(roundCount: Int = 3, timePerRound: Int = 60, customOptions: [String: String] = [:]) {
        self.roundCount = roundCount
        self.timePerRound = timePerRound
        self.customOptions = customOptions
    }

    static let `default` = GameSettings()
}

nonisolated struct PlayerAction: Hashable, Sendable {
    let playerID: UUID
    let actionType: String
    let value: String
    let timestamp: Date

    init(playerID: UUID, actionType: String, value: String, timestamp: Date = Date()) {
        self.playerID = playerID
        self.actionType = actionType
        self.value = value
        self.timestamp = timestamp
    }
}

nonisolated struct RoundScore: Hashable, Sendable {
    let playerID: UUID
    let points: Int
    let feedback: String
    let isCorrect: Bool

    init(playerID: UUID, points: Int, feedback: String, isCorrect: Bool = false) {
        self.playerID = playerID
        self.points = points
        self.feedback = feedback
        self.isCorrect = isCorrect
    }
}

@MainActor
protocol RoundManagerProtocol: AnyObject {
    var currentRoundIndex: Int { get }
    var totalRounds: Int { get }
    var isLastRound: Bool { get }
    func advanceToNextRound()
    func resetRounds()
}

@MainActor
protocol TurnManagerProtocol: AnyObject {
    var currentPlayerIndex: Int { get }
    var currentPlayer: PlayerProfile? { get }
    func advanceToNextTurn()
    func resetTurns()
}

@MainActor
protocol ScoreManagerProtocol: AnyObject {
    var scores: [UUID: Int] { get }
    func addScore(_ points: Int, for playerID: UUID)
    func resetScores()
    func sortedResults() -> [(playerID: UUID, score: Int)]
}

@MainActor
protocol ResultBuilderProtocol: AnyObject {
    func buildResults(players: [PlayerProfile], scores: [UUID: Int], mode: GameMode) -> [GameResultRow]
}

@Observable
@MainActor
final class SharedRoundManager: RoundManagerProtocol {
    var currentRoundIndex: Int = 0
    let totalRounds: Int

    var isLastRound: Bool { currentRoundIndex >= totalRounds - 1 }

    init(totalRounds: Int) {
        self.totalRounds = totalRounds
    }

    func advanceToNextRound() {
        guard !isLastRound else { return }
        currentRoundIndex += 1
    }

    func resetRounds() {
        currentRoundIndex = 0
    }
}

@Observable
@MainActor
final class SharedTurnManager: TurnManagerProtocol {
    var currentPlayerIndex: Int = 0
    private let players: [PlayerProfile]

    var currentPlayer: PlayerProfile? {
        guard currentPlayerIndex < players.count else { return nil }
        return players[currentPlayerIndex]
    }

    init(players: [PlayerProfile]) {
        self.players = players
    }

    func advanceToNextTurn() {
        currentPlayerIndex = (currentPlayerIndex + 1) % max(players.count, 1)
    }

    func resetTurns() {
        currentPlayerIndex = 0
    }
}

@Observable
@MainActor
final class SharedScoreManager: ScoreManagerProtocol {
    var scores: [UUID: Int] = [:]

    func addScore(_ points: Int, for playerID: UUID) {
        scores[playerID, default: 0] += points
    }

    func resetScores() {
        scores = [:]
    }

    func sortedResults() -> [(playerID: UUID, score: Int)] {
        scores.sorted { $0.value > $1.value }.map { (playerID: $0.key, score: $0.value) }
    }
}

@MainActor
final class SharedResultBuilder: ResultBuilderProtocol {
    func buildResults(players: [PlayerProfile], scores: [UUID: Int], mode: GameMode) -> [GameResultRow] {
        let sorted = players.sorted { lhs, rhs in
            let lhsScore = scores[lhs.id] ?? 0
            let rhsScore = scores[rhs.id] ?? 0
            return lhsScore > rhsScore
        }

        let policy = RewardPolicy.defaultPolicy

        return sorted.enumerated().map { index, player in
            let rank = index + 1
            let score = scores[player.id] ?? 0
            let isWin = rank == 1
            let xpWon = isWin ? policy.xpForWin : policy.xpForParticipation

            let starsWon = isWin ? policy.starsForWin : policy.starsForParticipation

            return GameResultRow(
                name: player.username,
                score: score,
                rank: rank,
                starsWon: starsWon,
                xpWon: xpWon
            )
        }
    }
}

nonisolated enum GameEngineRegistry {
    private static let engines: [String: any GameEngineProtocol] = [:]

    static func engine(for gameKey: String) -> (any GameEngineProtocol)? {
        engines[gameKey]
    }

    static func register(_ engine: any GameEngineProtocol) {
        // Future: dynamic registration
    }
}
