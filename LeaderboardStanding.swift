import Foundation

/// Where one player stands on the leaderboard: place, RP, progress to the next tier, and the
/// gaps to the players directly above and below. Pure data, so it's unit-testable.
struct LeaderboardStanding: Equatable {
    struct Neighbor: Equatable {
        let place: Int
        let username: String
        /// RP between the viewer and this player (always 0 or more).
        let gap: Int64
    }

    let place: Int          // 1-based
    let totalPlayers: Int
    let rankPoints: Int64
    let rank: String
    let above: Neighbor?
    let below: Neighbor?
    /// The next tier up and the RP still needed to reach it; nil at the top tier.
    let nextTier: (name: String, rpToGo: Int64)?
    /// 0...1 progress through the current tier (1 for the uncapped top tier).
    let tierProgress: Double

    static func == (lhs: LeaderboardStanding, rhs: LeaderboardStanding) -> Bool {
        lhs.place == rhs.place && lhs.totalPlayers == rhs.totalPlayers && lhs.rankPoints == rhs.rankPoints
            && lhs.above == rhs.above && lhs.below == rhs.below
            && lhs.nextTier?.name == rhs.nextTier?.name && lhs.nextTier?.rpToGo == rhs.nextTier?.rpToGo
    }

    /// - Parameters:
    ///   - ranking: the leaderboard, best first, as (username, RP).
    ///   - index: the viewer's 0-based position in `ranking`.
    init?(ranking: [(username: String, rankPoints: Int64)], index: Int) {
        guard ranking.indices.contains(index) else { return nil }
        let me = ranking[index]
        place = index + 1
        totalPlayers = ranking.count
        rankPoints = me.rankPoints
        rank = RankSystem.rankName(for: me.rankPoints)

        above = index > 0
            ? Neighbor(place: index, username: ranking[index - 1].username,
                       gap: max(0, ranking[index - 1].rankPoints - me.rankPoints))
            : nil
        below = index + 1 < ranking.count
            ? Neighbor(place: index + 2, username: ranking[index + 1].username,
                       gap: max(0, me.rankPoints - ranking[index + 1].rankPoints))
            : nil

        if let tierIndex = RankSystem.index(of: rank) {
            let tier = RankSystem.tiers[tierIndex]
            if tierIndex + 1 < RankSystem.tiers.count {
                let next = RankSystem.tiers[tierIndex + 1]
                nextTier = (next.name, next.minPoints - me.rankPoints)
                let span = Double(next.minPoints - tier.minPoints)
                tierProgress = min(1, max(0, Double(me.rankPoints - tier.minPoints) / span))
            } else {
                nextTier = nil
                tierProgress = 1
            }
        } else {
            nextTier = nil
            tierProgress = 0
        }
    }
}
