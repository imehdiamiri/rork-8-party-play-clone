import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class MemoryPathViewModel {
    var settings: MemoryPathSettings = .default
    var phase: MemoryPathPhase = .setup
    var tiles: [[MemoryPathTile]] = []
    var pathTiles: [(row: Int, col: Int)] = []
    var players: [MemoryPathPlayerState] = []
    var teams: [MemoryPathTeam] = []
    var currentPlayerIndex: Int = 0
    var currentTeamIndex: Int = 0
    var elapsedTime: TimeInterval = 0
    var hintCountdown: Int = 0
    var rankings: [MemoryPathRanking] = []
    var wrongTileID: UUID?
    var showConfetti: Bool = false
    var turnSwitchMessage: String = ""
    var passDevicePlayerName: String = ""
    var turnAttempts: Int = 0
    var wrongFeedbackToken: Int = 0
    var correctFeedbackToken: Int = 0

    private var timerTask: Task<Void, Never>?
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0

    var gridSize: Int { settings.difficulty.gridSize }

    var currentPlayer: MemoryPathPlayerState? {
        guard players.indices.contains(currentPlayerIndex) else { return nil }
        return players[currentPlayerIndex]
    }

    var currentTeam: MemoryPathTeam? {
        guard teams.indices.contains(currentTeamIndex) else { return nil }
        return teams[currentTeamIndex]
    }

    var currentProgress: Int {
        if settings.playType == .team {
            return currentTeam?.progress ?? 0
        }
        return currentPlayer?.progress ?? 0
    }

    var pathLength: Int { pathTiles.count }

    var stepsToFind: Int { max(0, pathTiles.count - 2) }

    var stepsFound: Int { max(0, currentProgress - 1) }

    var currentHintUsed: Bool {
        if settings.playType == .team {
            return currentTeam?.hintUsed ?? false
        }
        return currentPlayer?.hintUsed ?? false
    }

    var hintEligible: Bool {
        settings.playType == .team && gridSize >= 7 && stepsToFind >= 15
    }

    var hintUnlocked: Bool {
        guard hintEligible else { return false }
        let total = pathTiles.count
        guard total > 2 else { return false }
        let stepsTotal = total - 2
        let stepsDone = max(0, currentProgress - 1)
        return Double(stepsDone) >= Double(stepsTotal) * 0.5
    }

    var allPlayersFinished: Bool {
        if settings.playType == .team {
            return teams.allSatisfy(\.isFinished)
        }
        return players.allSatisfy(\.isFinished)
    }

    var activeName: String {
        if settings.playType == .team {
            if let team = currentTeam, let memberID = team.currentMemberID,
               let player = players.first(where: { $0.id == memberID }) {
                return "\(team.name) — \(player.name)"
            }
            return currentTeam?.name ?? ""
        }
        return currentPlayer?.name ?? ""
    }

    func configure(settings: MemoryPathSettings, playerNames: [String], teamAssignments: TeamState? = nil) {
        self.settings = settings
        currentPlayerIndex = 0
        currentTeamIndex = 0
        elapsedTime = 0
        hintCountdown = 0
        rankings = []
        wrongTileID = nil
        showConfetti = false
        turnSwitchMessage = ""
        passDevicePlayerName = ""
        turnAttempts = 0
        wrongFeedbackToken = 0
        correctFeedbackToken = 0
        accumulatedTime = 0
        startTime = nil
        timerTask?.cancel()
        teams = []
        players = playerNames.map { name in
            MemoryPathPlayerState(name: name, progress: 1)
        }

        if settings.playType == .team, let teamAssignments {
            let teamA = teamAssignments.teamA
            let teamB = teamAssignments.teamB
            let teamAMembers = teamA.playerIDs.compactMap { pid in players.firstIndex(where: { $0.id == pid }).map { players[$0].id } }
            let teamBMembers = teamB.playerIDs.compactMap { pid in players.firstIndex(where: { $0.id == pid }).map { players[$0].id } }

            teams = [
                MemoryPathTeam(id: "team_a", name: "Team A", memberIDs: teamAMembers.isEmpty ? Array(players.prefix(players.count / 2).map(\.id)) : teamAMembers, progress: 1),
                MemoryPathTeam(id: "team_b", name: "Team B", memberIDs: teamBMembers.isEmpty ? Array(players.suffix(from: players.count / 2).map(\.id)) : teamBMembers, progress: 1)
            ]

            for index in players.indices {
                if teams[0].memberIDs.contains(players[index].id) {
                    players[index].teamID = "team_a"
                } else {
                    players[index].teamID = "team_b"
                }
            }
        }

        generateBoard()
    }

    func startGame() {
        phase = .countdown
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard phase == .countdown else { return }
            beginPlay()
        }
    }

    func tapTile(row: Int, col: Int) {
        guard phase == .playing else { return }
        guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }

        let progress = currentProgress
        guard progress < pathTiles.count else { return }

        let expectedTile = pathTiles[progress]
        if row == expectedTile.row && col == expectedTile.col {
            handleCorrectTap(row: row, col: col)
        } else {
            handleWrongTap(row: row, col: col)
        }
    }

    func useHint() {
        guard phase == .playing, !currentHintUsed, hintEligible, hintUnlocked else { return }

        if settings.playType == .team {
            guard teams.indices.contains(currentTeamIndex) else { return }
            teams[currentTeamIndex].hintUsed = true
        } else {
            guard players.indices.contains(currentPlayerIndex) else { return }
            players[currentPlayerIndex].hintUsed = true
        }

        phase = .hintActive
        hintCountdown = 2

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if tiles[row][col].isPath {
                    if tiles[row][col].isStart {
                        tiles[row][col].state = .start
                    } else if tiles[row][col].isEnd {
                        tiles[row][col].state = .end
                    } else {
                        tiles[row][col].state = .hintRevealed
                    }
                }
            }
        }

        FeedbackService.shared.playRoundStart()

        Task {
            for value in stride(from: 2, through: 1, by: -1) {
                hintCountdown = value
                try? await Task.sleep(for: .seconds(1))
            }
            hintCountdown = 0
            hidePathExceptProgress()
            phase = .playing
        }
    }

    func advanceFromPassDevice() {
        resetBoardForCurrentPlayer()
        phase = .playing
        startTimer()
    }

    func advanceFromTurnSwitch() {
        resetBoardForCurrentPlayer()
        phase = .playing
        startTimer()
    }

    private func generateBoard() {
        let size = gridSize
        let result = MemoryPathGenerator.generate(rows: size, cols: size)

        let generatedPath: [(row: Int, col: Int)] = result.pathTiles.map { index in
            (row: index / size, col: index % size)
        }

        var pathSet = Set<Int>()
        for idx in result.pathTiles { pathSet.insert(idx) }

        pathTiles = generatedPath
        tiles = (0..<size).map { row in
            (0..<size).map { col in
                let tileIndex = row * size + col
                let isPath = pathSet.contains(tileIndex)
                let isStart = tileIndex == result.startTile
                let isEnd = tileIndex == result.endTile
                let state: MemoryPathTileState = isStart ? .start : (isEnd ? .end : .hidden)
                return MemoryPathTile(row: row, col: col, isPath: isPath, isStart: isStart, isEnd: isEnd, state: state)
            }
        }
    }

    private func beginPlay() {
        if settings.playType == .singleDevice && settings.gameMode == .timeRace && currentPlayerIndex > 0 {
            passDevicePlayerName = players[currentPlayerIndex].name
            phase = .passDevice
            return
        }

        resetBoardForCurrentPlayer()
        phase = .playing
        startTimer()
    }

    private func tileStateForCorrectStep(at row: Int, col: Int) -> MemoryPathTileState {
        if tiles[row][col].isStart { return .start }
        if tiles[row][col].isEnd { return .end }
        return .correct
    }

    private func resetBoardForCurrentPlayer() {
        let progress: Int
        if settings.playType == .team {
            progress = teams[currentTeamIndex].progress
        } else {
            progress = players[currentPlayerIndex].progress
        }

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if tiles[row][col].isStart {
                    tiles[row][col].state = .start
                } else if tiles[row][col].isEnd {
                    tiles[row][col].state = .end
                } else {
                    tiles[row][col].state = .hidden
                }
            }
        }

        for index in 0..<progress {
            let tile = pathTiles[index]
            tiles[tile.0][tile.1].state = tileStateForCorrectStep(at: tile.0, col: tile.1)
        }
    }

    private func handleCorrectTap(row: Int, col: Int) {
        tiles[row][col].state = tileStateForCorrectStep(at: row, col: col)
        correctFeedbackToken += 1
        FeedbackService.shared.playSuccess()

        if settings.playType == .team {
            teams[currentTeamIndex].progress += 1
        } else {
            players[currentPlayerIndex].progress += 1
        }

        let newProgress = currentProgress
        if newProgress >= pathTiles.count - 1 {
            if let end = pathTiles.last {
                tiles[end.0][end.1].state = .end
            }
            handleCompletion()
        }
    }

    private func handleWrongTap(row: Int, col: Int) {
        let tileID = tiles[row][col].id
        wrongTileID = tileID
        wrongFeedbackToken += 1
        tiles[row][col].state = .wrong
        FeedbackService.shared.playRoundEnd()

        if settings.playType == .team {
            teams[currentTeamIndex].attempts += 1
        } else {
            players[currentPlayerIndex].attempts += 1
        }

        Task {
            try? await Task.sleep(for: .seconds(0.5))
            wrongTileID = nil
            tiles[row][col].state = .hidden

            if settings.gameMode == .turnBased {
                handleTurnBasedWrongMove()
            } else {
                resetProgress()
            }
        }
    }

    private func resetProgress() {
        if settings.playType == .team {
            teams[currentTeamIndex].progress = 1
        } else {
            players[currentPlayerIndex].progress = 1
        }
        resetBoardForCurrentPlayer()
    }

    private func handleTurnBasedWrongMove() {
        stopTimer()
        turnAttempts += 1

        if settings.playType == .singleDevice && turnAttempts < 2 {
            resetProgress()
            phase = .playing
            startTimer()
            return
        }

        resetProgress()
        turnAttempts = 0

        if settings.playType == .team {
            let nextTeamIndex = (currentTeamIndex + 1) % teams.count
            if teams[nextTeamIndex].isFinished {
                let remaining = teams.enumerated().filter { !$0.element.isFinished }
                if remaining.count <= 1 {
                    if remaining.count == 1 {
                        currentTeamIndex = remaining[0].offset
                        resetBoardForCurrentPlayer()
                        phase = .playing
                        startTimer()
                    } else {
                        finishGame()
                    }
                    return
                }
            }

            if !teams[currentTeamIndex].memberIDs.isEmpty {
                teams[currentTeamIndex].currentMemberIndex = (teams[currentTeamIndex].currentMemberIndex + 1) % teams[currentTeamIndex].memberIDs.count
            }
            currentTeamIndex = nextTeamIndex

            let nextTeam = teams[currentTeamIndex]
            if let memberID = nextTeam.currentMemberID, let player = players.first(where: { $0.id == memberID }) {
                turnSwitchMessage = "\(nextTeam.name)\n\(player.name)'s turn"
            } else {
                turnSwitchMessage = "\(nextTeam.name)'s turn"
            }
            phase = .turnSwitch
        } else {
            var nextIndex = (currentPlayerIndex + 1) % players.count
            var loopCount = 0
            while players[nextIndex].isFinished && loopCount < players.count {
                nextIndex = (nextIndex + 1) % players.count
                loopCount += 1
            }

            if loopCount >= players.count {
                finishGame()
                return
            }

            currentPlayerIndex = nextIndex
            turnAttempts = 0

            if settings.playType == .singleDevice {
                passDevicePlayerName = players[currentPlayerIndex].name
                phase = .passDevice
            } else {
                turnSwitchMessage = "\(players[currentPlayerIndex].name)'s turn"
                phase = .turnSwitch
            }
        }
    }

    private func handleCompletion() {
        stopTimer()
        let time = accumulatedTime + (startTime.map { Date().timeIntervalSince($0) } ?? 0)

        if settings.playType == .team {
            teams[currentTeamIndex].completionTime = time
            showConfetti = true
            FeedbackService.shared.playSuccess()

            if teams.allSatisfy(\.isFinished) || settings.gameMode == .turnBased {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    finishGame()
                }
            } else {
                let nextTeamIndex = (currentTeamIndex + 1) % teams.count
                if !teams[nextTeamIndex].isFinished {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        showConfetti = false
                        currentTeamIndex = nextTeamIndex
                        turnSwitchMessage = "\(teams[currentTeamIndex].name)'s turn"
                        phase = .turnSwitch
                    }
                } else {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        finishGame()
                    }
                }
            }
        } else {
            players[currentPlayerIndex].completionTime = time
            players[currentPlayerIndex].finishedAt = Date()
            players[currentPlayerIndex].totalPlayTime = time
            showConfetti = true
            FeedbackService.shared.playSuccess()

            if settings.gameMode == .timeRace {
                let remaining = players.filter { !$0.isFinished }
                if remaining.isEmpty {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        finishGame()
                    }
                } else {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        showConfetti = false
                        currentPlayerIndex = players.firstIndex(where: { !$0.isFinished }) ?? 0
                        accumulatedTime = 0
                        startTime = nil

                        if settings.playType == .singleDevice {
                            passDevicePlayerName = players[currentPlayerIndex].name
                            phase = .passDevice
                        } else {
                            beginPlay()
                        }
                    }
                }
            } else {
                let remaining = players.filter { !$0.isFinished }
                if remaining.isEmpty {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        finishGame()
                    }
                } else {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        showConfetti = false
                        var nextIndex = (currentPlayerIndex + 1) % players.count
                        var loopCount = 0
                        while players[nextIndex].isFinished && loopCount < players.count {
                            nextIndex = (nextIndex + 1) % players.count
                            loopCount += 1
                        }
                        currentPlayerIndex = nextIndex
                        accumulatedTime = 0
                        startTime = nil

                        if settings.playType == .singleDevice {
                            passDevicePlayerName = players[currentPlayerIndex].name
                            phase = .passDevice
                        } else {
                            turnSwitchMessage = "\(players[currentPlayerIndex].name)'s turn"
                            phase = .turnSwitch
                        }
                    }
                }
            }
        }
    }

    private func finishGame() {
        stopTimer()
        showConfetti = false
        buildRankings()
        phase = .finished
    }

    private func playerRankingScore(for player: MemoryPathPlayerState) -> Int {
        let completionBonus = player.isFinished ? 10_000 : 0
        let progressScore = player.progress * 100
        let efficiencyBonus = max(0, 40 - player.attempts * 10)
        let timeBonus = Int(max(0, 600 - (player.completionTime ?? player.totalPlayTime) * 10))
        return completionBonus + progressScore + efficiencyBonus + timeBonus
    }

    private func teamRankingScore(for team: MemoryPathTeam) -> Int {
        let completionBonus = team.isFinished ? 10_000 : 0
        let progressScore = team.progress * 100
        let efficiencyBonus = max(0, 40 - team.attempts * 10)
        let timeBonus = Int(max(0, 600 - (team.completionTime ?? 0) * 10))
        return completionBonus + progressScore + efficiencyBonus + timeBonus
    }

    private func buildRankings() {
        if settings.playType == .team {
            let sorted = teams.sorted { t1, t2 in
                if t1.isFinished && t2.isFinished {
                    return (t1.completionTime ?? .infinity) < (t2.completionTime ?? .infinity)
                }
                if t1.isFinished { return true }
                if t2.isFinished { return false }
                if t1.progress != t2.progress { return t1.progress > t2.progress }
                if t1.attempts != t2.attempts { return t1.attempts < t2.attempts }
                return teamRankingScore(for: t1) > teamRankingScore(for: t2)
            }
            rankings = sorted.enumerated().map { index, team in
                MemoryPathRanking(
                    name: team.name,
                    rank: index + 1,
                    score: teamRankingScore(for: team),
                    completed: team.isFinished,
                    progress: team.progress,
                    pathLength: pathTiles.count,
                    attempts: team.attempts,
                    time: team.completionTime,
                    isTeam: true
                )
            }
        } else if settings.gameMode == .timeRace {
            let sorted = players.sorted { p1, p2 in
                if p1.isFinished && p2.isFinished {
                    let t1 = p1.completionTime ?? .infinity
                    let t2 = p2.completionTime ?? .infinity
                    if t1 != t2 { return t1 < t2 }
                    if p1.attempts != p2.attempts { return p1.attempts < p2.attempts }
                    return playerRankingScore(for: p1) > playerRankingScore(for: p2)
                }
                if p1.isFinished { return true }
                if p2.isFinished { return false }
                if p1.progress != p2.progress { return p1.progress > p2.progress }
                if p1.attempts != p2.attempts { return p1.attempts < p2.attempts }
                return playerRankingScore(for: p1) > playerRankingScore(for: p2)
            }
            rankings = sorted.enumerated().map { index, player in
                MemoryPathRanking(
                    name: player.name,
                    rank: index + 1,
                    score: playerRankingScore(for: player),
                    completed: player.isFinished,
                    progress: player.progress,
                    pathLength: pathTiles.count,
                    attempts: player.attempts,
                    time: player.completionTime
                )
            }
        } else {
            let finished = players.filter(\.isFinished).sorted { ($0.finishedAt ?? .distantFuture) < ($1.finishedAt ?? .distantFuture) }
            let unfinished = players.filter { !$0.isFinished }.sorted { p1, p2 in
                if p1.progress != p2.progress { return p1.progress > p2.progress }
                if p1.attempts != p2.attempts { return p1.attempts < p2.attempts }
                if p1.totalPlayTime != p2.totalPlayTime { return p1.totalPlayTime < p2.totalPlayTime }
                return playerRankingScore(for: p1) > playerRankingScore(for: p2)
            }
            let combined = finished + unfinished
            rankings = combined.enumerated().map { index, player in
                MemoryPathRanking(
                    name: player.name,
                    rank: index + 1,
                    score: playerRankingScore(for: player),
                    completed: player.isFinished,
                    progress: player.progress,
                    pathLength: pathTiles.count,
                    attempts: player.attempts,
                    time: player.completionTime
                )
            }
        }
    }

    private func hidePathExceptProgress() {
        let progress = currentProgress
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if tiles[row][col].isStart {
                    tiles[row][col].state = .start
                } else if tiles[row][col].isEnd {
                    tiles[row][col].state = .end
                } else {
                    tiles[row][col].state = .hidden
                }
            }
        }
        for index in 0..<progress {
            let tile = pathTiles[index]
            tiles[tile.0][tile.1].state = tileStateForCorrectStep(at: tile.0, col: tile.1)
        }
    }

    private func startTimer() {
        startTime = Date()
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                guard let start = self.startTime else { continue }
                self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(start)
            }
        }
    }

    private func stopTimer() {
        if let start = startTime {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        timerTask?.cancel()
        timerTask = nil
        startTime = nil
    }

}
