import XCTest
import CoreData
@testable import Project_Comp_B

final class RSVPPolicyTests: XCTestCase {

    private let venue = VenueRecord(name: "Gym", address: "1 Main St", courtCount: 2)
    private func night(startingIn hours: Double, from now: Date, capacity: Int16 = 10) -> GameNightRecord {
        let start = now.addingTimeInterval(hours * 3600)
        return GameNightRecord(venue: venue, startDate: start, endDate: start.addingTimeInterval(7200), capacity: capacity)
    }

    func testRSVPRules() {
        let now = Date()
        let n = night(startingIn: 24, from: now)
        XCTAssertNil(RSVPPolicy.refusalToRSVP(night: n, membership: "Competitive", alreadyActive: false, now: now))
        XCTAssertEqual(RSVPPolicy.refusalToRSVP(night: n, membership: "Competitive", alreadyActive: true, now: now), .alreadyIn)
        if LeagueSettings.rsvpRequiresCompetitive {
            XCTAssertEqual(RSVPPolicy.refusalToRSVP(night: n, membership: "Casual", alreadyActive: false, now: now), .notCompetitive)
        }
        var cancelled = n; cancelled.status = .cancelled
        XCTAssertEqual(RSVPPolicy.refusalToRSVP(night: cancelled, membership: "Competitive", alreadyActive: false, now: now), .cancelledNight)
    }

    func testRSVPsCloseAtTheCutoff() {
        let now = Date()
        let justBefore = night(startingIn: LeagueSettings.rsvpCutoff / 3600 + 0.1, from: now)
        let justAfter = night(startingIn: LeagueSettings.rsvpCutoff / 3600 - 0.1, from: now)
        XCTAssertNil(RSVPPolicy.refusalToRSVP(night: justBefore, membership: "Competitive", alreadyActive: false, now: now))
        XCTAssertEqual(RSVPPolicy.refusalToRSVP(night: justAfter, membership: "Competitive", alreadyActive: false, now: now), .closed)
    }

    func testCapacityWaitlistAndPromotions() {
        XCTAssertEqual(RSVPPolicy.statusForNewRSVP(confirmedCount: 9, capacity: 10), .confirmed)
        XCTAssertEqual(RSVPPolicy.statusForNewRSVP(confirmedCount: 10, capacity: 10), .waitlisted)
        XCTAssertEqual(RSVPPolicy.promotions(confirmedCount: 9, capacity: 10, waitlistCount: 3), 1)
        XCTAssertEqual(RSVPPolicy.promotions(confirmedCount: 6, capacity: 10, waitlistCount: 2), 2)
        XCTAssertEqual(RSVPPolicy.promotions(confirmedCount: 12, capacity: 10, waitlistCount: 2), 0)
    }

    func testAvailabilityText() {
        XCTAssertEqual(RSVPPolicy.availabilityText(capacity: 24, confirmedCount: 12, waitlistCount: 0), "12 of 24 spots left")
        XCTAssertEqual(RSVPPolicy.availabilityText(capacity: 10, confirmedCount: 10, waitlistCount: 3), "Full · 3 waiting")
        XCTAssertEqual(RSVPPolicy.availabilityText(capacity: 10, confirmedCount: 10, waitlistCount: 0), "Full")
    }

    func testCheckInWindow() {
        let now = Date()
        XCTAssertTrue(RSVPPolicy.checkInIsOpen(night: night(startingIn: 1, from: now), now: now))
        XCTAssertFalse(RSVPPolicy.checkInIsOpen(night: night(startingIn: 30, from: now), now: now))
        XCTAssertFalse(RSVPPolicy.checkInIsOpen(night: night(startingIn: -5, from: now), now: now))
    }
}

final class TeamBalancerTests: XCTestCase {

    private func players(_ rps: [Int64]) -> [TeamBalancer.Player] {
        rps.enumerated().map { TeamBalancer.Player(id: "p\($0.offset)", rankPoints: $0.element) }
    }

    func testTenPlayersSplitFiveAndFiveWithCloseTotals() {
        let split = TeamBalancer.suggest(players([748, 677, 629, 588, 525, 472, 327, 302, 288, 226]))
        XCTAssertEqual(split.teamA.count, 5)
        XCTAssertEqual(split.teamB.count, 5)
        XCTAssertLessThanOrEqual(split.difference, 30)
        XCTAssertEqual(Set((split.teamA + split.teamB).map(\.id)).count, 10, "Every player on exactly one team")
    }

