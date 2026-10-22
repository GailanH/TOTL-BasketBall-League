import XCTest
@testable import Project_Comp_B

/// Win/loss, MVP/SVP, and placement rules (ROADMAP D4). Expected numbers assume the default
/// values in `CompetitiveRules`. If you retune those, update these tests on purpose.
final class MatchScoringTests: XCTestCase {

    private func p(_ team: Team, _ pts: Int64, _ reb: Int64, _ ast: Int64, _ blk: Int64, _ stl: Int64,
                   rank: String = "Rookie", placement: Bool = false) -> MatchScoring.Participant {
        MatchScoring.Participant(team: team, stats: StatLine(points: pts, rebounds: reb, assists: ast, blocks: blk, steals: stl),
                                 rank: rank, isPlacement: placement)
    }

    func testBasicGame() {
        let outcomes = MatchScoring.score([
            p(.a, 10, 5, 4, 1, 2),  // perf 22: win 10 + 22/2 + MVP 5 = 26
            p(.a, 5, 3, 2, 0, 1),   // perf 0: win 10
            p(.b, 9, 4, 3, 0, 1),   // perf 12, best loser (SVP): -7 + 6 = -1
            p(.b, 0, 0, 0, 0, 0)    // perf -22 (stat score -20): -15 - 10 = -25
        ], winner: .a)

        XCTAssertEqual(outcomes.map(\.rpChange), [26, 10, -1, -25])
        XCTAssertEqual(outcomes.map(\.award), [.mvp, nil, .svp, nil])
        XCTAssertEqual(outcomes.map(\.won), [true, true, false, false])
    }

    func testEveryWinnerGains() {
        let outcomes = MatchScoring.score([p(.a, 0, 0, 0, 0, 0), p(.a, 0, 0, 0, 0, 0), p(.b, 0, 0, 0, 0, 0)], winner: .a)
        XCTAssertTrue(outcomes.filter(\.won).allSatisfy { $0.rpChange > 0 })
    }

    func testLosersOtherThanSVPNeverGain() {
        let outcomes = MatchScoring.score([
            p(.a, 30, 10, 8, 2, 3),
            p(.b, 20, 8, 6, 2, 3),  // SVP
            p(.b, 15, 6, 5, 1, 2)   // great game, but not SVP → 0
        ], winner: .a)
        XCTAssertEqual(outcomes[1].award, .svp)
        XCTAssertEqual(outcomes[1].rpChange, CompetitiveRules.svpMaxGain)
        XCTAssertEqual(outcomes[2].rpChange, 0)
    }

    /// If the whole losing team played badly, everyone loses RP, including the SVP.
    func testSVPLosesWhenEveryLoserPlayedBadly() {
        let outcomes = MatchScoring.score([
            p(.a, 20, 8, 5, 1, 2),
            p(.b, 2, 1, 1, 0, 0),   // perf -14, still the best loser: -7 - 7 = -14
            p(.b, 0, 0, 0, 0, 0)    // perf -22: -25
        ], winner: .a)
        XCTAssertEqual(outcomes.map(\.rpChange), [32, -14, -25])
        XCTAssertEqual(outcomes[1].award, .svp)
    }

    func testWinnerGainIsBounded() {
        // Stat score clamps at +50, counts half: 10 + 25 + MVP 5.
        let outcomes = MatchScoring.score([p(.a, 99, 99, 99, 99, 99), p(.b, 5, 3, 2, 0, 1)], winner: .a)
        XCTAssertEqual(outcomes[0].rpChange, 40)
    }

    /// The SVP can still gain a little with a great game, even though their team lost.
    func testGreatSVPGameCanGainALittle() {
        let outcomes = MatchScoring.score([
            p(.a, 5, 3, 2, 0, 1),
            p(.b, 30, 10, 8, 2, 3),
            p(.b, 0, 0, 0, 0, 0)
        ], winner: .a)
        XCTAssertEqual(outcomes.map(\.rpChange), [15, CompetitiveRules.svpMaxGain, -25])
    }

    /// The core anti-inflation property: losing costs more than winning earns at equal play.
    func testAverageLossCostsMoreThanAverageWinEarns() {
        let outcomes = MatchScoring.score([p(.a, 5, 3, 2, 0, 1), p(.a, 5, 3, 2, 0, 1),
                                           p(.b, 5, 3, 2, 0, 1), p(.b, 5, 3, 2, 0, 1)], winner: .a)
        XCTAssertEqual(outcomes.map(\.rpChange), [15, 10, -7, -15])
    }

    func testPlacementDoublesGainsAndLosses() {
        let outcomes = MatchScoring.score([
            p(.a, 10, 5, 4, 1, 2, placement: true),
            p(.b, 0, 0, 0, 0, 0, placement: true)
        ], winner: .a)
        XCTAssertEqual(outcomes.map(\.rpChange), [52, -34])
    }

    /// MVP is judged against each player's own tier, not raw stats, so a lower-ranked player
    /// who outplays their level can beat a higher-ranked player with bigger raw numbers.
    func testMVPUsesPerformanceAgainstOwnTier() {
        let outcomes = MatchScoring.score([
            p(.a, 18, 9, 6, 2, 4, rank: "Elite"),   // exactly Elite average → perf 0
            p(.a, 10, 5, 3, 1, 2, rank: "Rookie"),  // well above Rookie → perf 20 → 10 + 10 + 5
            p(.b, 5, 3, 2, 0, 1)
        ], winner: .a)
        XCTAssertNil(outcomes[0].award)
        XCTAssertEqual(outcomes[1].award, .mvp)
        XCTAssertEqual(outcomes.map(\.rpChange), [10, 25, -7])
    }

