import Foundation
import Observation

nonisolated struct TenTangleScenario: Sendable {
    let text: String
}

nonisolated enum TenTanglePhase: Hashable, Sendable {
    case setup
    case guesserAnnounce
    case passToPlayer(Int)
    case showNumber(Int)
    case scenarioReveal
    case acting
    case guesserGuessing
    case roundReveal
    case scoreboard
    case finalResults
}

nonisolated struct TenTanglePlayerGuess: Identifiable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let actualNumber: Int
    var guessedNumber: Int?

    init(playerID: UUID, playerName: String, actualNumber: Int, guessedNumber: Int? = nil) {
        self.id = playerID
        self.playerID = playerID
        self.playerName = playerName
        self.actualNumber = actualNumber
        self.guessedNumber = guessedNumber
    }
}

@Observable
@MainActor
final class TenTangleViewModel {
    var players: [PlayerProfile]
    var phase: TenTanglePhase = .guesserAnnounce
    var currentGuesserIndex: Int = 0
    var currentRound: Int = 1
    var assignedNumbers: [UUID: Int] = [:]
    var guesses: [TenTanglePlayerGuess] = []
    var scores: [UUID: Int] = [:]
    var currentScenario: TenTangleScenario = TenTangleScenario(text: "")
    var passPlayerIndex: Int = 0
    private var usedScenarioIndices: Set<Int> = []

    var totalRounds: Int { players.count }

    var currentGuesser: PlayerProfile {
        players[currentGuesserIndex]
    }

    var nonGuesserPlayers: [PlayerProfile] {
        players.enumerated().compactMap { index, player in
            index == currentGuesserIndex ? nil : player
        }
    }

    var maxNumber: Int {
        nonGuesserPlayers.count
    }

    private let scenarios: [TenTangleScenario] = [
        TenTangleScenario(text: "You just found out your flight is cancelled"),
        TenTangleScenario(text: "Your crush texts you back after 3 months"),
        TenTangleScenario(text: "You meet your ex at a party"),
        TenTangleScenario(text: "You win a free trip but it's tomorrow"),
        TenTangleScenario(text: "Your boss calls you at 2 AM"),
        TenTangleScenario(text: "You get unlimited free food forever"),
        TenTangleScenario(text: "Your phone dies during an important call"),
        TenTangleScenario(text: "A stranger compliments your outfit in public"),
        TenTangleScenario(text: "You realize you left the oven on at home"),
        TenTangleScenario(text: "You find $100 in your old jacket pocket"),
        TenTangleScenario(text: "Your best friend spoils the movie ending"),
        TenTangleScenario(text: "You accidentally send a text to the wrong person"),
        TenTangleScenario(text: "You get promoted but have to move cities"),
        TenTangleScenario(text: "A celebrity follows you on social media"),
        TenTangleScenario(text: "You're stuck in an elevator with your neighbor"),
        TenTangleScenario(text: "You find out your food order was completely wrong"),
        TenTangleScenario(text: "A bird lands on your shoulder in public"),
        TenTangleScenario(text: "You win the lottery but lose the ticket"),
        TenTangleScenario(text: "Your alarm didn't go off on exam day"),
        TenTangleScenario(text: "You discover your pet learned a new trick"),
        TenTangleScenario(text: "Rain starts pouring on your outdoor wedding"),
        TenTangleScenario(text: "You find a secret room in your house"),
        TenTangleScenario(text: "Your favorite song plays at the grocery store"),
        TenTangleScenario(text: "You accidentally call your teacher 'Mom'"),
        TenTangleScenario(text: "You get free VIP tickets to a sold-out concert"),
        TenTangleScenario(text: "Your WiFi goes out during a live presentation"),
        TenTangleScenario(text: "A dog runs up and steals your sandwich"),
        TenTangleScenario(text: "You open a fortune cookie and it's blank"),
        TenTangleScenario(text: "Your childhood hero DMs you on Instagram"),
        TenTangleScenario(text: "You realize you've been wearing your shirt inside out all day")
    ]

    init(players: [PlayerProfile]) {
        self.players = players
        for player in players {
            scores[player.id] = 0
        }
    }

    func startGame() {
        currentGuesserIndex = 0
        currentRound = 1
        scores = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })
        startRound()
    }

    func startRound() {
        assignNumbers()
        pickScenario()
        phase = .guesserAnnounce
    }

    func proceedToNumberAssignment() {
        passPlayerIndex = 0
        let nonGuessers = nonGuesserPlayers
        if nonGuessers.isEmpty { return }
        phase = .passToPlayer(0)
    }

    func showPlayerNumber() {
        phase = .showNumber(passPlayerIndex)
    }

    func playerGotIt() {
        passPlayerIndex += 1
        let nonGuessers = nonGuesserPlayers
        if passPlayerIndex >= nonGuessers.count {
            phase = .scenarioReveal
        } else {
            phase = .passToPlayer(passPlayerIndex)
        }
    }

    func startActing() {
        phase = .acting
    }

    func startGuessing() {
        guesses = nonGuesserPlayers.map { player in
            TenTanglePlayerGuess(
                playerID: player.id,
                playerName: player.username,
                actualNumber: assignedNumbers[player.id] ?? 5
            )
        }
        phase = .guesserGuessing
    }

    func updateGuess(for playerID: UUID, number: Int) {
        if let index = guesses.firstIndex(where: { $0.playerID == playerID }) {
            guesses[index] = TenTanglePlayerGuess(
                playerID: guesses[index].playerID,
                playerName: guesses[index].playerName,
                actualNumber: guesses[index].actualNumber,
                guessedNumber: number
            )
        }
    }

    var allGuessesSubmitted: Bool {
        guesses.allSatisfy { $0.guessedNumber != nil }
    }

    func submitGuesses() {
        guard allGuessesSubmitted else { return }
        var roundPoints = 0
        for guess in guesses {
            if guess.guessedNumber == guess.actualNumber {
                roundPoints += 1
            }
        }
        scores[currentGuesser.id, default: 0] += roundPoints
        FeedbackService.shared.playSuccess()
        phase = .roundReveal
    }

    func showScoreboard() {
        phase = .scoreboard
    }

    func nextRound() {
        currentGuesserIndex += 1
        currentRound += 1
        if currentGuesserIndex >= players.count {
            phase = .finalResults
        } else {
            startRound()
        }
    }

    var sortedScores: [(player: PlayerProfile, score: Int)] {
        players.map { player in
            (player: player, score: scores[player.id] ?? 0)
        }
        .sorted { $0.score > $1.score }
    }

    var winner: PlayerProfile? {
        sortedScores.first?.player
    }

    private func assignNumbers() {
        assignedNumbers = [:]
        let count = nonGuesserPlayers.count
        guard count > 0 else { return }
        var numbers = Array(1...count).shuffled()
        for player in nonGuesserPlayers {
            assignedNumbers[player.id] = numbers.removeFirst()
        }
    }

    private func pickScenario() {
        if usedScenarioIndices.count >= scenarios.count {
            usedScenarioIndices.removeAll()
        }
        var index: Int
        repeat {
            index = Int.random(in: 0..<scenarios.count)
        } while usedScenarioIndices.contains(index)
        usedScenarioIndices.insert(index)
        currentScenario = scenarios[index]
    }
}
