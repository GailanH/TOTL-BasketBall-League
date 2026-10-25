import XCTest
import CoreData
@testable import Project_Comp_B

final class SeasonStatsTests: XCTestCase {

    func testTotalsAveragesRecordAndAwards() {
        let stats = SeasonStats([
            .init(points: 10, rebounds: 5, assists: 4, blocks: 1, steals: 2, won: true, award: "MVP", rpDelta: 20),
            .init(points: 6, rebounds: 3, assists: 1, blocks: 0, steals: 1, won: false, award: "SVP", rpDelta: -4),
            .init(points: 8, rebounds: 4, assists: 4, blocks: 2, steals: 0, won: true, rpDelta: 10, isPlacement: true)
        ])
        XCTAssertEqual(stats.games, 3)
        XCTAssertEqual(stats.wins, 2)
        XCTAssertEqual(stats.losses, 1)
        XCTAssertEqual(stats.mvps, 1)
        XCTAssertEqual(stats.svps, 1)
        XCTAssertEqual(stats.placementGames, 1)
        XCTAssertEqual(stats.netRP, 26)
        XCTAssertEqual(stats.totals.points, 24)
        XCTAssertEqual(stats.averages.points, 8, accuracy: 0.0001)
        XCTAssertEqual(stats.averages.rebounds, 4, accuracy: 0.0001)
        XCTAssertEqual(stats.averages.assists, 3, accuracy: 0.0001)
        XCTAssertEqual(SeasonStats.format(stats.averages.blocks), "1.0")
        XCTAssertEqual(stats.winRate, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testNoGamesMeansZeroesNotNaN() {
        XCTAssertEqual(SeasonStats.empty.averages, SeasonStats.Averages())
        XCTAssertEqual(SeasonStats.empty.winRate, 0)
    }

    func testStandingsSkipPlacementAndBreakTiesByName() {
        let positions = SeasonStandings.positions([
            .init(id: "zed", rankPoints: 300, isPlaced: true),
            .init(id: "amy", rankPoints: 300, isPlaced: true),
            .init(id: "top", rankPoints: 500, isPlaced: true),
            .init(id: "new", rankPoints: 900, isPlaced: false)
        ])
        XCTAssertEqual(positions, ["top": 1, "amy": 2, "zed": 3])
    }
}

/// Final standings saved at rollover, per-season stats, and the season-scoped journey.
final class SeasonHistoryTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = PersistenceController(inMemory: true).container.viewContext
    }

    private func makePlayer(_ name: String, rp: Int64, placement: Int16 = 0,
                            membership: String = AppConstants.competitiveMembership) -> Player {
        let player = Player(context: context)
        player.username = name
        player.email = "\(name)@example.com"
        player.role = AppConstants.playerRole
        player.membership = membership
        player.rankPoints = rp
        player.placementGamesRemaining = placement
        return player
    }

    private func line(_ pts: Int64) -> StatLine { StatLine(points: pts, rebounds: 4, assists: 3, blocks: 1, steals: 1) }

    func testNewSeasonSavesFinalStandingsBeforeTheReset() throws {
        let top = makePlayer("top", rp: 620)
        let mid = makePlayer("mid", rp: 410)
        let low = makePlayer("low", rp: 150)
        let rookie = makePlayer("rookie", rp: 80, placement: 3)
        let casual = makePlayer("casual", rp: 0, membership: AppConstants.casualMembership)
        try MatchRecorder.record([
            MatchEntry(player: top, team: .a, stats: line(14)),
            MatchEntry(player: low, team: .a, stats: line(6)),
            MatchEntry(player: mid, team: .b, stats: line(9)),
            MatchEntry(player: rookie, team: .b, stats: line(4))
        ], winner: .a, in: context)
        try context.save()
        let season1 = SeasonManager.activeSeason(in: context)!
        let topFinal = top.rankPoints, midFinal = mid.rankPoints

        let season2 = try SeasonManager.startNewSeason(in: context)

        let standings = SeasonHistory.finalStandings(of: season1)
        XCTAssertEqual(standings.map { $0.player?.username }, ["top", "mid", "low", "rookie"], "Casual members aren't in standings")
        XCTAssertEqual(standings[0].position, 1)
        XCTAssertEqual(standings[0].finalRankPoints, topFinal)
        XCTAssertEqual(standings[1].finalRankPoints, midFinal)
        XCTAssertEqual(standings[0].rankedPlayerCount, 3)
        XCTAssertEqual(standings[3].position, 0, "Players still in placement get no position")
        XCTAssertTrue(standings[3].wasInPlacement)
        XCTAssertNil(SeasonHistory.result(of: casual, in: season1))
        XCTAssertLessThan(top.rankPoints, topFinal, "Soft reset happened after the snapshot")

        // History lists both seasons for the ranked player, newest first.
        XCTAssertEqual(SeasonHistory.seasons(for: top, in: context).map(\.number), [season2.number, season1.number])
        XCTAssertEqual(SeasonHistory.stats(of: top, in: season1).games, 1)
        XCTAssertEqual(SeasonHistory.stats(of: top, in: season2).games, 0)
    }

