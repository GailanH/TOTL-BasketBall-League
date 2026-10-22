import XCTest
import CoreData
@testable import Project_Comp_B

final class CSVTableTests: XCTestCase {

    func testSplitHandlesQuotes() {
        XCTAssertEqual(CSVTable.split(#"a, "b, c" ,"say ""hi""""#), ["a", "b, c", #"say "hi""#])
    }

    func testHeadersLowercasedAndBlankLinesSkipped() {
        let table = CSVTable(text: "\nUserName, Email\n\nbob,bob@x.com\n\n")!
        XCTAssertEqual(table.headers, ["username", "email"])
        XCTAssertEqual(table.rows.count, 1)
        XCTAssertEqual(table.rows[0].line, 4)
        XCTAssertEqual(table.value("email", in: table.rows[0].fields), "bob@x.com")
        XCTAssertNil(table.value("missing", in: table.rows[0].fields))
    }

    func testParseDate() {
        XCTAssertNotNil(CSVTable.parseDate("2026-10-21"))
        XCTAssertNotNil(CSVTable.parseDate("2026-10-21 18:30"))
        XCTAssertNil(CSVTable.parseDate("10/21/2026"))
        XCTAssertLessThan(CSVTable.parseDate("2026-10-21")!, CSVTable.parseDate("2026-10-21 18:30")!)
    }
}

final class GameCSVImporterTests: XCTestCase {

    private func competitive(_ name: String, in context: NSManagedObjectContext) {
        let p = Player(context: context)
        p.username = name
        p.email = "\(name)@x.com"
        p.role = AppConstants.playerRole
        p.membership = AppConstants.competitiveMembership
        p.rankPoints = 50
        p.placementGamesRemaining = 0
    }

    func testRecordsGamesOldestFirstAndSkipsBadGames() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        ["a1", "b1"].forEach { competitive($0, in: context) }
        let csv = """
        game,date,username,team,result,points,rebounds,assists,blocks,steals
        later,2026-10-02,a1,A,W,5,3,2,0,1
        later,2026-10-02,b1,B,L,5,3,2,0,1
        first,2026-10-01,a1,A,L,5,3,2,0,1
        first,2026-10-01,b1,B,W,5,3,2,0,1
        bad,2026-10-03,a1,A,W,x,3,2,0,1
        bad,2026-10-03,b1,B,L,5,3,2,0,1
        nowin,2026-10-04,a1,A,L,5,3,2,0,1
        nowin,2026-10-04,b1,B,L,5,3,2,0,1
        """
        let result = GameCSVImporter.importCSV(csv, in: context)
        XCTAssertEqual(result.recorded, 2, result.summary)
        XCTAssertEqual(result.errors.count, 3, result.summary)  // bad row, bad game skipped, no winner

        let request: NSFetchRequest<Match> = Match.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        XCTAssertEqual(try context.fetch(request).map(\.winningTeam), ["B", "A"])
    }

    func testMissingColumns() {
        let context = PersistenceController(inMemory: true).container.viewContext
        XCTAssertEqual(GameCSVImporter.importCSV("game,username\nx,y", in: context).recorded, 0)
    }
}
