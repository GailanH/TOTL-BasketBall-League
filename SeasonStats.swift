import Foundation

/// A player's numbers for one season: record, awards, stat totals and per-game averages, net RP.
/// Pure (built from plain game lines), so it's unit-tested and moves to a backend unchanged.
struct SeasonStats: Equatable {

    /// One ranked game as the stats need it.
    struct GameLine: Equatable {
        var points: Int64 = 0
        var rebounds: Int64 = 0
        var assists: Int64 = 0
        var blocks: Int64 = 0
        var steals: Int64 = 0
        var won: Bool = false
        var award: String? = nil
        var rpDelta: Int64 = 0
        var isPlacement: Bool = false
    }

    let games: Int
    let wins: Int
    let mvps: Int
    let svps: Int
    let placementGames: Int
    let netRP: Int64
    let totals: Totals

    struct Totals: Equatable {
        var points: Int64 = 0
        var rebounds: Int64 = 0
        var assists: Int64 = 0
        var blocks: Int64 = 0
        var steals: Int64 = 0
    }

    var losses: Int { games - wins }
    var winRate: Double { games == 0 ? 0 : Double(wins) / Double(games) }

    /// Per-game averages, one decimal place when shown. Zero with no games.
    var averages: Averages {
        guard games > 0 else { return Averages() }
        let n = Double(games)
        return Averages(points: Double(totals.points) / n, rebounds: Double(totals.rebounds) / n,
                        assists: Double(totals.assists) / n, blocks: Double(totals.blocks) / n,
                        steals: Double(totals.steals) / n)
    }

    struct Averages: Equatable {
        var points = 0.0
        var rebounds = 0.0
        var assists = 0.0
        var blocks = 0.0
        var steals = 0.0

        /// (label, value) pairs in the app's usual stat order.
        var labelled: [(String, Double)] {
            [("PTS", points), ("REB", rebounds), ("AST", assists), ("BLK", blocks), ("STL", steals)]
        }
    }

    init(_ lines: [GameLine]) {
        games = lines.count
        wins = lines.filter(\.won).count
        mvps = lines.filter { $0.award == Award.mvp.rawValue }.count
        svps = lines.filter { $0.award == Award.svp.rawValue }.count
        placementGames = lines.filter(\.isPlacement).count
        netRP = lines.reduce(0) { $0 + $1.rpDelta }
        var t = Totals()
        for line in lines {
            t.points += line.points; t.rebounds += line.rebounds; t.assists += line.assists
            t.blocks += line.blocks; t.steals += line.steals
        }
        totals = t
    }

    static let empty = SeasonStats([])

    /// "12.4"
    static func format(_ value: Double) -> String { String(format: "%.1f", value) }
}

/// Final standings for a season: the same order as the leaderboard (placed Competitive
/// players by RP, highest first). Ties are broken by username so the order is stable.
enum SeasonStandings {

    struct Entry: Equatable {
        let id: String
        let rankPoints: Int64
        let isPlaced: Bool
    }

    /// Positions (1 = first) for placed players; players still in placement get none.
    static func positions(_ entries: [Entry]) -> [String: Int] {
        let placed = entries.filter(\.isPlaced).sorted {
            $0.rankPoints != $1.rankPoints ? $0.rankPoints > $1.rankPoints
                : $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
        }
        var result: [String: Int] = [:]
        for (index, entry) in placed.enumerated() { result[entry.id] = index + 1 }
        return result
    }
}
