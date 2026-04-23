import Foundation

nonisolated struct MemoryPathResult: Sendable {
    let rows: Int
    let cols: Int
    let startTile: Int
    let endTile: Int
    let pathTiles: [Int]
}

nonisolated struct MemoryPathGenerator: Sendable {

    private struct Coord: Hashable, Sendable {
        let row: Int
        let col: Int

        func index(cols: Int) -> Int { row * cols + col }
    }

    private struct Dir: Hashable, Sendable {
        let dr: Int
        let dc: Int
    }

    private enum Direction: CaseIterable {
        case up, down, left, right

        var delta: Dir {
            switch self {
            case .up: return Dir(dr: -1, dc: 0)
            case .down: return Dir(dr: 1, dc: 0)
            case .left: return Dir(dr: 0, dc: -1)
            case .right: return Dir(dr: 0, dc: 1)
            }
        }
    }

    static func generate(rows: Int, cols: Int, seed: UInt64? = nil) -> MemoryPathResult {
        let rng: SeededRNG
        if let seed {
            rng = SeededRNG(seed: seed)
        } else {
            rng = SeededRNG(seed: UInt64.random(in: 0...UInt64.max))
        }

        let lengthRange = pathLengthRange(rows: rows, cols: cols)
        let maxRetries = 50

        for _ in 0..<maxRetries {
            if let result = attemptGeneration(rows: rows, cols: cols, lengthRange: lengthRange, rng: rng) {
                return result
            }
        }

        return fallbackPath(rows: rows, cols: cols)
    }

    private static func pathLengthRange(rows: Int, cols: Int) -> ClosedRange<Int> {
        let size = min(rows, cols)
        switch size {
        case ...5: return 8...10
        case 6: return 10...13
        case 7: return 12...16
        default: return 14...18
        }
    }

    private static func minTurns(for size: Int) -> Int {
        switch size {
        case ...5: return 2
        case 6: return 3
        default: return 4
        }
    }

    private static func minEndDistance(for size: Int) -> Int {
        switch size {
        case ...5: return 4
        case 6: return 5
        case 7: return 6
        default: return 7
        }
    }

    private static func attemptGeneration(
        rows: Int,
        cols: Int,
        lengthRange: ClosedRange<Int>,
        rng: SeededRNG
    ) -> MemoryPathResult? {
        let startCol = rng.nextInt(bound: cols)
        let start = Coord(row: 0, col: startCol)

        var path: [Coord] = [start]
        var visited: Set<Coord> = [start]

        if dfs(
            current: start,
            path: &path,
            visited: &visited,
            rows: rows,
            cols: cols,
            targetLength: lengthRange.upperBound,
            minLength: lengthRange.lowerBound,
            rng: rng
        ) {
            if validateFinalPath(path, rows: rows, cols: cols, lengthRange: lengthRange) {
                let indices = path.map { $0.row * cols + $0.col }
                return MemoryPathResult(
                    rows: rows,
                    cols: cols,
                    startTile: indices[0],
                    endTile: indices[indices.count - 1],
                    pathTiles: indices
                )
            }
        }

        return nil
    }

    private static func dfs(
        current: Coord,
        path: inout [Coord],
        visited: inout Set<Coord>,
        rows: Int,
        cols: Int,
        targetLength: Int,
        minLength: Int,
        rng: SeededRNG
    ) -> Bool {
        if path.count >= minLength && path.count <= targetLength {
            if validateFinalPath(path, rows: rows, cols: cols, lengthRange: minLength...targetLength) {
                return true
            }
        }

        if path.count >= targetLength {
            return false
        }

        var neighbors = getNeighbors(current, rows: rows, cols: cols)
            .filter { !visited.contains($0) }
            .filter { !isCandidateTooCramped(path: path, next: $0, rows: rows, cols: cols, visited: visited) }
            .filter { !wouldCreateTooLongStraight(path: path, next: $0) }

        shuffleWithRNG(&neighbors, rng: rng)

        for next in neighbors {
            visited.insert(next)
            path.append(next)

            if dfs(
                current: next,
                path: &path,
                visited: &visited,
                rows: rows,
                cols: cols,
                targetLength: targetLength,
                minLength: minLength,
                rng: rng
            ) {
                return true
            }

            path.removeLast()
            visited.remove(next)
        }

        return false
    }

    private static func getNeighbors(_ coord: Coord, rows: Int, cols: Int) -> [Coord] {
        Direction.allCases.compactMap { direction in
            let d = direction.delta
            let nr = coord.row + d.dr
            let nc = coord.col + d.dc
            guard nr >= 0, nr < rows, nc >= 0, nc < cols else { return nil }
            return Coord(row: nr, col: nc)
        }
    }

    private static func isAdjacent(_ a: Coord, _ b: Coord) -> Bool {
        abs(a.row - b.row) + abs(a.col - b.col) == 1
    }

    private static func getDirection(_ a: Coord, _ b: Coord) -> Dir {
        Dir(dr: b.row - a.row, dc: b.col - a.col)
    }

    private static func manhattanDistance(_ a: Coord, _ b: Coord) -> Int {
        abs(a.row - b.row) + abs(a.col - b.col)
    }

    private static func countTurns(_ path: [Coord]) -> Int {
        guard path.count >= 3 else { return 0 }
        var turns = 0
        for i in 2..<path.count {
            let d1 = getDirection(path[i - 2], path[i - 1])
            let d2 = getDirection(path[i - 1], path[i])
            if d1 != d2 { turns += 1 }
        }
        return turns
    }

    private static func wouldCreateTooLongStraight(path: [Coord], next: Coord) -> Bool {
        guard path.count >= 3 else { return false }

        let last = path[path.count - 1]
        let dir = getDirection(last, next)

        var straightCount = 1
        for i in stride(from: path.count - 1, through: 1, by: -1) {
            let prevDir = getDirection(path[i - 1], path[i])
            if prevDir.dr == dir.dr && prevDir.dc == dir.dc {
                straightCount += 1
            } else {
                break
            }
        }

        return straightCount >= 3
    }

    private static func isCandidateTooCramped(
        path: [Coord],
        next: Coord,
        rows: Int,
        cols: Int,
        visited: Set<Coord>
    ) -> Bool {
        var adjacentUsed = 0
        for direction in Direction.allCases {
            let d = direction.delta
            let nr = next.row + d.dr
            let nc = next.col + d.dc
            guard nr >= 0, nr < rows, nc >= 0, nc < cols else { continue }
            if visited.contains(Coord(row: nr, col: nc)) {
                adjacentUsed += 1
            }
        }
        return adjacentUsed >= 3
    }

    private static func validateFinalPath(
        _ path: [Coord],
        rows: Int,
        cols: Int,
        lengthRange: ClosedRange<Int>
    ) -> Bool {
        guard !path.isEmpty else { return false }
        guard path.count >= lengthRange.lowerBound, path.count <= lengthRange.upperBound else { return false }

        let unique = Set(path)
        guard unique.count == path.count else { return false }

        for i in 1..<path.count {
            guard isAdjacent(path[i - 1], path[i]) else { return false }
        }

        guard let start = path.first, let end = path.last else { return false }

        let size = min(rows, cols)
        let dist = manhattanDistance(start, end)
        guard dist >= minEndDistance(for: size) else { return false }

        let turns = countTurns(path)
        guard turns >= minTurns(for: size) else { return false }

        return true
    }

    private static func shuffleWithRNG(_ array: inout [Coord], rng: SeededRNG) {
        for i in stride(from: array.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(bound: i + 1)
            if i != j {
                array.swapAt(i, j)
            }
        }
    }

    private static func fallbackPath(rows: Int, cols: Int) -> MemoryPathResult {
        var path: [Int] = []
        let startCol = cols / 2
        var col = startCol
        var goingRight = true

        for row in 0..<rows {
            path.append(row * cols + col)
            if row < rows - 1 {
                if goingRight && col < cols - 1 {
                    col += 1
                    path.append(row * cols + col)
                } else if !goingRight && col > 0 {
                    col -= 1
                    path.append(row * cols + col)
                }
                goingRight.toggle()
            }
        }

        let lengthRange = pathLengthRange(rows: rows, cols: cols)
        if path.count > lengthRange.upperBound {
            path = Array(path.prefix(lengthRange.upperBound))
        }

        return MemoryPathResult(
            rows: rows,
            cols: cols,
            startTile: path[0],
            endTile: path[path.count - 1],
            pathTiles: path
        )
    }
}

private nonisolated final class SeededRNG: @unchecked Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
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
}
