import XCTest
@testable import Project_Comp_B

final class AppConstantsTests: XCTestCase {

    func testCompetitiveMembershipIsRanked() {
        XCTAssertTrue(AppConstants.isRanked("Competitive"))
    }

    func testCasualMembershipIsNotRanked() {
        XCTAssertFalse(AppConstants.isRanked("Casual"))
    }

    func testNoMembershipIsNotRanked() {
        XCTAssertFalse(AppConstants.isRanked(nil))
    }

    func testDeactivatedMembershipIsNotRanked() {
        XCTAssertFalse(AppConstants.isRanked("Deactivated"))
    }

    func testStaffRolesContainsEmployeeAndAdministrator() {
        XCTAssertTrue(AppConstants.isStaff(AppConstants.employeeRole))
        XCTAssertTrue(AppConstants.isStaff(AppConstants.administratorRole))
        XCTAssertFalse(AppConstants.isStaff(AppConstants.playerRole))
        XCTAssertFalse(AppConstants.isStaff(AppConstants.employeePendingRole))
        XCTAssertFalse(AppConstants.isStaff(nil))
    }
}