    func testPastSeasonJourneyEndsAtTheSavedFinalRP() throws {
        let a = makePlayer("a", rp: 300), b = makePlayer("b", rp: 300)
        for winner in [Team.a, .a, .b] {
            try MatchRecorder.record([MatchEntry(player: a, team: .a, stats: line(10)),
                                      MatchEntry(player: b, team: .b, stats: line(10))], winner: winner, in: context)
        }
        try context.save()
        let season1 = SeasonManager.activeSeason(in: context)!
        let finalRP = a.rankPoints
        try SeasonManager.startNewSeason(in: context)

        let result = try XCTUnwrap(SeasonHistory.result(of: a, in: season1))
        let games = SeasonHistory.games(of: a, in: season1)
        let journey = RankJourney(
            games: games.map { RankJourney.GameStep(date: $0.date!, rpDelta: $0.rpDelta, won: $0.won, award: $0.award, isPlacement: $0.isPlacement) },
            currentRP: result.finalRankPoints, seasonStart: season1.startDate)
        XCTAssertEqual(journey.points.last?.rankPoints, finalRP)
        XCTAssertEqual(journey.points.first?.rankPoints, 300)
    }

    func testSnapshotIsOnlyTakenOnce() throws {
        _ = makePlayer("p", rp: 200)
        let season = SeasonManager.ensureActiveSeason(in: context)
        SeasonHistory.snapshot(season, in: context)
        SeasonHistory.snapshot(season, in: context)
        XCTAssertEqual((season.results as? Set<SeasonResult>)?.count, 1)
    }
}

/// Closing a night: no-shows, attendance, reopening.
final class CloseNightTests: XCTestCase {

    private var context: NSManagedObjectContext!
    private var store: CoreDataGameNightStore!
    private let venue = VenueRecord(name: "Gym", address: "1 Main St", courtCount: 2)
    private let nightID = UUID()
    private var start = Date()

    override func setUp() {
        super.setUp()
        context = PersistenceController(inMemory: true).container.viewContext
        store = CoreDataGameNightStore(context: context)
        try! store.saveVenue(venue)
        start = Date().addingTimeInterval(86_400)
        try! store.saveGameNight(GameNightRecord(id: nightID, venue: venue, startDate: start,
                                                 endDate: start.addingTimeInterval(7200), capacity: 4), createdBy: nil)
        for name in ["p1", "p2", "p3", "p4", "walker"] {
            let p = Player(context: context)
            p.username = name; p.email = "\(name)@x.com"; p.role = AppConstants.playerRole
            p.membership = AppConstants.competitiveMembership; p.rankPoints = 100
        }
        try! context.save()
        var t = Date()
        for name in ["p1", "p2", "p3", "p4"] { t += 1; try! store.rsvp(nightID: nightID, username: name, now: t) }
    }

    func testCloseMarksNoShowsAndSavesAttendance() throws {
        let during = start.addingTimeInterval(1800)
        XCTAssertThrowsError(try store.closeGameNight(id: nightID, now: start.addingTimeInterval(-60)), "Not started yet")
        try store.setCheckedIn(true, nightID: nightID, username: "p1", now: during)
        try store.setCheckedIn(true, nightID: nightID, username: "p2", now: during)
        try store.cancelRSVP(nightID: nightID, username: "p3", now: during)
        try store.addWalkIn(nightID: nightID, username: "walker", now: during)

        let summary = try store.closeGameNight(id: nightID, now: start.addingTimeInterval(7000))
        XCTAssertEqual(summary.attended, 3)
        XCTAssertEqual(summary.walkIns, 1)
        XCTAssertEqual(summary.noShows, 1, "p4 was confirmed and never checked in")
        XCTAssertEqual(summary.showRate, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(try store.gameNight(id: nightID)?.status, .completed)
        XCTAssertEqual(try store.gameNight(id: nightID)?.attendance, summary)
        XCTAssertEqual(try store.myRSVP(nightID: nightID, username: "p4"), .noShow)
        XCTAssertEqual(try store.roster(nightID: nightID).noShows.map(\.username), ["p4"])

        // Closed nights are read-only until reopened.
        XCTAssertThrowsError(try store.setCheckedIn(true, nightID: nightID, username: "p1", now: during))
        XCTAssertThrowsError(try store.closeGameNight(id: nightID, now: during))

        try store.reopenGameNight(id: nightID)
        XCTAssertEqual(try store.myRSVP(nightID: nightID, username: "p4"), .confirmed(checkedIn: false))
        XCTAssertNil(try store.gameNight(id: nightID)?.attendance)
        try store.setCheckedIn(true, nightID: nightID, username: "p4", now: during)
        XCTAssertEqual(try store.closeGameNight(id: nightID, now: during).noShows, 0)
    }

    func testNoShowsFollowThePlayerToLaterNights() throws {
        try store.closeGameNight(id: nightID, now: start.addingTimeInterval(60))  // nobody checked in
        let laterID = UUID()
        let later = start.addingTimeInterval(7 * 86_400)
        try store.saveGameNight(GameNightRecord(id: laterID, venue: venue, startDate: later,
                                                endDate: later.addingTimeInterval(7200)), createdBy: nil)
        try store.rsvp(nightID: laterID, username: "p1", now: Date())
        XCTAssertEqual(try store.roster(nightID: laterID).confirmed.first?.pastNoShows, 1)
    }
}
