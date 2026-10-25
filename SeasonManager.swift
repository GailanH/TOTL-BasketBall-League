import Foundation
import CoreData

/// Creates and rolls over seasons (D3: 3-month seasons, soft reset, placement games).
/// Seasons roll over when staff press "Start New Season". The app flags when the scheduled
/// end date has passed but never resets anyone's rank on its own.
enum SeasonManager {

    static func activeSeason(in context: NSManagedObjectContext) -> Season? {
        let request: NSFetchRequest<Season> = Season.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "number", ascending: false)]
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func allSeasons(in context: NSManagedObjectContext) -> [Season] {
        let request: NSFetchRequest<Season> = Season.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "number", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    /// The active season, creating Season 1 if none exists yet. Does not save.
    @discardableResult
    static func ensureActiveSeason(in context: NSManagedObjectContext, now: Date = Date()) -> Season {
        if let season = activeSeason(in: context) { return season }
        let latest = allSeasons(in: context).first?.number ?? 0
        return makeSeason(number: latest + 1, start: now, in: context)
    }

    static func scheduledEnd(from start: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: CompetitiveRules.seasonLengthMonths, to: start) ?? start
    }

    static func isPastScheduledEnd(_ season: Season, now: Date = Date()) -> Bool {
        guard let end = season.endDate else { return false }
        return now >= end
    }

    /// Ends the active season and starts the next one. Every player's RP is soft-reset
    /// (`RankSystem.softResetPoints`) and placement games are restored. Saves on success,
    /// rolls back on failure.
    @discardableResult
    static func startNewSeason(in context: NSManagedObjectContext, now: Date = Date()) throws -> Season {
        let previous = activeSeason(in: context)
        previous?.isActive = false
        previous?.endDate = now
        // Keep everyone's final RP and finishing position before the soft reset wipes it.
        if let previous { SeasonHistory.snapshot(previous, now: now, in: context) }

        let nextNumber = (allSeasons(in: context).first?.number ?? 0) + 1
        let season = makeSeason(number: nextNumber, start: now, in: context)

        let request: NSFetchRequest<Player> = Player.fetchRequest()
        let players = (try? context.fetch(request)) ?? []
        for player in players {
            let oldRank = RankSystem.rankName(for: player.rankPoints)
            player.rankPoints = RankSystem.softResetPoints(from: player.rankPoints)
            player.placementGamesRemaining = CompetitiveRules.placementGames
            MatchRecorder.recordRankChangeIfNeeded(
                for: player, from: oldRank, season: season, reason: .seasonReset, date: now, in: context
            )
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return season
    }

    private static func makeSeason(number: Int64, start: Date, in context: NSManagedObjectContext) -> Season {
        let season = Season(context: context)
        season.id = UUID()
        season.number = number
        season.name = "Season \(number)"
        season.startDate = start
        season.endDate = scheduledEnd(from: start)
        season.isActive = true
        return season
    }
}
