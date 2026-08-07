import Foundation

/// Single source of truth for the ranked-tier system.
///
/// Previously this logic (tier thresholds, per-tier stat averages, rank
/// ordering) was copy-pasted across `AddGameView`, `DashboardView`,
/// `LeaderboardView`, and `PlayerOverviewView` — with the thresholds
/// actually disagreeing between copies (Bronze III was `100...150` in one
/// file and `101...150` elsewhere). Everything now goes through here.
enum RankSystem {

    struct Tier {
        let name: String
        let minPoints: Int64
        let maxPoints: Int64  // inclusive; the top tier has no real ceiling
        /// Stat averages a player in this tier is compared against when a game is recorded.
        let averages: [String: Int64]  // keys: points, rebounds, assists, blocks, steals
    }

    /// Ordered lowest → highest.
    static let tiers: [Tier] = [
        Tier(name: "Rookie",     minPoints: 0,   maxPoints: 100,
             averages: ["points": 5,  "rebounds": 3, "assists": 2, "blocks": 0, "steals": 1]),
        Tier(name: "Bronze III", minPoints: 101, maxPoints: 150,
             averages: ["points": 7,  "rebounds": 4, "assists": 2, "blocks": 0, "steals": 1]),
        Tier(name: "Bronze II",  minPoints: 151, maxPoints: 200,
             averages: ["points": 9,  "rebounds": 4, "assists": 3, "blocks": 0, "steals": 2]),
        Tier(name: "Bronze I",   minPoints: 201, maxPoints: 250,
             averages: ["points": 11, "rebounds": 5, "assists": 3, "blocks": 1, "steals": 2]),
        Tier(name: "Silver III", minPoints: 251, maxPoints: 300,
             averages: ["points": 10, "rebounds": 4, "assists": 3, "blocks": 1, "steals": 2]),
        Tier(name: "Silver II",  minPoints: 301, maxPoints: 350,
             averages: ["points": 11, "rebounds": 5, "assists": 3, "blocks": 1, "steals": 2]),
        Tier(name: "Silver I",   minPoints: 351, maxPoints: 400,
             averages: ["points": 12, "rebounds": 6, "assists": 3, "blocks": 1, "steals": 3]),
        Tier(name: "Gold III",   minPoints: 401, maxPoints: 450,
             averages: ["points": 10, "rebounds": 5, "assists": 6, "blocks": 1, "steals": 2]),
        Tier(name: "Gold II",    minPoints: 451, maxPoints: 500,
             averages: ["points": 9,  "rebounds": 5, "assists": 3, "blocks": 1, "steals": 2]),
        // No upper bound: previously anything over 550 RP fell through every
        // bracket and displayed as "Unranked". Gold I is now the uncapped top tier.
        Tier(name: "Gold I",     minPoints: 501, maxPoints: Int64.max,
             averages: ["points": 13, "rebounds": 7, "assists": 2, "blocks": 0, "steals": 3])
    ]

    static var allRankNames: [String] { tiers.map { $0.name } }

    /// The tier name for a given rank-points total.
    static func rankName(for points: Int64) -> String {
        tiers.first(where: { points >= $0.minPoints && points <= $0.maxPoints })?.name ?? "Unranked"
    }

    /// The stat averages a player is compared against for their current rank.
    static func averages(for rankName: String) -> [String: Int64] {
        tiers.first(where: { $0.name == rankName })?.averages ?? [:]
    }

    /// Ordering index, low → high (0 = Rookie ... 9 = Gold I). `nil` if the name isn't a known tier.
    static func index(of rankName: String) -> Int? {
        tiers.firstIndex(where: { $0.name == rankName })
    }
}