    func testTieGoesToMorePointsThenFirstListed() {
        // Same performance (each 1 rebound above average = +2), different points.
        let byPoints = MatchScoring.score([p(.a, 5, 4, 2, 0, 1), p(.a, 6, 3, 2, 0, 1), p(.b, 5, 3, 2, 0, 1)], winner: .a)
        XCTAssertEqual(byPoints[1].award, .mvp)

        let identical = MatchScoring.score([p(.a, 6, 3, 2, 0, 1), p(.a, 6, 3, 2, 0, 1), p(.b, 5, 3, 2, 0, 1)], winner: .a)
        XCTAssertEqual(identical[0].award, .mvp)
        XCTAssertNil(identical[1].award)
    }

    func testValidateRequiresBothTeams() {
        XCTAssertNotNil(MatchScoring.validate([p(.a, 1, 1, 1, 1, 1)]))
        XCTAssertNotNil(MatchScoring.validate([]))
        XCTAssertNil(MatchScoring.validate([p(.a, 1, 1, 1, 1, 1), p(.b, 1, 1, 1, 1, 1)]))
    }

    // MARK: Underdog wins

    private func atAverage(_ team: Team, _ rank: String) -> MatchScoring.Participant {
        let a = RankSystem.averages(for: rank)!
        return p(team, a.points, a.rebounds, a.assists, a.blocks, a.steals, rank: rank)
    }

    func testThreeSilversBeatingThreeGoldsIsAnUnderdogWin() {
        let lineup = [atAverage(.a, "Silver I"), atAverage(.a, "Silver I"), atAverage(.a, "Silver I"),
                      atAverage(.b, "Gold III"), atAverage(.b, "Gold III"), atAverage(.b, "Gold III")]
        XCTAssertTrue(MatchScoring.isUnderdogWin(lineup, winner: .a))
        let outcomes = MatchScoring.score(lineup, winner: .a)
        XCTAssertEqual(outcomes.map(\.rpChange), [20, 15, 15, -7, -15, -15])
        XCTAssertEqual(outcomes.map(\.underdogBonus), [5, 5, 5, 0, 0, 0])
    }

    func testOneGoldOnTheWinningTeamMeansNoUnderdogBonus() {
        let lineup = [atAverage(.a, "Silver I"), atAverage(.a, "Silver I"), atAverage(.a, "Gold III"),
                      atAverage(.b, "Gold III"), atAverage(.b, "Gold III"), atAverage(.b, "Gold III")]
        XCTAssertFalse(MatchScoring.isUnderdogWin(lineup, winner: .a))
        XCTAssertEqual(MatchScoring.score(lineup, winner: .a).map(\.rpChange), [10, 10, 15, -7, -15, -15])
    }

    func testFavoritesWinningIsNotAnUnderdogWin() {
        let lineup = [atAverage(.a, "Silver I"), atAverage(.b, "Gold III")]
        XCTAssertFalse(MatchScoring.isUnderdogWin(lineup, winner: .b))
    }

    func testMixedHigherTeamStillCountsWhenAllAreAboveTheWinners() {
        let lineup = [atAverage(.a, "Silver III"), atAverage(.a, "Silver I"), atAverage(.a, "Silver II"),
                      atAverage(.b, "Gold III"), atAverage(.b, "Gold I"), atAverage(.b, "Diamond III")]
        XCTAssertTrue(MatchScoring.isUnderdogWin(lineup, winner: .a))
    }

    func testTwoMetalGapPaysTen() {
        // Bronzes beat Golds: two metals apart.
        let lineup = [atAverage(.a, "Bronze I"), atAverage(.a, "Bronze II"),
                      atAverage(.b, "Gold III"), atAverage(.b, "Gold I")]
        XCTAssertEqual(MatchScoring.underdogGap(lineup, winner: .a), 2)
        let outcomes = MatchScoring.score(lineup, winner: .a)
        XCTAssertEqual(outcomes.map(\.underdogBonus), [10, 10, 0, 0])
        XCTAssertEqual(outcomes.map(\.rpChange), [25, 20, -7, -15])
    }

    func testBonusIsCappedAtTenForAnyGap() {
        // Rookies beat Diamonds: four metals apart, still +10.
        let lineup = [atAverage(.a, "Rookie"), atAverage(.b, "Diamond II")]
        XCTAssertEqual(MatchScoring.underdogGap(lineup, winner: .a), 4)
        XCTAssertEqual(MatchScoring.score(lineup, winner: .a).map(\.underdogBonus), [10, 0])
    }

    func testFavoritesLoseOnlyTheNormalAmount() {
        let underdog = MatchScoring.score([atAverage(.a, "Bronze I"), atAverage(.a, "Bronze I"),
                                           atAverage(.b, "Gold I"), atAverage(.b, "Gold I")], winner: .a)
        let even = MatchScoring.score([atAverage(.a, "Gold I"), atAverage(.a, "Gold I"),
                                       atAverage(.b, "Gold I"), atAverage(.b, "Gold I")], winner: .a)
        XCTAssertEqual(underdog[2...].map(\.rpChange), even[2...].map(\.rpChange))
    }
}
