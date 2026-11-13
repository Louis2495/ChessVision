import XCTest
final class NovaChessUITests: XCTestCase {
    func assertHistory(_ value: String, in app: XCUIApplication) {
        let bar = app.otherElements["analysis-history-bar"]
        let correct = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: correct, object: bar)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        XCTAssertTrue(app.staticTexts["Swipe"].exists)
    }
    func testLaunchImmediateAnalysisAndLivePlayback() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["square-e2"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Analysis"].exists)
        let next = app.buttons["Next position"]
        XCTAssertFalse(next.isEnabled)
        app.buttons["square-e2"].tap(); app.buttons["square-e4"].tap()
        assertHistory("1/1", in: app)
        XCTAssertFalse(next.isEnabled)
        app.buttons["Previous position"].tap(); assertHistory("0/1", in: app)
        next.tap(); assertHistory("1/1", in: app)
        let toggle = app.switches["Candidate lines"]
        for _ in 0..<6 { if toggle.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(toggle.exists)
        if toggle.value as? String == "0" { toggle.tap() }
        let best = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Best move:")).firstMatch
        XCTAssertTrue(best.waitForExistence(timeout: 15))
        toggle.tap(); XCTAssertFalse(best.exists)
        toggle.tap(); XCTAssertTrue(best.waitForExistence(timeout: 5))
        for _ in 0..<6 { if next.isHittable { break }; app.swipeDown() }
        XCTAssertFalse(next.isEnabled)
        assertHistory("1/1", in: app)
    }

}

extension NovaChessUITests {
    func testBottomTabsAndNewTrainingFlows() {
        let app = XCUIApplication(); app.launch()
        for title in ["Analysis", "Play", "Puzzles", "Openings", "Clock"] { XCTAssertTrue(app.tabBars.buttons[title].waitForExistence(timeout: 5)) }
        app.tabBars.buttons["Openings"].tap()
        app.buttons["Research"].tap()
        XCTAssertTrue(app.textFields["Public username"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Puzzles"].tap()
        XCTAssertTrue(app.staticTexts["Your puzzle estimate"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Hint"].exists)
        app.tabBars.buttons["Openings"].tap()
        app.navigationBars.buttons["Openings"].tap()
        app.buttons["Your Repertoire"].tap()
        app.buttons["Add a line"].tap()
        app.buttons["square-e2"].tap(); app.buttons["square-e4"].tap()
        let name = "UI line " + UUID().uuidString.prefix(8)
        app.textFields["Line name"].tap(); app.textFields["Line name"].typeText(name)
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.staticTexts[name].tap(); app.buttons["Train this line"].tap()
        XCTAssertTrue(app.staticTexts["Your move: follow your repertoire"].waitForExistence(timeout: 5))
        app.buttons["square-e2"].tap(); app.buttons["square-e4"].tap()
        XCTAssertTrue(app.staticTexts["Line completed"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Play"].tap()
        if app.navigationBars["Game review"].waitForExistence(timeout: 2) { app.navigationBars.buttons["Done"].tap() }
        XCTAssertTrue(app.navigationBars["Play computer"].waitForExistence(timeout: 5))
    }
}


extension NovaChessUITests {
    func testAnalysisSwipeBarAndTurnToggle() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["square-e2"].waitForExistence(timeout: 5))
        let bar = app.otherElements["analysis-history-bar"]
        bar.swipeLeft(); assertHistory("0/0", in: app)
        app.buttons["square-e2"].tap(); app.buttons["square-e4"].tap()
        bar.swipeLeft(); assertHistory("1/1", in: app)
        XCTAssertFalse(app.buttons["Next position"].isEnabled)
        bar.swipeRight(); assertHistory("0/1", in: app)
        XCTAssertTrue(app.buttons["Next position"].isEnabled)
        app.buttons["Turn: White"].tap()
        XCTAssertTrue(app.buttons["Turn: Black"].waitForExistence(timeout: 5))
    }

}

extension NovaChessUITests {
    func testStartAnalysisWithoutPhotoAndOpenSettings() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["square-e2"].waitForExistence(timeout: 5))
        app.buttons["square-e2"].tap(); app.buttons["square-e4"].tap()
        assertHistory("1/1", in: app)
        let insights = app.switches["Position insights"]
        if !insights.isHittable { app.swipeUp() }
        XCTAssertTrue(insights.exists)
        if insights.value as? String == "0" { insights.tap() }
        XCTAssertTrue(app.staticTexts["Position assessment"].exists)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
    }
}

extension NovaChessUITests {
    func testFiveTabOrderAndClock() {
        let app = XCUIApplication(); app.launch()
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), ["Analysis", "Play", "Puzzles", "Openings", "Clock"])
        app.tabBars.buttons["Clock"].tap()
        XCTAssertTrue(app.buttons["clock-w"].waitForExistence(timeout: 5))
        app.buttons["clock-w"].tap()
        let running = expectation(for: NSPredicate(format: "label CONTAINS %@", "running"), evaluatedWith: app.buttons["clock-b"])
        wait(for: [running], timeout: 3)
        app.buttons["Pause"].tap()
        XCTAssertFalse(app.buttons["Resume"].exists)
        app.buttons["Time control"].tap()
        XCTAssertTrue(app.switches["Custom time control"].waitForExistence(timeout: 5))
    }
}

