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
        XCTAssertTrue(app.navigationBars["Stockfish analysis"].waitForExistence(timeout: 5))
        let best = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Best move:")).firstMatch
        XCTAssertTrue(best.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["White"].exists)
        XCTAssertTrue(app.staticTexts["Black"].exists)
        XCTAssertFalse(app.buttons["Analyze again"].exists)
        XCTAssertFalse(app.staticTexts["Evaluation is from White's perspective."].exists)
        let next = app.buttons["analysis-next"]
        for _ in 0..<5 { if next.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(next.isEnabled); next.tap()
        XCTAssertTrue(app.staticTexts["1 ply"].waitForExistence(timeout: 5))
        // The analysis is still live after moving; there is no restart button.
        XCTAssertTrue(best.waitForExistence(timeout: 15))
        app.buttons["Return to original position"].tap()
        XCTAssertTrue(app.staticTexts["0 ply"].waitForExistence(timeout: 5))
        app.buttons["Share position"].tap()
        XCTAssertTrue(app.buttons["Share board image"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share image & FEN"].exists)
    }
}
