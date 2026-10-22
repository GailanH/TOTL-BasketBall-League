import XCTest
import CoreData
@testable import Project_Comp_B

/// Recording, editing, deleting games and rolling seasons against an in-memory store.
final class MatchRecorderTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = PersistenceController(inMemory: true).container.viewContext
    }

    private func makePlayer(_ name: String, rp: Int64 = 50, placement: Int16 = 0,
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

    private func line(_ pts: Int64, _ reb: Int64, _ ast: Int64, _ blk: Int64, _ stl: Int64) -> StatLine {
        StatLine(points: pts, rebounds: reb, assists: ast, blocks: blk, steals: stl)
    }

    /// Players named so alphabetical order (used when re-scoring) matches listing order.
    private func recordBasicGame() throws -> [Player] {
        let players = [makePlayer("a1"), makePlayer("a2"), makePlayer("b1"), makePlayer("b2")]
        try MatchRecorder.record([
            MatchEntry(player: players[0], team: .a, stats: line(10, 5, 4, 1, 2)),
            MatchEntry(player: players[1], team: .a, stats: line(5, 3, 2, 0, 1)),
            MatchEntry(player: players[2], team: .b, stats: line(9, 4, 3, 0, 1)),
            MatchEntry(player: players[3], team: .b, stats: line(0, 0, 0, 0, 0))
        ], winner: .a, in: context)
        return players
    }

    func testRecordAppliesRPAndAwards() throws {
        let players = try recordBasicGame()
        XCTAssertEqual(players.map(\.rankPoints), [76, 60, 49, 25])

        let games = players.compactMap { ($0.games as? Set<Game>)?.first }
        XCTAssertEqual(games.map(\.rpDelta), [26, 10, -1, -25])
        XCTAssertEqual(games.map(\.award), ["MVP", nil, "SVP", nil])
        XCTAssertEqual(games.map(\.won), [true, true, false, false])
        XCTAssertNotNil(games.first?.match?.season, "First game should start Season 1")
        XCTAssertEqual(SeasonManager.activeSeason(in: context)?.number, 1)
    }

    func testRPNeverGoesBelowZeroAndDeltaReflectsTheFloor() throws {
        let winner = makePlayer("w"), loser = makePlayer("l", rp: 4)
        try MatchRecorder.record([
            MatchEntry(player: winner, team: .a, stats: line(5, 3, 2, 0, 1)),
            MatchEntry(player: loser, team: .b, stats: line(0, 0, 0, 0, 0))
        ], winner: .a, in: context)
        XCTAssertEqual(loser.rankPoints, 0)
        XCTAssertEqual((loser.games as? Set<Game>)?.first?.rpDelta, -4)
    }

    func testPlacementDoublesAndCountsDown() throws {
        let rookie = makePlayer("new", rp: 0, placement: 5)
        let other = makePlayer("other")
        try MatchRecorder.record([
            MatchEntry(player: rookie, team: .a, stats: line(10, 5, 4, 1, 2)),
            MatchEntry(player: other, team: .b, stats: line(5, 3, 2, 0, 1))
        ], winner: .a, in: context)
        XCTAssertEqual(rookie.rankPoints, 52)
        XCTAssertEqual(rookie.placementGamesRemaining, 4)
        XCTAssertEqual((rookie.games as? Set<Game>)?.first?.isPlacement, true)
    }

    func testCasualPlayersAreRejectedWithoutChanges() {
        let casual = makePlayer("casual", membership: AppConstants.casualMembership)
        let other = makePlayer("other")
        XCTAssertThrowsError(try MatchRecorder.record([
            MatchEntry(player: casual, team: .a, stats: line(5, 3, 2, 0, 1)),
            MatchEntry(player: other, team: .b, stats: line(5, 3, 2, 0, 1))
        ], winner: .a, in: context))
        XCTAssertEqual(other.rankPoints, 50)
        XCTAssertTrue((other.games as? Set<Game>)?.isEmpty ?? true)
    }

    func testOneTeamOnlyIsRejected() {
        let p = makePlayer("solo")
        XCTAssertThrowsError(try MatchRecorder.record([MatchEntry(player: p, team: .a, stats: line(5, 3, 2, 0, 1))], winner: .a, in: context))
    }

    func testDuplicatePlayerIsRejected() {
        let p = makePlayer("dup"), q = makePlayer("q")
        XCTAssertThrowsError(try MatchRecorder.record([
            MatchEntry(player: p, team: .a, stats: line(5, 3, 2, 0, 1)),
            MatchEntry(player: p, team: .b, stats: line(5, 3, 2, 0, 1)),
            MatchEntry(player: q, team: .b, stats: line(5, 3, 2, 0, 1))
        ], winner: .a, in: context))
    }

    func testEditingWithSameStatsChangesNothing() throws {
        let players = try recordBasicGame()
        let before = players.map(\.rankPoints)
        let game = (players[2].games as? Set<Game>)!.first!
        try MatchRecorder.updateStats(of: game, to: MatchRecorder.stats(of: game), in: context)
        XCTAssertEqual(players.map(\.rankPoints), before)
    }

    func testEditingCanMoveMVP() throws {
        let players = try recordBasicGame()
        let a2Game = (players[1].games as? Set<Game>)!.first!
        try MatchRecorder.updateStats(of: a2Game, to: line(20, 8, 5, 1, 2), in: context)  // perf 35 > a1's 22
        XCTAssertEqual(a2Game.award, "MVP")
        XCTAssertNil((players[0].games as? Set<Game>)!.first!.award)
        XCTAssertEqual(players[0].rankPoints, 50 + 21)
        XCTAssertEqual(players[1].rankPoints, 50 + 32)
    }

    func testDeletingLastPlayerOnATeamRemovesTheWholeGame() throws {
        let a = makePlayer("a", placement: 5), b = makePlayer("b", placement: 5)
        try MatchRecorder.record([
            MatchEntry(player: a, team: .a, stats: line(10, 5, 4, 1, 2)),
            MatchEntry(player: b, team: .b, stats: line(0, 0, 0, 0, 0))
        ], winner: .a, in: context)
        XCTAssertNotEqual(a.rankPoints, 50)

        try MatchRecorder.delete((b.games as? Set<Game>)!.first!, in: context)
        try context.save()

        XCTAssertEqual(a.rankPoints, 50)
        XCTAssertEqual(b.rankPoints, 50)
        XCTAssertEqual(a.placementGamesRemaining, 5)
        XCTAssertEqual(b.placementGamesRemaining, 5)
        let matches: NSFetchRequest<Match> = Match.fetchRequest()
        let games: NSFetchRequest<Game> = Game.fetchRequest()
        XCTAssertEqual(try context.count(for: matches), 0)
        XCTAssertEqual(try context.count(for: games), 0)
    }

    func testDeletingOneLineRescoresTheRest() throws {
        let players = try recordBasicGame()
        // Remove a1 (the MVP). a2 becomes the only winner and MVP: win 10 + MVP 5 = 15.
        try MatchRecorder.delete((players[0].games as? Set<Game>)!.first!, in: context)
        XCTAssertEqual(players[0].rankPoints, 50)
        XCTAssertEqual(players[1].rankPoints, 65)
        XCTAssertEqual((players[1].games as? Set<Game>)!.first!.award, "MVP")
    }

    // MARK: Seasons

    func testNewSeasonSoftResetsAndRestoresPlacement() throws {
        SeasonManager.ensureActiveSeason(in: context)
        let gold = makePlayer("gold", rp: 480)
        let rookie = makePlayer("rookie", rp: 40)
        try context.save()

        let season2 = try SeasonManager.startNewSeason(in: context)

        XCTAssertEqual(season2.number, 2)
        XCTAssertEqual(SeasonManager.activeSeason(in: context), season2)
        XCTAssertEqual(SeasonManager.allSeasons(in: context).filter(\.isActive).count, 1)
        XCTAssertEqual(gold.rankPoints, 301)
        XCTAssertEqual(rookie.rankPoints, 0)
        XCTAssertEqual(gold.placementGamesRemaining, CompetitiveRules.placementGames)
        XCTAssertEqual(gold.lastRank, "Silver II")
        let resetChange = (gold.rankChanges as? Set<RankChange>)?.first { $0.reason == RankChangeReason.seasonReset.rawValue }
        XCTAssertEqual(resetChange?.season, season2)
    }

    func testGamesFromFinishedSeasonsAreLocked() throws {
        let players = try recordBasicGame()
        try context.save()
        try SeasonManager.startNewSeason(in: context)
        let oldGame = (players[0].games as? Set<Game>)!.first!
        XCTAssertFalse(MatchRecorder.isEditable(oldGame, in: context))
        XCTAssertThrowsError(try MatchRecorder.delete(oldGame, in: context))
    }
}
