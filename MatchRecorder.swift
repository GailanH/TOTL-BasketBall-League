import Foundation
import CoreData

/// One player's line in a game being recorded.
struct MatchEntry {
    let player: Player
    let team: Team
    let stats: StatLine
}

enum RankChangeReason: String {
    case game
    case seasonReset
}

/// The only code that changes a player's RP from games. The manual form, the CSV importer,
/// game edits, and game deletes all go through here so they always agree.
///
/// RP changes are stored per game (`Game.rpDelta`), so a game can be reversed exactly. Editing
/// or deleting a game re-scores its whole game (MVP/SVP can move). That re-score uses each
/// player's rank as it was without this game. Later games aren't replayed, so it's exact for the
/// most recent game and a close approximation for older ones.
enum MatchRecorder {

    enum RecordError: LocalizedError {
        case lineup(String)
        case duplicatePlayer(String)
        case notCompetitive(String)
        case invalidStats(String, String)
        case pastSeason

        var errorDescription: String? {
            switch self {
            case .lineup(let message): return message
            case .duplicatePlayer(let name): return "\(name) is listed more than once."
            case .notCompetitive(let name): return "\(name) isn't a Competitive member. Only Competitive members play ranked games."
            case .invalidStats(let name, let message): return "\(name): \(message)"
            case .pastSeason: return "This game belongs to a finished season and can't be changed."
            }
        }
    }

    struct PlayerResult {
        let player: Player
        let won: Bool
        let award: Award?
        let rpDelta: Int64
        let newRank: String
        let rankChanged: Bool
        /// Underdog bonus RP included in `rpDelta` (0 unless they won an underdog win).
        let underdogBonus: Int64
    }

    // MARK: Record

    /// Validates, scores, and records one game. Does not save; the caller saves (so a CSV batch
    /// can save once). Throws without changing anything if the line-up or stats are invalid.
    @discardableResult
    static func record(
        _ entries: [MatchEntry], winner: Team, date: Date = Date(), gameNightID: UUID? = nil,
        in context: NSManagedObjectContext
    ) throws -> [PlayerResult] {
        try validate(entries)

        let season = SeasonManager.ensureActiveSeason(in: context, now: date)
        let match = Match(context: context)
        match.id = UUID()
        match.date = date
        match.winningTeam = winner.rawValue
        match.season = season
        if let gameNightID {
            let request: NSFetchRequest<GameNight> = GameNight.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", gameNightID as CVarArg)
            request.fetchLimit = 1
            match.gameNight = try context.fetch(request).first
        }

        for entry in entries {
            let game = Game(context: context)
            game.player = entry.player
            game.match = match
            game.date = date
            game.team = entry.team.rawValue
            game.points = entry.stats.points
            game.rebounds = entry.stats.rebounds
            game.assists = entry.stats.assists
            game.blocks = entry.stats.blocks
            game.steals = entry.stats.steals
            game.isPlacement = entry.player.placementGamesRemaining > 0
            game.rpDelta = 0
        }

        let ranksBefore = Dictionary(uniqueKeysWithValues: entries.map {
            ($0.player.objectID, RankSystem.rankName(for: $0.player.rankPoints))
        })
        apply(match)
        return finish(match, ranksBefore: ranksBefore, reason: .game, in: context)
    }

    static func validate(_ entries: [MatchEntry]) throws {
        var seen = Set<NSManagedObjectID>()
        for entry in entries {
            let name = entry.player.username ?? "A player"
            guard seen.insert(entry.player.objectID).inserted else { throw RecordError.duplicatePlayer(name) }
            guard AppConstants.isRanked(entry.player.membership) else { throw RecordError.notCompetitive(name) }
            let s = entry.stats
            if let message = GameStatBounds.validate(points: s.points, rebounds: s.rebounds, assists: s.assists, blocks: s.blocks, steals: s.steals) {
                throw RecordError.invalidStats(name, message)
            }
        }
        let lineup = entries.map {
            MatchScoring.Participant(team: $0.team, stats: $0.stats, rank: "Rookie", isPlacement: false)
        }
        if let message = MatchScoring.validate(lineup) { throw RecordError.lineup(message) }
    }

    // MARK: Edit / delete

