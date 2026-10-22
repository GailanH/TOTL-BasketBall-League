import Foundation

/// A player's RP after every ranked game in a season: the data behind the Rank Timeline chart.
///
/// RP isn't stored per game, only each game's change (`Game.rpDelta`). The journey is rebuilt
/// backwards from the player's current RP, which works within one season because nothing but
/// games changes RP mid-season (season resets only happen at a season boundary).
struct RankJourney: Equatable {

    struct Point: Equatable, Identifiable {
        let date: Date
        let rankPoints: Int64
        /// Change from the previous point (0 for the starting point).
        let delta: Int64
        let won: Bool?
        let award: String?
        let isPlacement: Bool
        var id: Date { date }
        var rank: String { RankSystem.rankName(for: rankPoints) }
    }

    struct GameStep {
        let date: Date
        let rpDelta: Int64
        let won: Bool
        let award: String?
        let isPlacement: Bool
    }

    /// The starting point followed by one point per game, oldest first.
    let points: [Point]

    var startRank: String? { points.first?.rank }
    var currentRank: String? { points.last?.rank }
    var peak: Point? { points.max { $0.rankPoints < $1.rankPoints } }

    /// - Parameters:
    ///   - games: the season's games, any order.
    ///   - currentRP: the player's RP now.
    ///   - seasonStart: when the season began; the starting point is placed there (or a day
    ///     before the first game, whichever is earlier).
    init(games: [GameStep], currentRP: Int64, seasonStart: Date?) {
        let ordered = games.sorted { $0.date < $1.date }
        let startRP = max(0, currentRP - ordered.reduce(0) { $0 + $1.rpDelta })

        var startDate = seasonStart ?? ordered.first?.date ?? Date()
        if let first = ordered.first?.date {
            startDate = min(startDate, first.addingTimeInterval(-86_400))
        }

        var result = [Point(date: startDate, rankPoints: startRP, delta: 0, won: nil, award: nil, isPlacement: false)]
        var running = startRP
        for game in ordered {
            running += game.rpDelta
            result.append(Point(date: game.date, rankPoints: running, delta: game.rpDelta,
                                won: game.won, award: game.award, isPlacement: game.isPlacement))
        }
        points = result
    }
}
