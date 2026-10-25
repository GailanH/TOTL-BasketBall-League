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

    /// Finds the element (scrolling down, then back up, through long forms whose off-screen
    /// rows don't exist yet), makes sure it's clear of the keyboard, and taps it.
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        if !element.waitForExistence(timeout: 3) {
            for direction in [1.0, -1.0] {
                for _ in 0..<6 where !element.exists {
                    drag(by: direction)
                }
            }
        }
        XCTAssertTrue(element.exists, "Missing: \(element)", file: file, line: line)
        var swipes = 0
        while (!element.isHittable || isUnderKeyboard(element)) && swipes < 8 {
            drag(by: 1)
            swipes += 1
        }
        element.tap()
    }

    /// Drags the content within the upper part of the screen (so it never starts on the
    /// keyboard). Positive moves further down the page, negative back up.
    private func drag(by direction: Double) {
        let area = scrollArea()
        let from = area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: direction > 0 ? 0.45 : 0.15))
        let to = area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: direction > 0 ? 0.15 : 0.45))
        from.press(forDuration: 0.05, thenDragTo: to)
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

    /// Opens a team's "Add Player" list and chooses a player.
    private func pick(_ username: String, forTeam team: String) {
        tap(app.buttons["addPlayer-\(team)"])
        let item = app.buttons["pick-\(username)"]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "\(username) isn't in the Add Player list")
        item.tap()
        let sheetTitle = app.navigationBars["Add to Team \(team)"]
        XCTAssertTrue(sheetTitle.waitForNonExistence(timeout: 5), "Player list didn't close")
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
        // iOS 26+ exposes the confirmation button twice (dialog + its accessibility proxy).
        tap(app.buttons.matching(identifier: "confirmStartSeason").firstMatch)
        XCTAssertTrue(app.staticTexts["Season 2"].waitForExistence(timeout: 5), "Season 2 didn't start")
        snap("game/seasons-after-reset")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap(app.buttons["Leaderboard"])
        XCTAssertTrue(app.staticTexts["Season 2"].waitForExistence(timeout: 5))
        snap("game/leaderboard-after-reset")

        // Season 1 is kept: its final standings are a tap away.
        tap(app.buttons["pastSeasonsLink"])
        XCTAssertTrue(app.navigationBars["Past Seasons"].waitForExistence(timeout: 5))
        tap(app.staticTexts["Season 1"])
        XCTAssertTrue(app.navigationBars["Season 1 Final"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["standing-jordan_g"].firstMatch.waitForExistence(timeout: 5),
                      "jordan_g missing from Season 1's final standings")
        snap("game/season-1-final-standings")
    }

    // MARK: Sample league: podium celebration and rank journey

    func testPodiumCelebrationAndRankJourney() {
        launch(["-loadSampleLeague", "-loginAs", "marcus_j"])
        XCTAssertTrue(app.staticTexts["Welcome, marcus_j!"].waitForExistence(timeout: 10))

        tap(app.buttons["Leaderboard"])
        XCTAssertTrue(app.staticTexts["You're #1!"].waitForExistence(timeout: 5), "No celebration for 1st place")
        sleep(1)  // let the confetti fall a little
        snap("podium/leaderboard-first-place")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap(app.buttons["Rank Timeline"])
        XCTAssertTrue(app.staticTexts["Rank Changes"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No ranked games yet this season. Your journey fills in after your first game."].exists)
        snap("podium/rank-journey-marcus")
    }

    /// Timeline → back → Leaderboard (the path that crashed on 2026-10-21), as a mid-table player.
    func testRankJourneyForAClimber() {
        launch(["-loadSampleLeague", "-loginAs", "jaylen_w"])
        XCTAssertTrue(app.staticTexts["Welcome, jaylen_w!"].waitForExistence(timeout: 10))
        tap(app.buttons["Rank Timeline"])
        XCTAssertTrue(app.staticTexts["Rank Changes"].waitForExistence(timeout: 5))
        snap("journey/rank-journey-jaylen")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap(app.buttons["Leaderboard"])
        XCTAssertTrue(app.staticTexts["5. jaylen_w"].waitForExistence(timeout: 5), "Leaderboard didn't load after the timeline")
        XCTAssertEqual(app.state, .runningForeground, "App crashed opening the leaderboard after the timeline")
        XCTAssertFalse(app.staticTexts["You're #1!"].exists || app.staticTexts["You're #2!"].exists || app.staticTexts["You're #3!"].exists,
                       "5th place shouldn't get the podium celebration")
        XCTAssertTrue(app.descendants(matching: .any)["standingCard"].exists, "No Your Standing card for 5th place")
        snap("journey/leaderboard-fifth-place")

        // Scroll down: the card collapses into the pinned bar; tapping it jumps back to your row.
        for _ in 0..<6 { drag(by: 1) }
        snap("journey/leaderboard-scrolled")
        let bar = app.buttons["compactStandingBar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 3), "Standing card didn't collapse into the pinned bar")
        snap("journey/leaderboard-collapsed-bar")
        bar.tap()
        XCTAssertTrue(app.staticTexts["5. jaylen_w"].waitForExistence(timeout: 3))
        snap("journey/leaderboard-after-tapping-bar")
    }

    // MARK: Game nights (MVP build step 1)

    /// Staff add a venue and a game night from scratch; it shows up on the dashboard.
    func testStaffCreatesVenueAndGameNight() {
        launch(["-seedDemoData", "-loginAs", "coach_demo"])
        XCTAssertTrue(app.staticTexts["Welcome, coach_demo!"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Upcoming Game Nights"].exists)
        snap("nights/dashboard-empty")

        tap(app.buttons["Game Nights"])
        tap(app.buttons["Venues"])
        tap(app.buttons["addVenue"])
        type("Test Rec Center", into: app.textFields["venueName"])
        // Multi-line text fields may surface as text views.
        type("1523 Rigsby Ave, San Antonio, TX 78210", into: app.descendants(matching: .any)["venueAddress"].firstMatch)
        snap("nights/venue-editor")
        app.buttons["saveVenue"].tap()
        XCTAssertTrue(app.staticTexts["Test Rec Center"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()  // back to Game Nights
        tap(app.buttons["newGameNight"])
        XCTAssertTrue(app.navigationBars["New Game Night"].waitForExistence(timeout: 5))
        snap("nights/night-editor")
        app.buttons["saveGameNight"].tap()
        XCTAssertTrue(app.navigationBars["Game Nights"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Test Rec Center'")).firstMatch.waitForExistence(timeout: 5))
        snap("nights/manage-list")

        app.navigationBars.buttons.element(boundBy: 0).tap()  // Dashboard
        XCTAssertTrue(app.descendants(matching: .any)["gameNightRow"].firstMatch.waitForExistence(timeout: 5),
                      "New game night isn't on the dashboard")
        snap("nights/dashboard-with-night")
    }

    /// A player sees the sample league's upcoming nights and opens one.
    func testPlayerSeesUpcomingNightAndDetail() {
        launch(["-loadSampleLeague", "-loginAs", "jaylen_w"])
        XCTAssertTrue(app.staticTexts["Welcome, jaylen_w!"].waitForExistence(timeout: 10))
        let row = app.descendants(matching: .any)["gameNightRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        snap("nights/player-dashboard")
        tap(row)
        XCTAssertTrue(app.buttons["Open in Maps"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add to Calendar"].exists)
        XCTAssertTrue(app.staticTexts["San Antonio time"].exists)
        snap("nights/player-detail")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap(app.buttons["See all"])
        XCTAssertTrue(app.navigationBars["Game Nights"].waitForExistence(timeout: 5))
        snap("nights/player-all-upcoming")
    }

    // MARK: RSVPs, waitlist, check-in and team suggestions (MVP step 2)

    /// luis_g hasn't RSVP'd to the sample kickoff night, which is full: he joins the waitlist
    /// behind two players, then cancels.
    func testPlayerJoinsWaitlistAndCancels() {
        launch(["-loadSampleLeague", "-loginAs", "luis_g"])
        XCTAssertTrue(app.staticTexts["Welcome, luis_g!"].waitForExistence(timeout: 10))
        let row = app.descendants(matching: .any)["gameNightRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        snap("rsvp/dashboard")
        tap(row)

        let join = app.buttons["rsvpButton"]
        XCTAssertTrue(join.waitForExistence(timeout: 5))
        XCTAssertEqual(join.label, "Join Waitlist")
        snap("rsvp/full-night")
        tap(join)
        let alert = app.alerts["RSVP"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["OK"].tap()
        let state = app.descendants(matching: .any)["rsvpState"].firstMatch
        XCTAssertTrue(state.waitForExistence(timeout: 5))
        XCTAssertTrue(state.label.contains("#3"), "Expected waitlist #3, got: \(state.label)")
        snap("rsvp/on-waitlist")

        tap(app.buttons["cancelRSVP"])
        tap(app.buttons.matching(identifier: "confirmCancelRSVP").firstMatch)
        XCTAssertTrue(app.buttons["rsvpButton"].waitForExistence(timeout: 5), "RSVP button didn't come back after cancelling")
        snap("rsvp/cancelled")
    }

    /// Staff open the kickoff night's roster, check players in, get suggested teams for a 2-on-2,
    /// and record it from the roster; the game links to the night.
    func testStaffChecksInAndRecordsFromRoster() {
        launch(["-seedDemoData", "-loadSampleLeague", "-loginAs", "coach_demo"])
        XCTAssertTrue(app.staticTexts["Welcome, coach_demo!"].waitForExistence(timeout: 10))
        tap(app.buttons["Game Nights"])
        let nightRow = app.descendants(matching: .any)["manageNightRow"].firstMatch
        XCTAssertTrue(nightRow.waitForExistence(timeout: 5))
        tap(nightRow)
        XCTAssertTrue(app.navigationBars["Roster"].waitForExistence(timeout: 5))
        snap("roster/before-check-in")

        let players = ["marcus_j", "tasha_b", "dev_o", "kev_m"]
        for name in players { tap(app.buttons["checkIn-\(name)"]) }
        snap("roster/checked-in")

        tap(app.buttons["selectAllCheckedIn"])
        tap(app.buttons["suggestTeams"])
        XCTAssertTrue(app.descendants(matching: .any)["teamBalance"].firstMatch.waitForExistence(timeout: 5))
        snap("roster/suggested-teams")

        tap(app.buttons["recordThisGame"])
        XCTAssertTrue(app.navigationBars["Record Game"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["linkedGameNight"].firstMatch.exists, "Game isn't linked to the night")
        snap("roster/record-prefilled")

        let lines = ["12", "5", "4", "1", "2"]
        let labels = ["PTS", "REB", "AST", "BLK", "STL"]
        for name in players {
            for (label, value) in zip(labels, lines) {
                type(value, into: app.textFields["stat-\(name)-\(label)"])
            }
        }
        dismissKeyboard()
        tap(app.buttons["Submit Game"])
        let result = app.alerts["Team A Wins"]
        XCTAssertTrue(result.waitForExistence(timeout: 5), "No result alert")
        result.buttons["OK"].tap()

        XCTAssertTrue(app.navigationBars["Roster"].waitForExistence(timeout: 5), "Didn't return to the roster")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'played 1'")).firstMatch.waitForExistence(timeout: 5),
                      "Roster doesn't show games played tonight")
        snap("roster/after-game")
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
