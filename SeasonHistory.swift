import Foundation
import CoreData

/// Season history: the final-standings snapshot taken when a season ends, and a player's stats
/// for any season. RP isn't kept per season (a new season soft-resets it), so each player's
/// final RP and finishing position are saved as a `SeasonResult` at rollover.
enum SeasonHistory {

    /// Saves every Competitive player's (and anyone who played that season's) final RP, rank and
    /// leaderboard position for `season`. Call before the soft reset. Does not save. Safe to call
    /// twice: an existing snapshot for the season is left alone.
    static func snapshot(_ season: Season, now: Date = Date(), in context: NSManagedObjectContext) {
        guard ((season.results as? Set<SeasonResult>) ?? []).isEmpty else { return }
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        let players = ((try? context.fetch(request)) ?? []).filter { player in
            AppConstants.isRanked(player.membership) || !games(of: player, in: season).isEmpty
        }
        let entries = players.map {
            SeasonStandings.Entry(id: $0.username ?? "", rankPoints: $0.rankPoints,
                                  isPlaced: AppConstants.isRanked($0.membership) && $0.placementGamesRemaining <= 0)
        }
        let positions = SeasonStandings.positions(entries)
        let rankedCount = positions.count

        for player in players {
            let result = SeasonResult(context: context)
            result.id = UUID()
            result.player = player
            result.season = season
            result.finalRankPoints = player.rankPoints
            result.finalRank = RankSystem.rankName(for: player.rankPoints)
            result.position = Int64(positions[player.username ?? ""] ?? 0)
            result.rankedPlayerCount = Int64(rankedCount)
            result.wasInPlacement = player.placementGamesRemaining > 0
            result.recordedAt = now
        }
    }

    /// The player's ranked games in a season.
    static func games(of player: Player, in season: Season) -> [Game] {
        ((player.games as? Set<Game>) ?? []).filter { $0.match?.season == season }
    }

    static func stats(of player: Player, in season: Season) -> SeasonStats {
        SeasonStats(games(of: player, in: season).map(line))
    }

    static func line(_ game: Game) -> SeasonStats.GameLine {
        SeasonStats.GameLine(points: game.points, rebounds: game.rebounds, assists: game.assists,
                             blocks: game.blocks, steals: game.steals, won: game.won, award: game.award,
                             rpDelta: game.rpDelta, isPlacement: game.isPlacement)
    }

    /// Game nights the player was checked in at during a season.
    static func nightsAttended(by player: Player, in season: Season) -> Int {
        ((player.rsvps as? Set<RSVP>) ?? []).filter { $0.checkedInAt != nil && $0.gameNight?.season == season }.count
    }

    static func result(of player: Player, in season: Season) -> SeasonResult? {
        ((player.seasonResults as? Set<SeasonResult>) ?? []).first { $0.season == season }
    }

    /// The seasons a player has history in (games or a final result), plus the active season
    /// for ranked players, newest first.
    static func seasons(for player: Player, in context: NSManagedObjectContext) -> [Season] {
        SeasonManager.allSeasons(in: context).filter { season in
            (season.isActive && AppConstants.isRanked(player.membership))
                || result(of: player, in: season) != nil
                || !games(of: player, in: season).isEmpty
        }
    }

    /// A finished season's final standings: placed players by position, then the rest by RP.
    static func finalStandings(of season: Season) -> [SeasonResult] {
        ((season.results as? Set<SeasonResult>) ?? []).sorted { lhs, rhs in
            switch (lhs.position > 0, rhs.position > 0) {
            case (true, true): return lhs.position < rhs.position
            case (true, false): return true
            case (false, true): return false
            case (false, false):
                return lhs.finalRankPoints != rhs.finalRankPoints ? lhs.finalRankPoints > rhs.finalRankPoints
                    : (lhs.player?.username ?? "") < (rhs.player?.username ?? "")
            }
        }
    }
}
