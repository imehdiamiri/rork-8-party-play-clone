import Foundation

@MainActor
final class SharedResultBuilder {
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
            let starsWon = isWin ? policy.starsForWin : policy.starsForParticipation

            return GameResultRow(
                name: player.username,
                score: score,
                rank: rank,
                starsWon: starsWon
            )
        }
    }
}
