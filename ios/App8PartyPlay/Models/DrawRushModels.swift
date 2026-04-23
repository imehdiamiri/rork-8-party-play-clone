import Foundation
import SwiftUI

nonisolated struct DRPoint: Codable, Hashable, Sendable {
    let x: Double
    let y: Double
}

nonisolated struct DRStroke: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let color: String
    let width: Double
    var points: [DRPoint]

    init(id: UUID = UUID(), color: String, width: Double, points: [DRPoint] = []) {
        self.id = id
        self.color = color
        self.width = width
        self.points = points
    }

    var uiColor: Color {
        switch color {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "black": return .black
        case "white": return .white
        default: return .white
        }
    }
}

nonisolated enum DRBrushColor: String, CaseIterable, Identifiable, Hashable, Sendable {
    case white, red, orange, yellow, green, blue, purple, pink, brown, black

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .white: return .white
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        case .black: return .black
        }
    }
}

nonisolated struct DRAnswer: Identifiable, Hashable, Sendable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let text: String
    let submittedAt: Date
    let wasDuringDrawing: Bool
    var isCorrect: Bool
    var isJudged: Bool

    init(id: UUID = UUID(), playerID: UUID, playerName: String, text: String, submittedAt: Date, wasDuringDrawing: Bool, isCorrect: Bool = false, isJudged: Bool = false) {
        self.id = id
        self.playerID = playerID
        self.playerName = playerName
        self.text = text
        self.submittedAt = submittedAt
        self.wasDuringDrawing = wasDuringDrawing
        self.isCorrect = isCorrect
        self.isJudged = isJudged
    }
}

nonisolated enum DRConceptMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case preset
    case freeDraw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preset: return "Preset Concepts"
        case .freeDraw: return "Free Draw"
        }
    }

    var subtitle: String {
        switch self {
        case .preset: return "Drawer gets a secret word"
        case .freeDraw: return "Drawer picks their own idea"
        }
    }

    var icon: String {
        switch self {
        case .preset: return "text.book.closed.fill"
        case .freeDraw: return "sparkles"
        }
    }
}

nonisolated struct DRPlayer: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    var score: Int

    init(id: UUID = UUID(), name: String, score: Int = 0) {
        self.id = id
        self.name = name
        self.score = score
    }
}

nonisolated enum DrawRushPhase: Hashable, Sendable {
    case turnIntro
    case drawerReveal
    case drawing
    case passForGuesses
    case guessing
    case drawerJudging
    case roundResults
    case finalLeaderboard
}

nonisolated enum DrawRushConcepts {
    static let list: [String] = [
        "Pizza", "Elephant", "Guitar", "Rainbow", "Rocket", "Banana", "Volcano",
        "Sunflower", "Penguin", "Ice Cream", "Dragon", "Castle", "Camera", "Robot",
        "Sandwich", "Lighthouse", "Octopus", "Tornado", "Cactus", "Basketball",
        "Skateboard", "Helicopter", "Pirate", "Ninja", "Mermaid", "Alien",
        "Sunglasses", "Donut", "Umbrella", "Clock", "Spider", "Keyboard",
        "Dinosaur", "Astronaut", "Snowman", "Cupcake", "Butterfly", "Mountain",
        "Windmill", "Telescope", "Hamburger", "Jellyfish", "Lightning",
        "Giraffe", "Campfire", "Bicycle", "Kite", "Scarecrow", "Anchor",
        "Compass", "Treasure Chest", "Magic Wand", "Crown", "Trophy", "Pencil",
        "Waterfall", "Dragonfly", "Cowboy", "Wizard", "Tiger", "Submarine",
        "Eiffel Tower", "Pyramid", "Popcorn", "Watermelon", "Backpack",
        "Mushroom", "Owl", "Vampire", "Zombie", "Ghost", "UFO", "Island",
        "Lemon", "Strawberry", "Toaster", "Trumpet", "Piano", "Drum"
    ]

    static func pick(seed: UInt64, avoid: Set<String>) -> String {
        let rng = QuickSeededRNG(seed: seed)
        let available = list.filter { !avoid.contains($0) }
        guard !available.isEmpty else { return list[rng.nextInt(bound: list.count)] }
        return available[rng.nextInt(bound: available.count)]
    }
}

nonisolated enum DrawRushScoring {
    static let fastestCorrect: Int = 15
    static let otherCorrect: Int = 12
    static let singleDeviceCorrect: Int = 10
    static let drawDuration: Int = 60
}
