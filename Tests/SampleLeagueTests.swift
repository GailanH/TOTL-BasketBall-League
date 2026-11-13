#if DEBUG
import XCTest
import CoreData
@testable import Project_Comp_B

/// Loads the DebugTools sample league through the real importers and checks the outcome
/// against an independent simulation of the scoring rules (done when the sample was made).
final class SampleLeagueTests: XCTestCase {

    func testSampleLeagueLoadsAndScoresAsSimulated() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let result = SampleLeague.load(in: context)
        XCTAssertEqual(result.title, "Sample League Loaded", result.message)

        let players: NSFetchRequest<Player> = Player.fetchRequest()
        XCTAssertEqual(try context.count(for: players), 18)
        let matches: NSFetchRequest<Match> = Match.fetchRequest()
        XCTAssertEqual(try context.count(for: matches), 41)

        func rp(_ name: String) -> (Int64, Int16) {
            players.predicate = NSPredicate(format: "username == %@", name)
            let p = try! context.fetch(players).first!
            return (p.rankPoints, p.placementGamesRemaining)
        }
        XCTAssertEqual(rp("marcus_j").0, 748)
        XCTAssertEqual(rp("kev_m").0, 629)
        XCTAssertEqual(rp("rookie_ray").0, 173)
        XCTAssertEqual(rp("rookie_ray").1, 0, "Placement should be finished")
        XCTAssertEqual(rp("rookie_jen").0, 46)
        XCTAssertEqual(rp("luis_g").0, 48)
        XCTAssertEqual(rp("bree_c").0, 327, "G41 underdog win (three Silvers over Gold+)")

        let nightStore = CoreDataGameNightStore(context: context)
        XCTAssertEqual(try nightStore.venues(includeInactive: true).count, 2)
        let nights = try nightStore.allGameNights()
        XCTAssertEqual(nights.count, 6)
        XCTAssertEqual(nights.filter(\.isCancelled).count, 1)
        XCTAssertTrue(nights.allSatisfy { $0.startDate > Date() })
        XCTAssertTrue(nights.allSatisfy { GameNightFormat.time($0.startDate) == "7:00 PM" })

        // The kickoff night is full with a waitlist; the second has a few RSVPs.
        let upcoming = nights.sorted { $0.startDate < $1.startDate }
        let kickoff = try nightStore.roster(nightID: upcoming[0].id)
        XCTAssertEqual(kickoff.confirmed.count, 12)
        XCTAssertEqual(kickoff.waitlist.map(\.username), ["mia_f", "rookie_ray"])
        XCTAssertEqual(upcoming[0].status, .full)
        XCTAssertEqual(try nightStore.roster(nightID: upcoming[1].id).confirmed.count, 6)

        XCTAssertEqual(SampleLeague.load(in: context).title, "Already Loaded")
    }
}
#endif

#if DEBUG
final class TestGameNightsTests: XCTestCase {

    func testAddsLongLivedNightsOnceWithRealisticFill() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        _ = SampleLeague.load(in: context)
        let store = CoreDataGameNightStore(context: context)
        let before = try store.allGameNights().count

        XCTAssertEqual(TestGameNights.add(in: context).title, "Test Game Nights Added")
        XCTAssertEqual(TestGameNights.add(in: context).title, "Already Added", "Second run adds nothing")

        let nights = try store.allGameNights().filter { $0.notes.hasPrefix(TestGameNights.marker) }
        XCTAssertEqual(nights.count, 8)
        XCTAssertEqual(try store.allGameNights().count, before + 8)
        XCTAssertTrue(nights.allSatisfy { LeagueSettings.calendar.component(.year, from: $0.startDate) == 2030 })
        XCTAssertTrue(nights.allSatisfy { GameNightFormat.time($0.startDate) == "7:00 PM" })

        let byDay = Dictionary(uniqueKeysWithValues: nights.map { (LeagueSettings.calendar.component(.day, from: $0.startDate), $0) })
        XCTAssertEqual(byDay[8]?.availabilityText, "Full · 3 waiting")
        XCTAssertEqual(byDay[10]?.availabilityText, "2 of 18 spots left")
        XCTAssertEqual(byDay[17]?.availabilityText, "36 of 36 spots left")
        XCTAssertEqual(byDay[24]?.availabilityText, "Full")

        // They show as upcoming for players.
        let upcoming = try store.upcomingGameNights(now: Date())
        XCTAssertEqual(upcoming.filter { $0.notes.hasPrefix(TestGameNights.marker) }.count, 8)
    }
}
#endif
