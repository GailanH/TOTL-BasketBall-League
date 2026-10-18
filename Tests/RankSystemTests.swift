import XCTest
@testable import Project_Comp_B

final class RankSystemTests: XCTestCase {

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
        // Regression test: previously anything over the top tier's ceiling fell through
        // every bracket and displayed as "Unranked".
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

    func testIndexOfKnownTiers() {
        XCTAssertEqual(RankSystem.index(of: "Rookie"), 0)
        XCTAssertEqual(RankSystem.index(of: "Elite"), 13)
    }

    func testIndexOfUnknownTierIsNil() {
        XCTAssertNil(RankSystem.index(of: "Not A Real Rank"))
    }

    func testRpGainCapsAtPositive50() {
        let gain = RankSystem.rpGain(points: 999, rebounds: 999, assists: 999, blocks: 999, steals: 999, at: "Rookie")
        XCTAssertEqual(gain, 50)
    }

    func testRpGainCapsAtNegative20() {
        let gain = RankSystem.rpGain(points: 0, rebounds: 0, assists: 0, blocks: 0, steals: 0, at: "Gold I")
        XCTAssertEqual(gain, -20)
    }

    func testRpGainAtExactAverageIsZero() {
        let averages = RankSystem.averages(for: "Rookie")
        let gain = RankSystem.rpGain(
            points: averages["points"] ?? 0,
            rebounds: averages["rebounds"] ?? 0,
            assists: averages["assists"] ?? 0,
            blocks: averages["blocks"] ?? 0,
            steals: averages["steals"] ?? 0,
            at: "Rookie"
        )
        XCTAssertEqual(gain, 0)
    }

    func testAveragesForUnknownRankIsEmpty() {
        XCTAssertTrue(RankSystem.averages(for: "Nonsense").isEmpty)
    }
}
