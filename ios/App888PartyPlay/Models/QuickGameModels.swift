import Foundation

// MARK: - Seeded RNG shared between games

nonisolated final class QuickSeededRNG: @unchecked Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xdeadbeefcafef00d : seed
    }

    func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        z = z ^ (z >> 31)
        return z
    }

    func nextInt(bound: Int) -> Int {
        guard bound > 0 else { return 0 }
        return Int(next() % UInt64(bound))
    }

    func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

nonisolated enum SeedHasher {
    static func seed(from uuid: UUID) -> UInt64 {
        let bytes = uuid.uuid
        var result: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        withUnsafeBytes(of: bytes) { raw in
            for byte in raw {
                result ^= UInt64(byte)
                result = result &* prime
            }
        }
        return result
    }
}

// MARK: - Tap in Order

nonisolated enum TapInOrderVariant: String, CaseIterable, Identifiable, Hashable, Sendable {
    case numberMemory = "number_memory"
    case patternMemory = "pattern_memory"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .numberMemory: return "Number Memory"
        case .patternMemory: return "Pattern Memory"
        }
    }

    var subtitle: String {
        switch self {
        case .numberMemory: return "Memorize the numbers, then tap 1 → N in order"
        case .patternMemory: return "Memorize the pattern, then tap the correct tiles"
        }
    }

    var icon: String {
        switch self {
        case .numberMemory: return "number.square.fill"
        case .patternMemory: return "square.grid.3x3.fill"
        }
    }
}

nonisolated enum TapInOrderBoard {
    static let gridSizeOptions: [Int] = [4, 5, 6, 7]
    static let maxMistakesNumberMemory: Int = 3

    static func tileOptions(for gridSize: Int, variant: TapInOrderVariant) -> [Int] {
        switch gridSize {
        case 4: return variant == .numberMemory ? [4, 6, 8, 10] : [3, 5, 7, 9]
        case 5: return variant == .numberMemory ? [6, 8, 10, 14] : [4, 7, 10, 13]
        case 6: return variant == .numberMemory ? [8, 12, 16, 22] : [6, 10, 14, 20]
        case 7: return variant == .numberMemory ? [10, 14, 20, 28] : [8, 14, 20, 28]
        default: return [6, 8, 10]
        }
    }

    static func defaultTileCount(for gridSize: Int, variant: TapInOrderVariant) -> Int {
        let options = tileOptions(for: gridSize, variant: variant)
        return options[min(1, options.count - 1)]
    }

    static func previewDuration(tileCount: Int) -> Double {
        return max(4.0, 3.5 + Double(tileCount) * 0.35)
    }

    static func difficultyLabel(gridSize: Int, tileCount: Int) -> String {
        "\(gridSize)×\(gridSize) · \(tileCount) tiles"
    }
}

nonisolated struct TapInOrderSettings: Hashable, Sendable {
    let variant: TapInOrderVariant
    let gridSize: Int
    let tileCount: Int

    static let `default` = TapInOrderSettings(variant: .numberMemory, gridSize: 4, tileCount: 6)

    var label: String { TapInOrderBoard.difficultyLabel(gridSize: gridSize, tileCount: tileCount) }
}

nonisolated struct TIOPlayerResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let variant: String
    let elapsedSeconds: Double
    let correctCount: Int
    let totalTargets: Int
    let missTaps: Int
    let didFinish: Bool

    init(id: UUID = UUID(), playerID: UUID, playerName: String, variant: String = TapInOrderVariant.numberMemory.rawValue, elapsedSeconds: Double, correctCount: Int, totalTargets: Int, missTaps: Int, didFinish: Bool) {
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

    var resolvedVariant: TapInOrderVariant {
        TapInOrderVariant(rawValue: variant) ?? .numberMemory
    }
}

nonisolated struct TapInOrderGameState: Hashable, Sendable {
    let variant: String
    let gridSize: Int
    let tileCount: Int
    let seed: UInt64
    let selectedCells: [Int]
    let currentPlayerIndex: Int
    let playerResults: [TIOPlayerResult]
    let isFinished: Bool

    init(variant: String = TapInOrderVariant.numberMemory.rawValue, gridSize: Int = 4, tileCount: Int = 6, seed: UInt64 = 0, selectedCells: [Int] = [], currentPlayerIndex: Int = 0, playerResults: [TIOPlayerResult] = [], isFinished: Bool = false) {
        self.variant = variant
        self.gridSize = gridSize
        self.tileCount = tileCount
        self.seed = seed
        self.selectedCells = selectedCells
        self.currentPlayerIndex = currentPlayerIndex
        self.playerResults = playerResults
        self.isFinished = isFinished
    }

    var resolvedVariant: TapInOrderVariant {
        TapInOrderVariant(rawValue: variant) ?? .numberMemory
    }
}

