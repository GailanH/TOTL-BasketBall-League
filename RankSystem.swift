import Foundation

/// One player's box-score line for a single game.
struct StatLine: Equatable {
    var points: Int64 = 0
    var rebounds: Int64 = 0
    var assists: Int64 = 0
    var blocks: Int64 = 0
    var steals: Int64 = 0
}

/// Single source of truth for the ranked-tier ladder: thresholds, per-tier stat averages,
/// ordering, and how a stat line is scored against a tier. Tunable numbers live in
/// `CompetitiveRules`; win/loss/MVP logic lives in `MatchScoring`.
enum RankSystem {

    struct Tier {
        let name: String
        let minPoints: Int64
        let maxPoints: Int64  // inclusive; the top tier has no real ceiling
        /// What a typical player at this tier produces per game. A game is scored against these.
        let averages: StatLine
    }

    /// Ordered lowest → highest. 50 RP per tier above Rookie (D2).
    /// Averages never decrease as rank goes up — climbing must never make RP easier to earn.
    /// They're starting values, to be tuned once real league data exists.
    static let tiers: [Tier] = [
        Tier(name: "Rookie",      minPoints: 0,   maxPoints: 100,       averages: StatLine(points: 5,  rebounds: 3, assists: 2, blocks: 0, steals: 1)),
        Tier(name: "Bronze III",  minPoints: 101, maxPoints: 150,       averages: StatLine(points: 6,  rebounds: 3, assists: 2, blocks: 0, steals: 1)),
        Tier(name: "Bronze II",   minPoints: 151, maxPoints: 200,       averages: StatLine(points: 7,  rebounds: 4, assists: 2, blocks: 0, steals: 1)),
        Tier(name: "Bronze I",    minPoints: 201, maxPoints: 250,       averages: StatLine(points: 8,  rebounds: 4, assists: 3, blocks: 0, steals: 1)),
        Tier(name: "Silver III",  minPoints: 251, maxPoints: 300,       averages: StatLine(points: 9,  rebounds: 4, assists: 3, blocks: 1, steals: 1)),
        Tier(name: "Silver II",   minPoints: 301, maxPoints: 350,       averages: StatLine(points: 10, rebounds: 5, assists: 3, blocks: 1, steals: 2)),
        Tier(name: "Silver I",    minPoints: 351, maxPoints: 400,       averages: StatLine(points: 11, rebounds: 5, assists: 3, blocks: 1, steals: 2)),
        Tier(name: "Gold III",    minPoints: 401, maxPoints: 450,       averages: StatLine(points: 12, rebounds: 5, assists: 4, blocks: 1, steals: 2)),
        Tier(name: "Gold II",     minPoints: 451, maxPoints: 500,       averages: StatLine(points: 13, rebounds: 6, assists: 4, blocks: 1, steals: 2)),
        Tier(name: "Gold I",      minPoints: 501, maxPoints: 550,       averages: StatLine(points: 14, rebounds: 6, assists: 4, blocks: 1, steals: 2)),
        Tier(name: "Diamond III", minPoints: 551, maxPoints: 600,       averages: StatLine(points: 15, rebounds: 7, assists: 4, blocks: 1, steals: 3)),
        Tier(name: "Diamond II",  minPoints: 601, maxPoints: 650,       averages: StatLine(points: 16, rebounds: 7, assists: 5, blocks: 2, steals: 3)),
        Tier(name: "Diamond I",   minPoints: 651, maxPoints: 700,       averages: StatLine(points: 17, rebounds: 8, assists: 5, blocks: 2, steals: 3)),
        // Uncapped top tier. Previously anything above the last ceiling displayed as "Unranked".
        Tier(name: "Elite",       minPoints: 701, maxPoints: Int64.max, averages: StatLine(points: 18, rebounds: 9, assists: 6, blocks: 2, steals: 4))
    ]

    static var allRankNames: [String] { tiers.map { $0.name } }

    /// The tier name for a given rank-points total.
    static func rankName(for points: Int64) -> String {
        tiers.first(where: { points >= $0.minPoints && points <= $0.maxPoints })?.name ?? "Unranked"
    }

    /// The stat averages for a rank, or `nil` if the name isn't a known tier.
    static func averages(for rankName: String) -> StatLine? {
        tiers.first(where: { $0.name == rankName })?.averages
    }

    /// The metal group of a tier, low → high: Rookie 0, Bronze 1, Silver 2, Gold 3, Diamond 4,
    /// Elite 5. Sub-levels (III, II, I) share their metal. `nil` for an unknown tier.
    static func metal(of rankName: String) -> Int? {
        guard index(of: rankName) != nil else { return nil }
        let metals = ["Rookie", "Bronze", "Silver", "Gold", "Diamond", "Elite"]
        return metals.firstIndex { rankName == $0 || rankName.hasPrefix($0 + " ") }
    }

    /// Ordering index, low → high (0 = Rookie ... 13 = Elite). `nil` if the name isn't a known tier.
    static func index(of rankName: String) -> Int? {
        tiers.firstIndex(where: { $0.name == rankName })
    }

    // MARK: Scoring a stat line

    /// How far above/below their tier a player performed: the sum of per-stat scores, each
    /// already capped by `CompetitiveRules.perStatGainCap` / `perStatLossCap`, with no
    /// per-game cap. Used to pick MVP/SVP, which compares players across different tiers fairly.
    static func performanceScore(_ line: StatLine, at rank: String) -> Int64 {
        let avg = averages(for: rank) ?? StatLine()
        return statScore(line.points, avg.points)
            + statScore(line.rebounds, avg.rebounds)
            + statScore(line.assists, avg.assists)
            + statScore(line.blocks, avg.blocks)
            + statScore(line.steals, avg.steals)
    }

    /// Performance clamped to the per-game range. Win/loss rules in `MatchScoring` start from this.
    static func baseRP(_ line: StatLine, at rank: String) -> Int64 {
        clamp(performanceScore(line, at: rank), -CompetitiveRules.gameLossCap, CompetitiveRules.gameGainCap)
    }

    static func statScore(_ value: Int64, _ average: Int64) -> Int64 {
        let difference = value - average
        if difference > 0 {
            return min(difference * CompetitiveRules.gainPerStatUnit, CompetitiveRules.perStatGainCap)
        } else if difference < 0 {
            return max(difference * CompetitiveRules.lossPerStatUnit, -CompetitiveRules.perStatLossCap)
        }
        return 0
    }

    // MARK: Season soft reset

    /// RP a player starts the next season with: down `CompetitiveRules.softResetTierDrop`
    /// tiers, at the bottom of that tier (never below Rookie / 0).
    static func softResetPoints(from points: Int64) -> Int64 {
        let current = index(of: rankName(for: points)) ?? 0
        let target = max(0, current - CompetitiveRules.softResetTierDrop)
        return tiers[target].minPoints
    }

    static func clamp(_ value: Int64, _ low: Int64, _ high: Int64) -> Int64 {
        min(max(value, low), high)
    }
}
