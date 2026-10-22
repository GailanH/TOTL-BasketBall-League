import XCTest

/// End-to-end walkthroughs of the real screens. Each step saves a screenshot (kept in the test
/// results; CI publishes them to the `ui-screenshots` branch) so the flow can be reviewed
/// without a person tapping through the Simulator.
final class LeagueFlowUITests: XCTestCase {

    private var app: XCUIApplication!
    private var shotIndex = 0

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: Helpers

    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + arguments
        app.launch()
    }

    private func snap(_ name: String) {
        shotIndex += 1
        let attachment = XCTAttachment(screenshot: app.screenshot())
        let parts = name.split(separator: "/").map(String.init)
        attachment.name = parts.count == 2
            ? String(format: "%@-%02d-%@", parts[0], shotIndex, parts[1])
            : String(format: "%02d-%@", shotIndex, name)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Scrolls until the element is on screen, clear of the keyboard, and tappable; then taps it.
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing: \(element)", file: file, line: line)
        var swipes = 0
        while (!element.isHittable || isUnderKeyboard(element)) && swipes < 8 {
            // Drag within the top of the screen so the gesture never starts on the keyboard.
            let area = scrollArea()
            area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                .press(forDuration: 0.05, thenDragTo: area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
            swipes += 1
        }
        element.tap()
    }

    private func isUnderKeyboard(_ element: XCUIElement) -> Bool {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return false }
        return element.frame.maxY > keyboard.frame.minY - 50
    }

    /// The scrollable content of the current screen (Forms are collection views), so swipes
    /// never land on the keyboard.
    private func scrollArea() -> XCUIElement {
        let list = app.collectionViews.firstMatch
        if list.exists { return list }
        let scroll = app.scrollViews.firstMatch
        return scroll.exists ? scroll : app
    }

    /// Opens a team's "Add Player" menu and chooses a player. Menu items are matched by their
    /// label (the username); identifiers on menu items aren't reliably exposed.
    private func pick(_ username: String, forTeam team: String) {
        let menu = app.buttons["addPlayer-\(team)"]
        tap(menu)
        let item = app.buttons[username].firstMatch
        if !item.waitForExistence(timeout: 3) {
            menu.tap()  // the first tap sometimes only focuses the row
        }
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Menu item \(username) didn't appear")
        item.tap()
    }

    private func type(_ text: String, into element: XCUIElement) {
        tap(element)
        element.typeText(text)
    }

    private func dismissKeyboard() {
        let done = app.toolbars.buttons["Done"]
        if done.exists && done.isHittable { done.tap() }
    }

    // MARK: Record a game as staff

    func testRecordGameLeaderboardAndSeason() {
        launch(["-seedDemoData", "-loginAs", "coach_demo"])

        XCTAssertTrue(app.staticTexts["Welcome, coach_demo!"].waitForExistence(timeout: 10))
        snap("game/dashboard-staff")

        tap(app.buttons["Record Game"])
        XCTAssertTrue(app.navigationBars["Record Game"].waitForExistence(timeout: 5))
        snap("game/record-game-empty")

        // Team A: jordan_g (Gold II) and newbie_p (placement). Team B: maya_r and dre_w.
        let lineups: [(team: String, player: String, stats: [String])] = [
            ("A", "jordan_g", ["16", "7", "5", "1", "3"]),
            ("A", "newbie_p", ["8", "4", "3", "0", "1"]),
            ("B", "maya_r", ["14", "6", "4", "1", "2"]),
            ("B", "dre_w", ["4", "2", "1", "0", "0"])
        ]
        for entry in lineups {
            pick(entry.player, forTeam: entry.team)
        }
        snap("game/record-game-lineups")

        let labels = ["PTS", "REB", "AST", "BLK", "STL"]
        for entry in lineups {
            for (label, value) in zip(labels, entry.stats) {
                type(value, into: app.textFields["stat-\(entry.player)-\(label)"])
            }
        }
        dismissKeyboard()
        snap("game/record-game-filled")

        tap(app.buttons["Team A won"])
        tap(app.buttons["Submit Game"])

        let resultAlert = app.alerts["Team A Wins"]
        XCTAssertTrue(resultAlert.waitForExistence(timeout: 5), "No result alert after submitting")
        snap("game/result-alert")
        let alertText = resultAlert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        XCTAssertTrue(alertText.contains("(MVP)"), "Expected an MVP in: \(alertText)")
        XCTAssertTrue(alertText.contains("(SVP)"), "Expected an SVP in: \(alertText)")
        resultAlert.buttons["OK"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()  // back to Dashboard
        tap(app.buttons["Leaderboard"])
        XCTAssertTrue(app.staticTexts["Season 1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'casual_cass'")).firstMatch.exists,
                       "Casual members must not appear on the leaderboard")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'newbie_p'")).firstMatch.exists,
                       "Players still in placement must not appear on the leaderboard")
        snap("game/leaderboard")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap(app.buttons["Seasons"])
        XCTAssertTrue(app.navigationBars["Seasons"].waitForExistence(timeout: 5))
        snap("game/seasons-before")

        tap(app.buttons["startSeasonButton"])
        tap(app.buttons["confirmStartSeason"])
        XCTAssertTrue(app.staticTexts["Season 2"].waitForExistence(timeout: 5), "Season 2 didn't start")
        snap("game/seasons-after-reset")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap(app.buttons["Leaderboard"])
        XCTAssertTrue(app.staticTexts["Season 2"].waitForExistence(timeout: 5))
        snap("game/leaderboard-after-reset")
    }

    // MARK: Player view

    func testCompetitivePlayerDashboardAndOverview() {
        launch(["-seedDemoData", "-loginAs", "jordan_g"])
        XCTAssertTrue(app.staticTexts["Welcome, jordan_g!"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Record Game"].exists, "Players must not see staff tools")
        snap("player/dashboard-player")

        tap(app.buttons["Player Overview"])
        snap("player/overview")
    }

    // MARK: Sign-up flow

    func testRegisterCompetitivePlayer() {
        launch([])
        XCTAssertTrue(app.buttons["Create Account"].waitForExistence(timeout: 10))
        snap("signup/login")

        tap(app.buttons["Create Account"])
        type("test_player", into: app.textFields["Username"])
        type("test_player@example.com", into: app.textFields["Email"])
        type("test-pass-123", into: app.secureTextFields["Password"])
        type("test-pass-123", into: app.secureTextFields["Confirm Password"])

        // Membership is a menu-style picker: open it, then choose Competitive.
        tap(app.buttons.containing(NSPredicate(format: "label CONTAINS 'membership' OR label CONTAINS 'Membership'")).firstMatch)
        tap(app.buttons["Competitive"])
        snap("signup/form-filled")

        tap(app.buttons["Register"])
        XCTAssertTrue(app.staticTexts["Welcome, test_player!"].waitForExistence(timeout: 10), "Registration didn't log in")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Placement'")).firstMatch.exists,
                      "New Competitive players should start in placement")
        snap("signup/dashboard-new-player")
    }
}
