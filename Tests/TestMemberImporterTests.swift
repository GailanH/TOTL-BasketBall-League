import XCTest
import CoreData
@testable import Project_Comp_B

#if DEBUG
final class TestMemberImporterTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = PersistenceController(inMemory: true).container.viewContext
    }

    private func player(_ username: String) -> Player? {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "username == %@", username)
        return try? context.fetch(request).first
    }

    func testImportsValidRowsWithDefaults() {
        let csv = """
        username,email,membership,password,rank_points,joined
        alpha_1,alpha@x.com,Competitive,password123,420,2026-09-01
        bravo_2,bravo@x.com,competitive,password123,,
        charlie_3,charlie@x.com,Casual,password123,,
        delta_4,delta@x.com,,password123,,
        """
        let result = TestMemberImporter.importCSV(csv, in: context)

        XCTAssertEqual(result.imported, ["alpha_1", "bravo_2", "charlie_3", "delta_4"])
        XCTAssertTrue(result.errors.isEmpty, "\(result.errors)")

        let alpha = player("alpha_1")!
        XCTAssertEqual(alpha.rankPoints, 420)
        XCTAssertEqual(alpha.placementGamesRemaining, 0, "rank_points means already placed")
        XCTAssertEqual(alpha.lastRank, "Gold III")
        XCTAssertEqual(alpha.role, AppConstants.playerRole)
        XCTAssertTrue(PasswordHasher.verify(password: "password123", salt: alpha.passwordSalt!, hash: alpha.password!))
        let firstChange = (alpha.rankChanges as? Set<RankChange>)?.first
        XCTAssertEqual(firstChange?.newRank, "Gold III")
        XCTAssertEqual(firstChange?.date, CSVTable.parseDate("2026-09-01"))

        let bravo = player("bravo_2")!
        XCTAssertEqual(bravo.membership, AppConstants.competitiveMembership)
        XCTAssertEqual(bravo.rankPoints, 0)
        XCTAssertEqual(bravo.placementGamesRemaining, CompetitiveRules.placementGames)

        XCTAssertEqual(player("charlie_3")?.membership, AppConstants.casualMembership)
        XCTAssertNil(player("delta_4")?.membership)
    }

    func testSkipsBadRowsAndKeepsGoodOnes() {
        _ = TestMemberImporter.importCSV("username,email,membership,password\nexisting,existing@x.com,Casual,password123", in: context)
        let csv = """
        username,email,membership,password,rank_points
        ok_one,ok1@x.com,Competitive,password123,
        existing,new@x.com,Casual,password123,
        other,existing@x.com,Casual,password123,
        x,short@x.com,Casual,password123,
        bad_email,not-an-email,Casual,password123,
        bad_member,bm@x.com,Gold,password123,
        short_pw,sp@x.com,Casual,abc,
        no_pw,np@x.com,Casual,,
        casual_rp,crp@x.com,Casual,password123,300
        neg_rp,nrp@x.com,Competitive,password123,-5
        ok_one,dup@x.com,Competitive,password123,
        """
        let result = TestMemberImporter.importCSV(csv, in: context)
        XCTAssertEqual(result.imported, ["ok_one"])
        XCTAssertEqual(result.errors.count, 10, "\(result.errors)")
    }

    func testMissingColumnsImportsNothing() {
        let result = TestMemberImporter.importCSV("username,email,membership\nzed,zed@x.com,Casual", in: context)
        XCTAssertTrue(result.imported.isEmpty)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertNil(player("zed"))
    }
}
#endif
