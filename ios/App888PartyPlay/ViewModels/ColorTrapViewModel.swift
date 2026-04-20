import Foundation
import Observation
import SwiftUI

nonisolated struct ColorTrapActiveTile: Identifiable, Hashable, Sendable {
    let id: Int
    let spawnedAt: Double
    let columnIndex: Int
    let colorIndex: Int
    let size: Double
    var isHit: Bool = false
    var isMissedTap: Bool = false
}

@Observable
@MainActor
final class ColorTrapViewModel {
    var difficulty: ColorTrapDifficulty = .medium
    var forbiddenColorIndex: Int = 0
    var spawns: [ColorTrapSpawn] = []
    var activeTiles: [ColorTrapActiveTile] = []
    var elapsedSeconds: Double = 0
    var isActive: Bool = false
    var isFinished: Bool = false
    var hits: Int = 0
    var fails: Int = 0
    var wasEliminated: Bool = false
    var lastTappedWrongID: Int? = nil

    private var tickTask: Task<Void, Never>?
    private var spawnCursor: Int = 0

    static let palette: [Color] = [.red, .blue, .green, .yellow, .purple]
    static let maxFails: Int = 3

    var forbiddenColor: Color {
        Self.palette[forbiddenColorIndex % Self.palette.count]
    }

    var failsLeft: Int { max(0, Self.maxFails - fails) }

    func start(difficulty: ColorTrapDifficulty, seed: UInt64, forbiddenColorIndex: Int) {
        self.difficulty = difficulty
        self.forbiddenColorIndex = forbiddenColorIndex
        self.spawns = ColorTrapGenerator.generateSpawns(difficulty: difficulty, seed: seed)
        self.activeTiles = []
        self.elapsedSeconds = 0
        self.isActive = true
        self.isFinished = false
        self.hits = 0
        self.fails = 0
        self.wasEliminated = false
        self.lastTappedWrongID = nil
        self.spawnCursor = 0
        startTick()
    }

    func tap(tileID: Int) {
        guard isActive else { return }
        guard let idx = activeTiles.firstIndex(where: { $0.id == tileID && !$0.isHit }) else { return }
        let tile = activeTiles[idx]
        if tile.colorIndex == forbiddenColorIndex {
            registerFail(tileID: tileID)
            FeedbackService.shared.playError()
        } else {
            activeTiles[idx].isHit = true
            hits += 1
            FeedbackService.shared.playClick()
        }
    }

    func cleanup() {
        stopTick()
    }

    func reset() {
        stopTick()
        activeTiles = []
        elapsedSeconds = 0
        isActive = false
        isFinished = false
        hits = 0
        fails = 0
        wasEliminated = false
        lastTappedWrongID = nil
        spawnCursor = 0
    }

    private func registerFail(tileID: Int) {
        fails += 1
        lastTappedWrongID = tileID
        if fails >= Self.maxFails {
            wasEliminated = true
            finish()
        }
    }

    private func finish() {
        isActive = false
        isFinished = true
        stopTick()
    }

    private func startTick() {
        stopTick()
        tickTask = Task { [weak self] in
            let step: Double = 0.05
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(step * 1000)))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.isActive else { return }
                    self.advance(by: step)
                }
            }
        }
    }

    private func stopTick() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func advance(by step: Double) {
        elapsedSeconds += step
        spawnDueTiles()
        expireMissedTiles()
        if elapsedSeconds >= difficulty.totalDuration {
            finish()
        }
    }

    private func spawnDueTiles() {
        while spawnCursor < spawns.count, spawns[spawnCursor].appearAt <= elapsedSeconds {
            let spawn = spawns[spawnCursor]
            activeTiles.append(ColorTrapActiveTile(
                id: spawn.id,
                spawnedAt: elapsedSeconds,
                columnIndex: spawn.columnIndex,
                colorIndex: spawn.colorIndex,
                size: spawn.size
            ))
            spawnCursor += 1
        }
    }

    private func expireMissedTiles() {
        let lifetime = difficulty.tileLifetime
        var expired: [ColorTrapActiveTile] = []
        activeTiles.removeAll { tile in
            if !tile.isHit && (elapsedSeconds - tile.spawnedAt) > lifetime {
                expired.append(tile)
                return true
            }
            if tile.isHit && (elapsedSeconds - tile.spawnedAt) > 0.35 {
                return true
            }
            return false
        }
        // Missed forbidden tile doesn't cause fail — only tapping forbidden does.
        // Missed safe tile is just ignored (but count wasn't incremented).
        _ = expired
    }
}
