import Foundation
import Observation

@Observable
@MainActor
final class MemoryGridViewModel {
    var tiles: [MemoryTile] = []
    var gridSize: MemoryGridSize = .small4x4
    var isResolving: Bool = false
    var matchedPairs: Int = 0
    var moveCount: Int = 0
    var elapsedSeconds: Double = 0
    var isGameActive: Bool = false
    var isGameComplete: Bool = false

    var onStateChange: (@MainActor () -> Void)?

    private var firstFlippedIndex: Int?
    private var timerTask: Task<Void, Never>?

    private static let tileSymbols: [String] = [
        "star.fill", "heart.fill", "moon.fill", "sun.max.fill",
        "bolt.fill", "flame.fill", "leaf.fill", "drop.fill",
        "snowflake", "cloud.fill", "wind", "tornado",
        "sparkles", "bell.fill", "flag.fill", "crown.fill",
        "diamond.fill", "globe.americas.fill"
    ]

    var totalPairs: Int { gridSize.pairCount }

    var formattedTime: String {
        let minutes = Int(elapsedSeconds) / 60
        let seconds = Int(elapsedSeconds) % 60
        let tenths = Int((elapsedSeconds * 10).truncatingRemainder(dividingBy: 10))
        if minutes > 0 {
            return String(format: "%d:%02d.%d", minutes, seconds, tenths)
        }
        return String(format: "%d.%d", seconds, tenths)
    }

    var progress: Double {
        guard totalPairs > 0 else { return 0 }
        return Double(matchedPairs) / Double(totalPairs)
    }

    func startGame(size: MemoryGridSize) {
        gridSize = size
        tiles = generateBoard(size: size)
        matchedPairs = 0
        moveCount = 0
        elapsedSeconds = 0
        isGameActive = true
        isGameComplete = false
        firstFlippedIndex = nil
        isResolving = false
        startTimer()
        onStateChange?()
    }

    func flipTile(at index: Int) {
        guard isGameActive, !isResolving else { return }
        guard index >= 0, index < tiles.count else { return }
        guard !tiles[index].isFlipped, !tiles[index].isMatched else { return }

        tiles[index].isFlipped = true
        SoundManager.shared.playTileFlip()
        onStateChange?()

        if let firstIndex = firstFlippedIndex {
            moveCount += 1
            if tiles[firstIndex].pairId == tiles[index].pairId {
                tiles[firstIndex].isMatched = true
                tiles[index].isMatched = true
                matchedPairs += 1
                firstFlippedIndex = nil
                SoundManager.shared.playMatch()
                onStateChange?()

                if matchedPairs >= totalPairs {
                    completeGame()
                }
            } else {
                isResolving = true
                let capturedFirst = firstIndex
                let capturedSecond = index
                firstFlippedIndex = nil
                Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    guard isGameActive else { return }
                    tiles[capturedFirst].isFlipped = false
                    tiles[capturedSecond].isFlipped = false
                    isResolving = false
                    SoundManager.shared.playMismatch()
                    onStateChange?()
                }
            }
        } else {
            firstFlippedIndex = index
        }
    }

    func resetGame() {
        stopTimer()
        tiles = []
        matchedPairs = 0
        moveCount = 0
        elapsedSeconds = 0
        isGameActive = false
        isGameComplete = false
        firstFlippedIndex = nil
        isResolving = false
    }

    func cleanup() {
        stopTimer()
    }

    private func generateBoard(size: MemoryGridSize) -> [MemoryTile] {
        let pairCount = size.pairCount
        let symbols = Array(Self.tileSymbols.shuffled().prefix(pairCount))
        var board: [MemoryTile] = []
        for (pairId, symbol) in symbols.enumerated() {
            let colorIdx = pairId % 10
            board.append(MemoryTile(pairId: pairId, symbol: symbol, colorIndex: colorIdx))
            board.append(MemoryTile(pairId: pairId, symbol: symbol, colorIndex: colorIdx))
        }
        board.shuffle()
        return board
    }

    private func completeGame() {
        isGameComplete = true
        isGameActive = false
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                guard self.isGameActive else { return }
                self.elapsedSeconds += 0.1
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

}
