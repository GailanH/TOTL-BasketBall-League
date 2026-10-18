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
            p(.a, 10, 5, 4, 1, 2),  // perf 22, winner, MVP → 22 + 10
            p(.a, 5, 3, 2, 0, 1),   // perf 0, winner → minimum 5
            p(.b, 9, 4, 3, 0, 1),   // perf 12, best loser (SVP) → capped at 5
            p(.b, 0, 0, 0, 0, 0)    // perf -11, loser → -11
        ], winner: .a)

        XCTAssertEqual(outcomes.map(\.rpChange), [32, 5, 5, -11])
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
            p(.b, 2, 1, 1, 0, 0),   // perf -7, still the best loser
            p(.b, 0, 0, 0, 0, 0)    // perf -11
        ], winner: .a)
        XCTAssertEqual(outcomes.map(\.rpChange), [45, -7, -11])
        XCTAssertEqual(outcomes[1].award, .svp)
    }

    func testWinnerGainIsCapped() {
        let outcomes = MatchScoring.score([p(.a, 99, 99, 99, 99, 99), p(.b, 5, 3, 2, 0, 1)], winner: .a)
        XCTAssertEqual(outcomes[0].rpChange, CompetitiveRules.gameGainCap)
    }

    func testPlacementDoublesGainsAndLosses() {
        let outcomes = MatchScoring.score([
            p(.a, 10, 5, 4, 1, 2, placement: true),
            p(.b, 0, 0, 0, 0, 0, placement: true)
        ], winner: .a)
        XCTAssertEqual(outcomes.map(\.rpChange), [64, -22])
    }

    /// MVP is judged against each player's own tier, not raw stats, so a lower-ranked player
    /// who outplays their level can beat a higher-ranked player with bigger raw numbers.
    func testMVPUsesPerformanceAgainstOwnTier() {
        let outcomes = MatchScoring.score([
            p(.a, 18, 9, 6, 2, 4, rank: "Elite"),   // exactly Elite average → perf 0
            p(.a, 10, 5, 3, 1, 2, rank: "Rookie"),  // well above Rookie → perf 20
            p(.b, 5, 3, 2, 0, 1)
        ], winner: .a)
        XCTAssertNil(outcomes[0].award)
        XCTAssertEqual(outcomes[1].award, .mvp)
        XCTAssertEqual(outcomes.map(\.rpChange), [5, 30, 0])
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
}