    func testOddCountDiffersByOne() {
        let split = TeamBalancer.suggest(players([500, 400, 300, 200, 100, 50, 25]))
        XCTAssertEqual(abs(split.teamA.count - split.teamB.count), 1)
    }

    func testFindsThePerfectSplitWhenThereIsOne() {
        // 100+40+30+10 = 180 vs 90+50+20+20 = 180
        let split = TeamBalancer.suggest(players([100, 90, 50, 40, 30, 20, 20, 10]))
        XCTAssertEqual(split.difference, 0)
    }

    func testIsDeterministic() {
        let input = players([300, 300, 200, 200, 100, 100])
        XCTAssertEqual(TeamBalancer.suggest(input), TeamBalancer.suggest(input))
    }

    func testEmptyAndSingle() {
        XCTAssertEqual(TeamBalancer.suggest([]).teamA.count, 0)
        let one = TeamBalancer.suggest(players([10]))
        XCTAssertEqual(one.teamA.count + one.teamB.count, 1)
    }
}

final class RSVPStoreTests: XCTestCase {

    private var context: NSManagedObjectContext!
    private var store: CoreDataGameNightStore!
    private let venue = VenueRecord(name: "Gym", address: "1 Main St", courtCount: 2)
    private var nightID = UUID()

    override func setUp() {
        super.setUp()
        context = PersistenceController(inMemory: true).container.viewContext
        store = CoreDataGameNightStore(context: context)
        try! store.saveVenue(venue)
        let start = Date().addingTimeInterval(2 * 86_400)
        let night = GameNightRecord(id: nightID, venue: venue, startDate: start,
                                    endDate: start.addingTimeInterval(7200), capacity: 10)
        try! store.saveGameNight(night, createdBy: nil)
    }

    @discardableResult
    private func member(_ name: String, rp: Int64 = 100, membership: String = AppConstants.competitiveMembership) -> Player {
        let p = Player(context: context)
        p.username = name; p.email = "\(name)@x.com"; p.role = AppConstants.playerRole
        p.membership = membership; p.rankPoints = rp
        try! context.save()
        return p
    }

    private func names(_ n: Int) -> [String] { (1...n).map { "p\($0)" } }

    /// The brief's acceptance test: capacity 10, the 11th RSVP is waitlisted; when one player
    /// cancels the waitlisted player is confirmed; staff check in 10 and get two suggested teams.
    func testAcceptanceFlow() throws {
        for (i, name) in names(11).enumerated() { member(name, rp: Int64(100 + i * 40)) }
        var t = Date()
        for name in names(10) {
            t += 1
            XCTAssertEqual(try store.rsvp(nightID: nightID, username: name, now: t), .confirmed)
        }
        XCTAssertEqual(try store.gameNight(id: nightID)?.status, .full)
        XCTAssertEqual(try store.rsvp(nightID: nightID, username: "p11", now: t + 1), .waitlisted)
        XCTAssertEqual(try store.myRSVP(nightID: nightID, username: "p11"), .waitlisted(position: 1))
        XCTAssertEqual(try store.gameNight(id: nightID)?.availabilityText, "Full · 1 waiting")

        XCTAssertEqual(try store.cancelRSVP(nightID: nightID, username: "p3", now: t + 2), ["p11"])
        XCTAssertEqual(try store.myRSVP(nightID: nightID, username: "p11"), .confirmed(checkedIn: false))
        XCTAssertEqual(try store.myRSVP(nightID: nightID, username: "p3"), .none)

        let roster = try store.roster(nightID: nightID)
        XCTAssertEqual(roster.confirmed.count, 10)
        XCTAssertTrue(roster.waitlist.isEmpty)
        for rsvp in roster.confirmed {
            try store.setCheckedIn(true, nightID: nightID, username: rsvp.username, now: t + 3)
        }
        let checkedIn = try store.roster(nightID: nightID).checkedIn
        XCTAssertEqual(checkedIn.count, 10)
        let split = TeamBalancer.suggest(checkedIn.map { TeamBalancer.Player(id: $0.username, rankPoints: $0.rankPoints) })
        XCTAssertEqual(split.teamA.count, 5)
        XCTAssertEqual(split.teamB.count, 5)
    }

