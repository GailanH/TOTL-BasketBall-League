import XCTest
import CoreData
@testable import Project_Comp_B

final class GameNightModelTests: XCTestCase {

    private let venue = VenueRecord(name: "Ramirez Rec Center", address: "1523 Rigsby Ave, San Antonio, TX 78210",
                                    courtCount: 2, notes: "Park in the back lot")

    /// 2026-11-03 19:00 in San Antonio (CST, UTC-6) is 2026-11-04 01:00 UTC.
    private func chicago(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        LeagueSettings.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testDatesAreStoredInUTCAndShownInLeagueTime() {
        let start = chicago(2026, 11, 3, 19)
        let utc = ISO8601DateFormatter().string(from: start)
        XCTAssertEqual(utc, "2026-11-04T01:00:00Z")
        XCTAssertEqual(GameNightFormat.time(start), "7:00 PM")
        XCTAssertEqual(GameNightFormat.day(start), "Tue, Nov 3")
    }

    func testDayAndTimesFormatting() {
        var night = GameNightRecord.newNight(on: chicago(2026, 11, 3, 12), at: venue)
        XCTAssertEqual(GameNightFormat.dayAndTimes(night), "Tue, Nov 3 · 7:00 – 9:00 PM")
        night.endDate = chicago(2026, 11, 4, 1)
        XCTAssertEqual(GameNightFormat.dayAndTimes(night), "Tue, Nov 3 · 7:00 PM – 1:00 AM")
    }

    func testNewNightUsesLeagueDefaults() {
        let night = GameNightRecord.newNight(on: chicago(2026, 11, 3, 9), at: venue)
        XCTAssertEqual(night.startDate, chicago(2026, 11, 3, 19))
        XCTAssertEqual(night.endDate.timeIntervalSince(night.startDate), LeagueSettings.defaultDuration)
        XCTAssertEqual(night.capacity, LeagueSettings.defaultCapacity)
        XCTAssertEqual(night.status, .scheduled)
    }

    func testValidation() {
        let now = chicago(2026, 11, 1, 12)
        let good = GameNightRecord.newNight(on: chicago(2026, 11, 3, 12), at: venue)
        XCTAssertNil(good.validationError(now: now, isNew: true))

        var endsBeforeStart = good; endsBeforeStart.endDate = good.startDate.addingTimeInterval(-60)
        XCTAssertNotNil(endsBeforeStart.validationError(now: now, isNew: true))

        var inThePast = good; inThePast.startDate = chicago(2026, 10, 1, 19); inThePast.endDate = chicago(2026, 10, 1, 21)
        XCTAssertNotNil(inThePast.validationError(now: now, isNew: true))
        XCTAssertNil(inThePast.validationError(now: now, isNew: false), "Past nights can still be edited")

        var tooManyCourts = good; tooManyCourts.courtsInUse = 3
        XCTAssertNotNil(tooManyCourts.validationError(now: now, isNew: true))

        var tinyCapacity = good; tinyCapacity.capacity = 1
        XCTAssertNotNil(tinyCapacity.validationError(now: now, isNew: true))

        var inactiveVenue = good; inactiveVenue.venue.isActive = false
        XCTAssertNotNil(inactiveVenue.validationError(now: now, isNew: true))
    }

    func testVenueValidation() {
        XCTAssertNil(venue.validationError)
        XCTAssertNotNil(VenueRecord(name: "", address: "x").validationError)
        XCTAssertNotNil(VenueRecord(name: "Gym", address: "").validationError)
        XCTAssertNotNil(VenueRecord(name: "Gym", address: "x", mapURL: "not a url").validationError)
        XCTAssertEqual(venue.shortAddress, "1523 Rigsby Ave")
    }

    func testMapsURLUsesTheAddress() {
        let url = venue.mapsURL!.absoluteString
        XCTAssertTrue(url.hasPrefix("https://maps.apple.com/?"))
        XCTAssertTrue(url.contains("address=1523%20Rigsby%20Ave"))
        var pinned = venue; pinned.mapURL = "https://maps.apple.com/?ll=29.4,-98.4"
        XCTAssertEqual(pinned.mapsURL?.absoluteString, "https://maps.apple.com/?ll=29.4,-98.4")
    }

    func testMaterialChanges() {
        let old = GameNightRecord.newNight(on: chicago(2026, 11, 3, 12), at: venue)
        var notesOnly = old; notesOnly.notes = "Bring a dark shirt"
        XCTAssertEqual(notesOnly.materialChanges(from: old), [])

        var moved = old; moved.startDate = moved.startDate.addingTimeInterval(1800)
        XCTAssertEqual(moved.materialChanges(from: old), [.time])

        var newVenue = old; newVenue.venue = VenueRecord(name: "Other Gym", address: "1 Main St")
        XCTAssertEqual(newVenue.materialChanges(from: old), [.venue])

        var cancelled = old; cancelled.status = .cancelled
        XCTAssertEqual(cancelled.materialChanges(from: old), [.cancelled])
    }

    func testDisplayStatusMarksPastNightsCompleted() {
        let night = GameNightRecord.newNight(on: chicago(2026, 11, 3, 12), at: venue)
        XCTAssertEqual(night.displayStatus(now: chicago(2026, 11, 3, 18)), .scheduled)
        XCTAssertEqual(night.displayStatus(now: chicago(2026, 11, 3, 22)), .completed)
        var cancelled = night; cancelled.status = .cancelled
        XCTAssertEqual(cancelled.displayStatus(now: chicago(2026, 11, 3, 22)), .cancelled)
    }

    func testShareTextSaysWhenAndWhere() {
        let night = GameNightRecord.newNight(on: chicago(2026, 11, 3, 12), at: venue)
        let text = GameNightFormat.shareText(night)
        XCTAssertTrue(text.contains("Tue, Nov 3 · 7:00 – 9:00 PM"))
        XCTAssertTrue(text.contains("Ramirez Rec Center, 1523 Rigsby Ave"))
    }
}

final class CoreDataGameNightStoreTests: XCTestCase {