nonisolated enum TapInOrderGenerator {
    static func generateSelectedCells(variant: TapInOrderVariant, gridSize: Int, tileCount: Int, seed: UInt64) -> [Int] {
        let total = gridSize * gridSize
        let tiles = min(tileCount, total)
        let rng = QuickSeededRNG(seed: seed)
        var indices = Array(0..<total)
        for i in stride(from: indices.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(bound: i + 1)
            if i != j { indices.swapAt(i, j) }
        }
        return Array(indices.prefix(tiles))
    }
}

// MARK: - Color Trap

nonisolated enum ColorTrapDifficulty: String, CaseIterable, Identifiable, Hashable, Sendable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: return "Slower tiles · 20s"
        case .medium: return "Faster tiles · 30s"
        case .hard: return "Chaos · 45s"
        }
    }

    var totalDuration: Double {
        switch self {
        case .easy: return 20
        case .medium: return 30
        case .hard: return 45
        }
    }

    var spawnInterval: Double {
        switch self {
        case .easy: return 0.9
        case .medium: return 0.65
        case .hard: return 0.45
        }
    }

    var tileLifetime: Double {
        switch self {
        case .easy: return 1.9
        case .medium: return 1.5
        case .hard: return 1.15
        }
    }
}

nonisolated struct ColorTrapSettings: Hashable, Sendable {
    let difficulty: ColorTrapDifficulty

    static let `default` = ColorTrapSettings(difficulty: .medium)
}

nonisolated struct ColorTrapSpawn: Identifiable, Hashable, Sendable {
    let id: Int
    let appearAt: Double
    let columnIndex: Int
    let colorIndex: Int
    let size: Double
}

nonisolated struct CTPlayerResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let hits: Int
    let fails: Int
    let survivalTime: Double
    let eliminated: Bool

    init(id: UUID = UUID(), playerID: UUID, playerName: String, hits: Int, fails: Int, survivalTime: Double, eliminated: Bool) {
        self.id = id
        self.playerID = playerID
        self.playerName = playerName
        self.hits = hits
        self.fails = fails
        self.survivalTime = survivalTime
        self.eliminated = eliminated
    }

    var score: Int {
        hits * 10 + Int(survivalTime * 5) - fails * 15
    }
}

nonisolated struct ColorTrapGameState: Hashable, Sendable {
    let difficulty: String
    let seed: UInt64
    let forbiddenColorIndex: Int
    let currentPlayerIndex: Int
    let playerResults: [CTPlayerResult]
    let isFinished: Bool

    init(difficulty: String = ColorTrapDifficulty.medium.rawValue, seed: UInt64 = 0, forbiddenColorIndex: Int = 0, currentPlayerIndex: Int = 0, playerResults: [CTPlayerResult] = [], isFinished: Bool = false) {
        self.difficulty = difficulty
        self.seed = seed
        self.forbiddenColorIndex = forbiddenColorIndex
        self.currentPlayerIndex = currentPlayerIndex
        self.playerResults = playerResults
        self.isFinished = isFinished
    }

    var resolvedDifficulty: ColorTrapDifficulty {
        ColorTrapDifficulty(rawValue: difficulty) ?? .medium
    }
}

nonisolated enum ColorTrapGenerator {
    static let columnCount: Int = 4
    static let paletteSize: Int = 5

    static func generateSpawns(difficulty: ColorTrapDifficulty, seed: UInt64) -> [ColorTrapSpawn] {
        let rng = QuickSeededRNG(seed: seed)
        let total = difficulty.totalDuration
        let interval = difficulty.spawnInterval
        var spawns: [ColorTrapSpawn] = []
        var t: Double = 0.4
        var id: Int = 0
        while t < total {
            let jitter = (rng.nextDouble() - 0.5) * interval * 0.3
            let appear = max(0, min(total - 0.1, t + jitter))
            let column = rng.nextInt(bound: columnCount)
            let color = rng.nextInt(bound: paletteSize)
            let size = 0.9 + rng.nextDouble() * 0.2
            spawns.append(ColorTrapSpawn(id: id, appearAt: appear, columnIndex: column, colorIndex: color, size: size))
            id += 1
            t += interval
        }
        return spawns.sorted { $0.appearAt < $1.appearAt }
    }

    static func pickForbiddenColor(seed: UInt64) -> Int {
        let rng = QuickSeededRNG(seed: seed &+ 0xA5A5A5A5)
        return rng.nextInt(bound: paletteSize)
    }
}