    func testWaitlistIsFirstComeFirstServed() throws {
        for name in names(13) { member(name) }
        var t = Date()
        for name in names(13) { t += 1; try store.rsvp(nightID: nightID, username: name, now: t) }
        XCTAssertEqual(try store.roster(nightID: nightID).waitlist.map(\.username), ["p11", "p12", "p13"])
        XCTAssertEqual(try store.myRSVP(nightID: nightID, username: "p13"), .waitlisted(position: 3))
        try store.cancelRSVP(nightID: nightID, username: "p1", now: t + 1)
        XCTAssertEqual(try store.roster(nightID: nightID).waitlist.map(\.username), ["p12", "p13"])
    }

    func testCancellingAndRejoiningGoesToTheBackOfTheLine() throws {
        for name in names(12) { member(name) }
        var t = Date()
        for name in names(12) { t += 1; try store.rsvp(nightID: nightID, username: name, now: t) }
        try store.cancelRSVP(nightID: nightID, username: "p2", now: t + 1)  // p11 moves up
        XCTAssertEqual(try store.rsvp(nightID: nightID, username: "p2", now: t + 2), .waitlisted)
        XCTAssertEqual(try store.roster(nightID: nightID).waitlist.map(\.username), ["p12", "p2"])
    }

    func testCapacityIncreasePromotesTheWaitlist() throws {
        for name in names(12) { member(name) }
        var t = Date()
        for name in names(12) { t += 1; try store.rsvp(nightID: nightID, username: name, now: t) }
        var night = try store.gameNight(id: nightID)!
        night.capacity = 11
        let result = try store.saveGameNight(night, createdBy: nil)
        XCTAssertEqual(result.promoted, ["p11"])
        XCTAssertEqual(try store.gameNight(id: nightID)?.status, .full)
        night.capacity = 14
        XCTAssertEqual(try store.saveGameNight(night, createdBy: nil).promoted, ["p12"])
        XCTAssertEqual(try store.gameNight(id: nightID)?.status, .scheduled)
    }

    func testRefusals() throws {
        member("casual", membership: AppConstants.casualMembership)
        member("comp")
        if LeagueSettings.rsvpRequiresCompetitive {
            XCTAssertThrowsError(try store.rsvp(nightID: nightID, username: "casual", now: Date()))
        }
        try store.rsvp(nightID: nightID, username: "comp", now: Date())
        XCTAssertThrowsError(try store.rsvp(nightID: nightID, username: "comp", now: Date()), "Double RSVP")
        try store.cancelGameNight(id: nightID)
        member("late")
        XCTAssertThrowsError(try store.rsvp(nightID: nightID, username: "late", now: Date()), "Cancelled night")
    }

    func testWalkInsOnlyWhenThereIsRoom() throws {
        for name in names(10) { member(name) }
        member("walker"); member("waiter")
        var t = Date()
        for name in names(9) { t += 1; try store.rsvp(nightID: nightID, username: name, now: t) }
        XCTAssertTrue(try store.walkInCandidates(nightID: nightID).map(\.username).contains("walker"))

        try store.addWalkIn(nightID: nightID, username: "walker", now: t + 1)
        let roster = try store.roster(nightID: nightID)
        XCTAssertEqual(roster.confirmed.last?.username, "walker")
        XCTAssertTrue(roster.confirmed.last!.isWalkIn)
        XCTAssertTrue(roster.confirmed.last!.isCheckedIn)
        XCTAssertThrowsError(try store.addWalkIn(nightID: nightID, username: "p10", now: t + 2), "Night is full")
    }

    func testWaitlistedPlayerCannotWalkInWhileTheNightIsFull() throws {
        for name in names(11) { member(name) }
        var t = Date()
        for name in names(11) { t += 1; try store.rsvp(nightID: nightID, username: name, now: t) }
        XCTAssertThrowsError(try store.addWalkIn(nightID: nightID, username: "p11", now: t + 1))
        XCTAssertEqual(try store.myRSVP(nightID: nightID, username: "p11"), .waitlisted(position: 1))
    }

    func testCheckInCanBeUndone() throws {
        member("p1")
        try store.rsvp(nightID: nightID, username: "p1", now: Date())
        try store.setCheckedIn(true, nightID: nightID, username: "p1", now: Date())
        XCTAssertEqual(try store.myRSVP(nightID: nightID, username: "p1"), .confirmed(checkedIn: true))
        try store.setCheckedIn(false, nightID: nightID, username: "p1", now: Date())
        XCTAssertEqual(try store.myRSVP(nightID: nightID, username: "p1"), .confirmed(checkedIn: false))
    }

    func testCheckInRequiresAConfirmedRSVP() throws {
        member("nobody")
        XCTAssertThrowsError(try store.setCheckedIn(true, nightID: nightID, username: "nobody", now: Date()))
    }
}
