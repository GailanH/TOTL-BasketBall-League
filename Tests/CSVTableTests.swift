import XCTest
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
