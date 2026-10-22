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

        XCTAssertEqual(SampleLeague.load(in: context).title, "Already Loaded")
    }
}
#endif
