import XCTest
final class ChessVisionUITests: XCTestCase {
    func testLaunchImmediateAnalysisAndLivePlayback() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["square-e2"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Explore the board editor with an example"].exists)
        XCTAssertTrue(app.navigationBars["Analysis"].waitForExistence(timeout: 5))
        app.buttons["Candidate lines"].tap()
        let best = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Best move:")).firstMatch
        XCTAssertTrue(best.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["White"].exists)
        XCTAssertTrue(app.staticTexts["Black"].exists)
        XCTAssertFalse(app.buttons["Analyze again"].exists)
        XCTAssertFalse(app.staticTexts["Evaluation is from White's perspective."].exists)
        let next = app.buttons["Next position"]
        for _ in 0..<5 { if next.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(next.isEnabled); next.tap()
        XCTAssertTrue(app.staticTexts["Swipe through the game · 1/1"].waitForExistence(timeout: 5))
        // The analysis is still live after moving; there is no restart button.
        XCTAssertTrue(best.waitForExistence(timeout: 15))
        app.buttons["Return to original position"].tap()
        XCTAssertTrue(app.staticTexts["Swipe through the game · 0/0"].waitForExistence(timeout: 5))
        app.buttons["Share position"].tap()
        XCTAssertTrue(app.buttons["Share board image"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share image & FEN"].exists)
    }
}

extension ChessVisionUITests {
    func testBottomTabsAndNewTrainingFlows() {
        let app = XCUIApplication(); app.launch()
        for title in ["Analysis", "Play", "Puzzles", "Openings", "Clock"] { XCTAssertTrue(app.tabBars.buttons[title].waitForExistence(timeout: 5)) }
        app.tabBars.buttons["Openings"].tap()
        app.buttons["Research"].tap()
        XCTAssertTrue(app.textFields["Public username"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Puzzles"].tap()
        XCTAssertTrue(app.staticTexts["Your training estimate"].waitForExistence(timeout: 5))
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


extension ChessVisionUITests {
    func testAnalysisSwipeBarAndTurnToggle() {
        let app = XCUIApplication(); app.launch()
        app.buttons["Candidate lines"].tap()
        let best = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Best move:")).firstMatch
        XCTAssertTrue(best.waitForExistence(timeout: 15))
        let bar = app.otherElements["analysis-history-bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        bar.swipeLeft(); XCTAssertTrue(app.staticTexts["Swipe through the game · 1/1"].waitForExistence(timeout: 5))
        bar.swipeRight(); XCTAssertTrue(app.staticTexts["Swipe through the game · 0/1"].waitForExistence(timeout: 5))
        app.buttons["Turn: White"].tap()
        XCTAssertTrue(app.buttons["Turn: Black"].waitForExistence(timeout: 5))
    }
}

extension ChessVisionUITests {
    func testStartAnalysisWithoutPhotoAndOpenSettings() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["square-e2"].waitForExistence(timeout: 5))
        app.buttons["square-e2"].tap(); app.buttons["square-e4"].tap()
        XCTAssertTrue(app.staticTexts["Swipe through the game · 1/1"].waitForExistence(timeout: 5))
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

extension ChessVisionUITests {
    func testFiveTabOrderAndClock() {
        let app = XCUIApplication(); app.launch()
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), ["Analysis", "Play", "Puzzles", "Openings", "Clock"])
        app.tabBars.buttons["Clock"].tap()
        XCTAssertTrue(app.buttons["clock-w"].waitForExistence(timeout: 5))
        app.buttons["clock-w"].tap()
        let running = expectation(for: NSPredicate(format: "label CONTAINS %@", "running"), evaluatedWith: app.buttons["clock-b"])
        wait(for: [running], timeout: 3)
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].exists)
        app.buttons["Time control"].tap()
        XCTAssertTrue(app.switches["Custom time control"].waitForExistence(timeout: 5))
    }
}

extension ChessVisionUITests {
    func testPlayedNotationAndGIFShareOption() {
        let app = XCUIApplication(); app.launch()
        app.buttons["square-e2"].tap(); app.buttons["square-e4"].tap()
        let insights = app.switches["Position insights"]
        if insights.value as? String == "1" { insights.tap() }
        let notation = app.switches["Show notation"]
        for _ in 0..<8 { if notation.isHittable { break }; app.swipeUp() }
        if notation.value as? String == "0" { notation.tap() }
        XCTAssertTrue(app.buttons["Move 1, White, e4"].waitForExistence(timeout: 5))
        let share = app.buttons["Share position"]
        for _ in 0..<5 { if share.isHittable { break }; app.swipeUp() }
        share.tap()
        XCTAssertTrue(app.buttons["Share game GIF"].waitForExistence(timeout: 5))
    }
}

extension ChessVisionUITests {
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
        XCTAssertTrue(app.navigationBars["Game review"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Areas for improvement"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Done"].tap()
        app.buttons["Game history"].tap()
        XCTAssertTrue(app.navigationBars["Game history"].waitForExistence(timeout: 5))
    }
}