    /// Whether staff may still edit or delete this game. Games from finished seasons are
    /// locked: their RP was already soft-reset away, so reversing it would corrupt the current
    /// season. Games from before seasons existed stay editable during Season 1 only.
    static func isEditable(_ game: Game, in context: NSManagedObjectContext) -> Bool {
        if let season = game.match?.season { return season.isActive }
        let seasons = SeasonManager.allSeasons(in: context)
        return seasons.count <= 1
    }

    /// Replaces one player's stats and re-scores the game. Does not save.
    static func updateStats(of game: Game, to stats: StatLine, in context: NSManagedObjectContext) throws {
        guard isEditable(game, in: context) else { throw RecordError.pastSeason }
        let name = game.player?.username ?? "This player"
        if let message = GameStatBounds.validate(points: stats.points, rebounds: stats.rebounds, assists: stats.assists, blocks: stats.blocks, steals: stats.steals) {
            throw RecordError.invalidStats(name, message)
        }

        guard let match = game.match else {
            // Legacy game recorded before teams/seasons: score it alone, no win/loss.
            let ranksBefore = legacyUnapply(game)
            write(stats, to: game)
            legacyApply(game)
            if let player = game.player {
                recordRankChangeIfNeeded(for: player, from: ranksBefore, season: SeasonManager.activeSeason(in: context), reason: .game, date: Date(), in: context)
            }
            return
        }

        let ranksBefore = unapply(match)
        write(stats, to: game)
        apply(match)
        _ = finish(match, ranksBefore: ranksBefore, reason: .game, in: context)
    }

    /// Removes one player's line from a game and re-scores the rest. If that leaves a team
    /// empty, the whole game is removed and everyone's RP from it is reversed. Does not save.
    static func delete(_ game: Game, in context: NSManagedObjectContext) throws {
        guard isEditable(game, in: context) else { throw RecordError.pastSeason }

        guard let match = game.match else {
            let rankBefore = legacyUnapply(game)
            let player = game.player
            context.delete(game)
            if let player {
                recordRankChangeIfNeeded(for: player, from: rankBefore, season: SeasonManager.activeSeason(in: context), reason: .game, date: Date(), in: context)
            }
            return
        }

        let season = match.season
        let ranksBefore = unapply(match)
        let removedPlayer = game.player
        game.match = nil
        context.delete(game)

        let remaining = games(in: match).filter { $0 != game }
        let stillPlayable = Team.allCases.allSatisfy { team in remaining.contains { $0.team == team.rawValue } }
        var playersNotYetChecked = remaining.compactMap(\.player)
        if stillPlayable {
            apply(match)
            _ = finish(match, ranksBefore: ranksBefore, reason: .game, in: context)
            playersNotYetChecked = []
        } else {
            context.delete(match)  // cascades to the remaining lines
        }
        if let removedPlayer { playersNotYetChecked.append(removedPlayer) }
        for player in playersNotYetChecked {
            if let before = ranksBefore[player.objectID] {
                recordRankChangeIfNeeded(for: player, from: before, season: season, reason: .game, date: Date(), in: context)
            }
        }
    }

    // MARK: Internals

    static func games(in match: Match) -> [Game] {
        ((match.games as? Set<Game>) ?? [])
            .sorted { ($0.player?.username ?? "") < ($1.player?.username ?? "") }
    }

    /// Scores every game line in `match` from the players' current RP and applies the result.
    private static func apply(_ match: Match) {
        let lines = games(in: match)
        let winner = Team(rawValue: match.winningTeam ?? "") ?? .a
        let participants = lines.map { game in
            MatchScoring.Participant(
                team: Team(rawValue: game.team ?? "") ?? .a,
                stats: stats(of: game),
                rank: RankSystem.rankName(for: game.player?.rankPoints ?? 0),
                isPlacement: game.isPlacement
            )
        }
        let outcomes = MatchScoring.score(participants, winner: winner)

        for (game, outcome) in zip(lines, outcomes) {
            game.won = outcome.won
            game.award = outcome.award?.rawValue
            guard let player = game.player else { game.rpDelta = 0; continue }
            let old = player.rankPoints
            player.rankPoints = max(0, old + outcome.rpChange)
            // Store the real change (the 0 floor can clamp it) so it reverses exactly.
            game.rpDelta = player.rankPoints - old
            if game.isPlacement {
                player.placementGamesRemaining = max(0, player.placementGamesRemaining - 1)
            }
        }
    }