extension NovaChessUITests {
    func testPlayedNotationAndGIFShareOption() {
        let app = XCUIApplication(); app.launch()
        app.buttons["square-e2"].tap(); app.buttons["square-e4"].tap()
        let insights = app.switches["Position insights"]
        if insights.value as? String == "1" { insights.tap() }
        let notation = app.switches["Show notation"]
        for _ in 0..<8 { if notation.isHittable { break }; app.swipeUp() }
        if notation.value as? String == "0" { notation.tap() }
        XCTAssertTrue(app.buttons["Move 1, White, e4"].waitForExistence(timeout: 5))
        let share = app.buttons["Share"]
        for _ in 0..<5 { if share.isHittable { break }; app.swipeUp() }
        share.tap()
        XCTAssertTrue(app.buttons["Share GIF"].waitForExistence(timeout: 5))
    }
}

extension NovaChessUITests {
    func testFinishedGameOpensReviewAndHistory() {
        let app = XCUIApplication(); app.launch(); app.tabBars.buttons["Play"].tap()
        if app.navigationBars["Game review"].waitForExistence(timeout: 2) { app.navigationBars.buttons["Done"].tap() }
        if app.buttons["New game"].exists { app.buttons["New game"].tap() }
        let start = app.buttons["Start game"]
        for _ in 0..<6 { if start.isHittable { break }; app.swipeUp() }
        start.tap()
        let resign = app.buttons["Resign"]
        for _ in 0..<8 { if resign.isHittable { break }; app.swipeUp() }
        resign.tap(); app.sheets.buttons["Resign"].tap()
        XCTAssertTrue(app.staticTexts["final-position-evaluation"].waitForExistence(timeout: 10))
        let review = app.buttons["Review game"]
        for _ in 0..<8 { if review.isHittable { break }; app.swipeUp() }
        review.tap()
        XCTAssertTrue(app.navigationBars["Game review"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Areas for improvement"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Done"].tap()
        let banner = app.buttons["game-result"]
        for _ in 0..<8 { if banner.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(banner.exists); banner.tap()
        XCTAssertFalse(banner.exists)
        XCTAssertTrue(app.navigationBars["Play computer"].exists)
        app.buttons["New game"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start game"].exists)
        XCTAssertEqual(app.sheets.count, 0)
        app.navigationBars["New game"].buttons.firstMatch.tap()
        app.buttons["Game history"].tap()
        XCTAssertTrue(app.navigationBars["Game history"].waitForExistence(timeout: 5))
    }
}

extension NovaChessUITests {
    func testBughouseRequiresLandscapeAndShowsTwoBoards() {
        let app = XCUIApplication(); app.launch(); app.tabBars.buttons["Play"].tap()
        if app.navigationBars["Game review"].waitForExistence(timeout: 2) { app.navigationBars.buttons["Done"].tap() }
        if app.buttons["New game"].exists { app.buttons["New game"].tap() }
        app.buttons["Game options"].tap()
        app.buttons["game-style"].tap(); app.buttons["Bughouse"].tap()
        app.buttons["Start game"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        let start = app.buttons["Start Bughouse"]
        for _ in 0..<8 { if start.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(start.waitForExistence(timeout: 5)); start.tap()
        XCTAssertTrue(app.otherElements["bughouse-board-A"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["bughouse-board-B"].exists)
        app.buttons["Close"].tap()
        XCUIDevice.shared.orientation = .portrait
    }
}

extension NovaChessUITests {
    func testSavedPhotosHasDirectEntryPointAndHelpfulEmptyState() {
        let app = XCUIApplication(); app.launch()
        let photos = app.buttons["Saved photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 5)); photos.tap()
        XCTAssertTrue(app.navigationBars["Saved photos"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No saved photos"].exists || app.staticTexts["Analyze"].firstMatch.exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Scan board"].exists)
    }
}


extension NovaChessUITests {
    func testClockFacesOnlyShowTimesAndCenterControlOpensSetup() {
        let app = XCUIApplication(); app.launch(); app.tabBars.buttons["Clock"].tap()
        let white = app.buttons["clock-w"], black = app.buttons["clock-b"]
        XCTAssertTrue(white.waitForExistence(timeout: 5))
        XCTAssertFalse(white.staticTexts["White"].exists)
        XCTAssertFalse(black.staticTexts["Black"].exists)
        app.buttons["Time control"].tap()
        XCTAssertTrue(app.navigationBars["Time control"].waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.buttons["Apply"].frame.width, 200)
    }
}


extension NovaChessUITests {
    func testNewGameUsesExclusiveOpponentChoices() {
        let app = XCUIApplication(); app.launch(); app.tabBars.buttons["Play"].tap()
        if app.navigationBars["Game review"].waitForExistence(timeout: 2) { app.navigationBars.buttons["Done"].tap() }
        app.buttons["New game"].firstMatch.tap()
        let start = app.buttons["start-computer-game"], options = app.buttons["game-options"]
        XCTAssertTrue(start.waitForExistence(timeout: 5)); XCTAssertTrue(options.exists)
        XCTAssertLessThan(start.frame.minY, options.frame.minY)
        XCTAssertEqual(options.value as? String, "Collapsed")
        options.tap()
        for choice in ["developer", "adaptive", "matched", "custom"] {
            let button = app.buttons["opponent-" + choice]
            for _ in 0..<5 { if button.isHittable { break }; app.swipeUp() }
            button.tap(); XCTAssertTrue(button.isSelected)
            for other in ["developer", "adaptive", "matched", "custom"] where other != choice {
                XCTAssertFalse(app.buttons["opponent-" + other].isSelected)
            }
        }
        XCTAssertTrue(app.textFields["Rating"].exists)
    }
}
