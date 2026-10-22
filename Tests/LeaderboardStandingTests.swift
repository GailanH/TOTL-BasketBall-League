import XCTest
@testable import Project_Comp_B

final class LeaderboardStandingTests: XCTestCase {

    private let ranking: [(username: String, rankPoints: Int64)] = [
        ("ace", 748), ("bo", 677), ("cy", 629), ("di", 403), ("ed", 380)
    ]

    func testMiddleOfTheTable() {
        let s = LeaderboardStanding(ranking: ranking, index: 3)!
        XCTAssertEqual(s.place, 4)
        XCTAssertEqual(s.totalPlayers, 5)
        XCTAssertEqual(s.rank, "Gold III")
        XCTAssertEqual(s.above, .init(place: 3, username: "cy", gap: 226))
        XCTAssertEqual(s.below, .init(place: 5, username: "ed", gap: 23))
        XCTAssertEqual(s.nextTier?.name, "Gold II")
        XCTAssertEqual(s.nextTier?.rpToGo, 48)
        XCTAssertEqual(s.tierProgress, 2.0 / 50.0, accuracy: 0.001)
    }

    func testFirstPlaceHasNobodyAboveAndEliteHasNoNextTier() {
        let s = LeaderboardStanding(ranking: ranking, index: 0)!
        XCTAssertNil(s.above)
        XCTAssertEqual(s.below?.gap, 71)
        XCTAssertNil(s.nextTier)
        XCTAssertEqual(s.tierProgress, 1)
    }

    func testLastPlaceHasNobodyBelow() {
        XCTAssertNil(LeaderboardStanding(ranking: ranking, index: 4)!.below)
    }

    func testRookieProgressUsesTheWideFirstTier() {
        let s = LeaderboardStanding(ranking: [("new", 50)], index: 0)!
        XCTAssertEqual(s.nextTier?.name, "Bronze III")
        XCTAssertEqual(s.nextTier?.rpToGo, 51)
        XCTAssertEqual(s.tierProgress, 50.0 / 101.0, accuracy: 0.001)
    }

    func testOutOfRangeIsNil() {
        XCTAssertNil(LeaderboardStanding(ranking: ranking, index: 9))
    }
}
