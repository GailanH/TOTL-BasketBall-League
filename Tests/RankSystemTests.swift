import XCTest
@testable import Project_Comp_B

final class RankSystemTests: XCTestCase {

    // MARK: Tiers

    func testRookieAtZero() {
        XCTAssertEqual(RankSystem.rankName(for: 0), "Rookie")
    }

    func testRookieUpperBound() {
        XCTAssertEqual(RankSystem.rankName(for: 100), "Rookie")
    }

    func testBronzeIIILowerBound() {
        XCTAssertEqual(RankSystem.rankName(for: 101), "Bronze III")
    }

    func testGoldIIsCappedNowThatDiamondExists() {
        XCTAssertEqual(RankSystem.rankName(for: 501), "Gold I")
        XCTAssertEqual(RankSystem.rankName(for: 550), "Gold I")
        XCTAssertEqual(RankSystem.rankName(for: 551), "Diamond III")
    }

    func testEliteIsUncappedAtTop() {
        XCTAssertEqual(RankSystem.rankName(for: 701), "Elite")
        XCTAssertEqual(RankSystem.rankName(for: 10_000), "Elite")
        XCTAssertEqual(RankSystem.rankName(for: Int64.max), "Elite")
    }

    func testTierOrderingIsAscending() {
        let names = RankSystem.allRankNames
        XCTAssertEqual(names.first, "Rookie")
        XCTAssertEqual(names.last, "Elite")
        XCTAssertEqual(names.count, 14)
    }

    func testTiersAreContiguousAndFiftyWide() {
        let tiers = RankSystem.tiers
        for i in 1..<tiers.count {
            XCTAssertEqual(tiers[i].minPoints, tiers[i - 1].maxPoints + 1, "Gap before \(tiers[i].name)")
            if i < tiers.count - 1 {
                XCTAssertEqual(tiers[i].maxPoints - tiers[i].minPoints + 1, 50, "\(tiers[i].name) isn't 50 RP wide")
            }
        }
    }

    /// Climbing must never make RP easier to earn.
    func testAveragesNeverDecreaseWithRank() {
        let tiers = RankSystem.tiers
        for i in 1..<tiers.count {
            let lower = tiers[i - 1].averages, higher = tiers[i].averages
            XCTAssertGreaterThanOrEqual(higher.points, lower.points, tiers[i].name)
            XCTAssertGreaterThanOrEqual(higher.rebounds, lower.rebounds, tiers[i].name)
            XCTAssertGreaterThanOrEqual(higher.assists, lower.assists, tiers[i].name)
            XCTAssertGreaterThanOrEqual(higher.blocks, lower.blocks, tiers[i].name)
            XCTAssertGreaterThanOrEqual(higher.steals, lower.steals, tiers[i].name)
        }
    }

    func testIndexOfKnownTiers() {
        XCTAssertEqual(RankSystem.index(of: "Rookie"), 0)
        XCTAssertEqual(RankSystem.index(of: "Elite"), 13)
    }

    func testIndexOfUnknownTierIsNil() {
        XCTAssertNil(RankSystem.index(of: "Not A Real Rank"))
        XCTAssertNil(RankSystem.averages(for: "Nonsense"))
    }

    // MARK: Stat-line scoring

    func testExactAverageScoresZero() {
        let line = RankSystem.averages(for: "Rookie")!
        XCTAssertEqual(RankSystem.performanceScore(line, at: "Rookie"), 0)
        XCTAssertEqual(RankSystem.baseRP(line, at: "Rookie"), 0)
    }

    /// One huge stat is capped per stat, so it can't max out a game on its own.
    func testSingleStatIsCappedPerStat() {
        let line = StatLine(points: 40, rebounds: 3, assists: 2, blocks: 0, steals: 1)  // only points above Rookie avg
        XCTAssertEqual(RankSystem.baseRP(line, at: "Rookie"), CompetitiveRules.perStatGainCap)
    }

    func testBaseRPCapsAtGameGainCap() {
        let line = StatLine(points: 99, rebounds: 99, assists: 99, blocks: 99, steals: 99)
        XCTAssertEqual(RankSystem.performanceScore(line, at: "Rookie"), 75)
        XCTAssertEqual(RankSystem.baseRP(line, at: "Rookie"), CompetitiveRules.gameGainCap)
    }

    func testBaseRPCapsAtGameLossCap() {
        let line = StatLine()
        XCTAssertEqual(RankSystem.performanceScore(line, at: "Gold I"), -41)
        XCTAssertEqual(RankSystem.baseRP(line, at: "Gold I"), -CompetitiveRules.gameLossCap)
    }

    func testMixedLine() {
        // +5 pts (10), +2 reb (4), +2 ast (4), +1 blk (2), +1 stl (2) vs Rookie
        let line = StatLine(points: 10, rebounds: 5, assists: 4, blocks: 1, steals: 2)
        XCTAssertEqual(RankSystem.performanceScore(line, at: "Rookie"), 22)
    }

    // MARK: Soft reset

    func testSoftResetDropsThreeTiersToBottom() {
        XCTAssertEqual(RankSystem.softResetPoints(from: 480), 301)   // Gold II → Silver II
        XCTAssertEqual(RankSystem.softResetPoints(from: 5_000), 551) // Elite → Diamond III
        XCTAssertEqual(RankSystem.softResetPoints(from: 260), 101)   // Silver III → Bronze III
    }

    func testSoftResetNeverGoesBelowRookie() {
        XCTAssertEqual(RankSystem.softResetPoints(from: 0), 0)
        XCTAssertEqual(RankSystem.softResetPoints(from: 120), 0)     // Bronze III → Rookie
        XCTAssertEqual(RankSystem.softResetPoints(from: 210), 0)     // Bronze I → Rookie
    }
}

final class RankJourneyTests: XCTestCase {

    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: 1_790_000_000 + Double(n) * 86_400) }

    func testRebuildsRPBackwardsFromCurrent() {
        let journey = RankJourney(games: [
            .init(date: day(3), rpDelta: -10, won: false, award: nil, isPlacement: false),
            .init(date: day(1), rpDelta: 25, won: true, award: "MVP", isPlacement: false),
            .init(date: day(2), rpDelta: 5, won: true, award: nil, isPlacement: false)
        ], currentRP: 720, seasonStart: day(0))

        XCTAssertEqual(journey.points.map(\.rankPoints), [700, 725, 730, 720])
        XCTAssertEqual(journey.points.map(\.delta), [0, 25, 5, -10])
        XCTAssertEqual(journey.points.first?.date, day(0))
        XCTAssertEqual(journey.startRank, "Diamond I")
        XCTAssertEqual(journey.currentRank, "Elite")
        XCTAssertEqual(journey.peak?.rankPoints, 730)
    }

    func testStartPointIsBeforeFirstGameWhenSeasonStartsLate() {
        let journey = RankJourney(games: [.init(date: day(5), rpDelta: 10, won: true, award: nil, isPlacement: false)],
                                  currentRP: 60, seasonStart: day(9))
        XCTAssertEqual(journey.points.first?.date, day(4))
        XCTAssertEqual(journey.points.first?.rankPoints, 50)
    }

    func testNoGamesIsJustTheStartingPoint() {
        let journey = RankJourney(games: [], currentRP: 300, seasonStart: day(0))
        XCTAssertEqual(journey.points.count, 1)
    }
}