    private var context: NSManagedObjectContext!
    private var store: CoreDataGameNightStore!
    private let venue = VenueRecord(name: "Ramirez Rec Center", address: "1523 Rigsby Ave, San Antonio, TX 78210", courtCount: 2)

    override func setUp() {
        super.setUp()
        context = PersistenceController(inMemory: true).container.viewContext
        store = CoreDataGameNightStore(context: context)
    }

    private func night(inDays days: Double, from now: Date = Date()) -> GameNightRecord {
        let start = now.addingTimeInterval(days * 86_400)
        return GameNightRecord(venue: venue, startDate: start, endDate: start.addingTimeInterval(7_200))
    }

    func testVenueRoundTripAndUpdate() throws {
        try store.saveVenue(venue)
        var edited = venue; edited.notes = "Side door"; edited.latitude = 29.41; edited.longitude = -98.47
        try store.saveVenue(edited)
        XCTAssertEqual(try store.venues(includeInactive: false), [edited])

        var inactive = edited; inactive.isActive = false
        try store.saveVenue(inactive)
        XCTAssertTrue(try store.venues(includeInactive: false).isEmpty)
        XCTAssertEqual(try store.venues(includeInactive: true).count, 1)
    }

    func testInvalidVenueIsRejected() {
        XCTAssertThrowsError(try store.saveVenue(VenueRecord(name: "", address: "")))
    }

    func testUpcomingIsSoonestFirstAndSkipsPastNights() throws {
        try store.saveVenue(venue)
        let now = Date()
        let later = night(inDays: 7, from: now), sooner = night(inDays: 2, from: now)
        try store.saveGameNight(later, createdBy: nil)
        try store.saveGameNight(sooner, createdBy: nil)

        // A finished night (inserted directly; the store refuses to create nights in the past).
        let past = GameNight(context: context)
        past.id = UUID(); past.startDate = now.addingTimeInterval(-86_400); past.endDate = now.addingTimeInterval(-79_200)
        past.status = GameNightStatus.scheduled.rawValue
        let venues: NSFetchRequest<Venue> = Venue.fetchRequest()
        past.venue = try context.fetch(venues).first
        try context.save()

        XCTAssertEqual(try store.upcomingGameNights(now: now).map(\.id), [sooner.id, later.id])
        XCTAssertEqual(try store.allGameNights().count, 3)
    }

    func testCancelledNightsStayVisibleThisWeekOnly() throws {
        try store.saveVenue(venue)
        let now = Date()
        let soon = night(inDays: 2, from: now), farOff = night(inDays: 20, from: now)
        try store.saveGameNight(soon, createdBy: nil)
        try store.saveGameNight(farOff, createdBy: nil)

        XCTAssertEqual(try store.cancelGameNight(id: soon.id), [.cancelled])
        try store.cancelGameNight(id: farOff.id)

        let upcoming = try store.upcomingGameNights(now: now)
        XCTAssertEqual(upcoming.map(\.id), [soon.id])
        XCTAssertEqual(upcoming.first?.status, .cancelled)
    }

    func testEditReportsMaterialChanges() throws {
        try store.saveVenue(venue)
        let original = night(inDays: 3)
        XCTAssertEqual(try store.saveGameNight(original, createdBy: nil), [])

        var moved = original
        moved.startDate = moved.startDate.addingTimeInterval(3_600)
        moved.endDate = moved.endDate.addingTimeInterval(3_600)
        XCTAssertEqual(try store.saveGameNight(moved, createdBy: nil), [.time])
        XCTAssertEqual(try store.gameNight(id: original.id)?.startDate, moved.startDate)
    }

    func testCreatorAndSeasonAreRecorded() throws {
        let staff = Player(context: context)
        staff.username = "coach"; staff.email = "coach@x.com"; staff.role = AppConstants.employeeRole
        SeasonManager.ensureActiveSeason(in: context)
        try context.save()
        try store.saveVenue(venue)
        let n = night(inDays: 3)
        try store.saveGameNight(n, createdBy: "coach")
        let saved = try store.gameNight(id: n.id)
        XCTAssertEqual(saved?.createdByUsername, "coach")
        XCTAssertEqual(saved?.seasonName, "Season 1")
    }

    func testInvalidNightIsRejectedWithoutSaving() throws {
        try store.saveVenue(venue)
        var bad = night(inDays: 3); bad.endDate = bad.startDate
        XCTAssertThrowsError(try store.saveGameNight(bad, createdBy: nil))
        XCTAssertTrue(try store.allGameNights().isEmpty)
    }
}
