import XCTest
final class ChessVisionUITests: XCTestCase {
    func testLaunchImmediateAnalysisAndLivePlayback() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["Take Pic of Board"].waitForExistence(timeout: 10))
        app.swipeUp()
        app.buttons["Explore the board editor with an example"].tap()
        XCTAssertFalse(app.switches["I confirm whose turn it is"].exists)
        XCTAssertFalse(app.switches["I reviewed every piece"].exists)
        XCTAssertFalse(app.buttons["Rotate recognized board 90°"].exists)
        let analyze = app.buttons["Analyze with Stockfish"]
        for _ in 0..<6 { if analyze.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(analyze.isEnabled, "A valid position needs no review confirmation")
        analyze.tap()
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
        for title in ["Analysis", "Openings", "Puzzles", "Repertoire", "Play"] { XCTAssertTrue(app.tabBars.buttons[title].waitForExistence(timeout: 5)) }
        app.tabBars.buttons["Openings"].tap()
        XCTAssertTrue(app.textFields["Public username"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Puzzles"].tap()
        XCTAssertTrue(app.staticTexts["Your training estimate"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Hint"].exists)
        app.tabBars.buttons["Repertoire"].tap()
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
        XCTAssertTrue(app.navigationBars["Play computer"].waitForExistence(timeout: 5))
    }
}


extension ChessVisionUITests {
    func testAnalysisSwipeBarAndTurnToggle() {
        let app = XCUIApplication(); app.launch(); app.swipeUp()
        app.buttons["Explore the board editor with an example"].tap()
        let analyze = app.buttons["Analyze with Stockfish"]
        for _ in 0..<6 { if analyze.isHittable { break }; app.swipeUp() }
        analyze.tap()
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
        app.buttons["Start analysis"].tap()
        XCTAssertTrue(app.buttons["square-e2"].waitForExistence(timeout: 5))
        app.buttons["square-e2"].tap(); app.buttons["square-e4"].tap()
        XCTAssertTrue(app.staticTexts["Swipe through the game · 1/1"].waitForExistence(timeout: 5))
        let insights = app.switches["Position insights"]
        if !insights.isHittable { app.swipeUp() }
        XCTAssertTrue(insights.exists)
        if insights.value as? String == "0" { insights.tap() }
        XCTAssertTrue(app.staticTexts["On the board"].exists)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
    }
}