    /// Reverses every line's stored RP change and placement use. Returns each player's rank
    /// before the reversal (that is, their rank as currently displayed).
    private static func unapply(_ match: Match) -> [NSManagedObjectID: String] {
        var ranksBefore: [NSManagedObjectID: String] = [:]
        for game in games(in: match) {
            guard let player = game.player else { continue }
            ranksBefore[player.objectID] = RankSystem.rankName(for: player.rankPoints)
            player.rankPoints = max(0, player.rankPoints - game.rpDelta)
            if game.isPlacement {
                player.placementGamesRemaining = min(CompetitiveRules.placementGames, player.placementGamesRemaining + 1)
            }
            game.rpDelta = 0
        }
        return ranksBefore
    }

    private static func finish(
        _ match: Match, ranksBefore: [NSManagedObjectID: String], reason: RankChangeReason, in context: NSManagedObjectContext
    ) -> [PlayerResult] {
        // Whether this was an underdog win, judged on ranks going into the game.
        let lines = games(in: match)
        let winner = Team(rawValue: match.winningTeam ?? "") ?? .a
        let underdogGap = MatchScoring.underdogGap(lines.map { game in
            MatchScoring.Participant(
                team: Team(rawValue: game.team ?? "") ?? .a,
                stats: stats(of: game),
                rank: game.player.flatMap { ranksBefore[$0.objectID] } ?? "Rookie",
                isPlacement: game.isPlacement
            )
        }, winner: winner)

        return lines.compactMap { game in
            guard let player = game.player else { return nil }
            let before = ranksBefore[player.objectID] ?? RankSystem.rankName(for: player.rankPoints)
            let changed = recordRankChangeIfNeeded(
                for: player, from: before, season: match.season, reason: reason, date: match.date ?? Date(), in: context
            )
            return PlayerResult(
                player: player,
                won: game.won,
                award: game.award.flatMap(Award.init(rawValue:)),
                rpDelta: game.rpDelta,
                newRank: RankSystem.rankName(for: player.rankPoints),
                rankChanged: changed,
                underdogBonus: game.won ? MatchScoring.underdogBonus(forGap: underdogGap) : 0
            )
        }
    }

    private static func legacyUnapply(_ game: Game) -> String {
        guard let player = game.player else { return "Rookie" }
        let before = RankSystem.rankName(for: player.rankPoints)
        player.rankPoints = max(0, player.rankPoints - game.rpDelta)
        game.rpDelta = 0
        return before
    }

    private static func legacyApply(_ game: Game) {
        guard let player = game.player, AppConstants.isRanked(player.membership) else { game.rpDelta = 0; return }
        let gain = RankSystem.baseRP(stats(of: game), at: RankSystem.rankName(for: player.rankPoints))
        let old = player.rankPoints
        player.rankPoints = max(0, old + gain)
        game.rpDelta = player.rankPoints - old
    }

    static func stats(of game: Game) -> StatLine {
        StatLine(points: game.points, rebounds: game.rebounds, assists: game.assists, blocks: game.blocks, steals: game.steals)
    }

    private static func write(_ stats: StatLine, to game: Game) {
        game.points = stats.points
        game.rebounds = stats.rebounds
        game.assists = stats.assists
        game.blocks = stats.blocks
        game.steals = stats.steals
    }

    /// Adds a RankChange (and updates `lastRank`) if the player's tier differs from `oldRank`.
    @discardableResult
    static func recordRankChangeIfNeeded(
        for player: Player, from oldRank: String, season: Season?, reason: RankChangeReason, date: Date, in context: NSManagedObjectContext
    ) -> Bool {
        let newRank = RankSystem.rankName(for: player.rankPoints)
        guard newRank != oldRank else { return false }
        let change = RankChange(context: context)
        change.id = UUID()
        change.date = date
        change.newRank = newRank
        change.reason = reason.rawValue
        change.season = season
        change.player = player
        player.lastRank = newRank
        return true
    }
}
