import Foundation
import SwiftUI

nonisolated enum MemoryPathGameMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case timeRace
    case turnBased

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeRace: return "Time Race"
        case .turnBased: return "Turn-Based"
        }
    }

    var icon: String {
        switch self {
        case .timeRace: return "timer"
        case .turnBased: return "arrow.trianglehead.2.clockwise"
        }
    }

    var subtitle: String {
        switch self {
        case .timeRace: return "Race to complete the path fastest"
        case .turnBased: return "Take turns, wrong move passes control"
        }
    }
}

nonisolated enum MemoryPathPlayType: String, CaseIterable, Identifiable, Hashable, Sendable {
    case singleDevice
    case multiDevice
    case team

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleDevice: return "1-Device"
        case .multiDevice: return "Multi-Device"
        case .team: return "Team Mode"
        }
    }
}

nonisolated enum MemoryPathDifficulty: String, CaseIterable, Identifiable, Hashable, Sendable {
    case easy
    case medium
    case hard
    case expert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .expert: return "Expert"
        }
    }

    var gridSize: Int {
        switch self {
        case .easy: return 5
        case .medium: return 6
        case .hard: return 7
        case .expert: return 8
        }
    }

    var accentColor: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        case .expert: return .purple
        }
    }
}

nonisolated enum MemoryPathPhase: String, Hashable, Sendable {
    case setup
    case countdown
    case playing
    case passDevice
    case turnSwitch
    case hintActive
    case finished
}

nonisolated enum MemoryPathTileState: Hashable, Sendable {
    case hidden
    case correct
    case wrong
    case hintRevealed
    case start
    case end
}

nonisolated struct MemoryPathTile: Identifiable, Hashable, Sendable {
    let id: UUID
    let row: Int
    let col: Int
    let isPath: Bool
    let isStart: Bool
    let isEnd: Bool
    var state: MemoryPathTileState

    init(id: UUID = UUID(), row: Int, col: Int, isPath: Bool, isStart: Bool = false, isEnd: Bool = false, state: MemoryPathTileState = .hidden) {
        self.id = id
        self.row = row
        self.col = col
        self.isPath = isPath
        self.isStart = isStart
        self.isEnd = isEnd
        self.state = state
    }
}

nonisolated struct MemoryPathPlayerState: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    var progress: Int
    var attempts: Int
    var completionTime: TimeInterval?
    var finishedAt: Date?
    var totalPlayTime: TimeInterval
    var hintUsed: Bool
    var teamID: String?

    init(id: UUID = UUID(), name: String, progress: Int = 0, attempts: Int = 0, completionTime: TimeInterval? = nil, finishedAt: Date? = nil, totalPlayTime: TimeInterval = 0, hintUsed: Bool = false, teamID: String? = nil) {
        self.id = id
        self.name = name
        self.progress = progress
        self.attempts = attempts
        self.completionTime = completionTime
        self.finishedAt = finishedAt
        self.totalPlayTime = totalPlayTime
        self.hintUsed = hintUsed
        self.teamID = teamID
    }

    var isFinished: Bool { completionTime != nil }
}

nonisolated struct MemoryPathTeam: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var memberIDs: [UUID]
    var progress: Int
    var hintUsed: Bool
    var currentMemberIndex: Int
    var completionTime: TimeInterval?
    var attempts: Int

    init(id: String, name: String, memberIDs: [UUID] = [], progress: Int = 0, hintUsed: Bool = false, currentMemberIndex: Int = 0, completionTime: TimeInterval? = nil, attempts: Int = 0) {
        self.id = id
        self.name = name
        self.memberIDs = memberIDs
        self.progress = progress
        self.hintUsed = hintUsed
        self.currentMemberIndex = currentMemberIndex
        self.completionTime = completionTime
        self.attempts = attempts
    }

    var currentMemberID: UUID? {
        guard !memberIDs.isEmpty else { return nil }
        return memberIDs[currentMemberIndex % memberIDs.count]
    }

    var isFinished: Bool { completionTime != nil }
}

nonisolated struct MemoryPathSettings: Hashable, Sendable {
    let gameMode: MemoryPathGameMode
    let playType: MemoryPathPlayType
    let difficulty: MemoryPathDifficulty
    let targetSteps: Int

    static let `default` = MemoryPathSettings(gameMode: .timeRace, playType: .singleDevice, difficulty: .easy, targetSteps: 6)

    static func defaultSteps(for difficulty: MemoryPathDifficulty) -> Int {
        switch difficulty {
        case .easy: return 6
        case .medium: return 10
        case .hard: return 14
        case .expert: return 18
        }
    }

    static func stepsRange(for difficulty: MemoryPathDifficulty) -> ClosedRange<Int> {
        let size = difficulty.gridSize
        let minSteps = max(3, size - 1)
        let maxSteps = size * size / 2
        return minSteps...maxSteps
    }
}

nonisolated struct MemoryPathRanking: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let rank: Int
    let score: Int
    let completed: Bool
    let progress: Int
    let pathLength: Int
    let attempts: Int
    let time: TimeInterval?
    let isTeam: Bool

    init(id: UUID = UUID(), name: String, rank: Int, score: Int, completed: Bool, progress: Int, pathLength: Int, attempts: Int, time: TimeInterval?, isTeam: Bool = false) {
        self.id = id
        self.name = name
        self.rank = rank
        self.score = score
        self.completed = completed
        self.progress = progress
        self.pathLength = pathLength
        self.attempts = attempts
        self.time = time
        self.isTeam = isTeam
    }

    var progressPercent: Double {
        guard pathLength > 0 else { return 0 }
        return Double(progress) / Double(pathLength) * 100
    }

    var formattedTime: String {
        guard let time else { return "—" }
        let seconds = Int(time) % 60
        let minutes = Int(time) / 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
