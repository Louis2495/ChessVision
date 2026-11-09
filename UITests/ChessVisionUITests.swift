import XCTest
final class ChessVisionUITests: XCTestCase {
    func testLaunchAndExampleAnalysis() {
        let app=XCUIApplication();app.launch()
        XCTAssertTrue(app.buttons["Take Pic of Board"].waitForExistence(timeout:10))
        app.swipeUp()
        app.buttons["Explore the board editor with an example"].tap()
        let turn=app.switches["I confirm whose turn it is"]
        for _ in 0..<6 {if turn.isHittable {break};app.swipeUp()}
        XCTAssertTrue(turn.exists);turn.tap()
        let review=app.switches["I reviewed every piece"]
        for _ in 0..<4 {if review.isHittable {break};app.swipeUp()}
        review.tap()
        let analyze=app.buttons["Analyze with Stockfish"]
        for _ in 0..<6 {if analyze.isHittable {break};app.swipeUp()}
        XCTAssertTrue(analyze.isEnabled);analyze.tap()
        XCTAssertTrue(app.navigationBars["Stockfish analysis"].waitForExistence(timeout:5))
        let best=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Best move:")).firstMatch
        XCTAssertTrue(best.waitForExistence(timeout:15))
        let next=app.buttons["Next"]
        for _ in 0..<4 {if next.isHittable {break};app.swipeUp()}
        if next.waitForExistence(timeout:10) {
            let deadline=Date().addingTimeInterval(10)
            while !next.isEnabled && Date()<deadline {RunLoop.current.run(until:Date().addingTimeInterval(0.2))}
            XCTAssertTrue(next.isEnabled);next.tap()
            XCTAssertTrue(app.staticTexts["1 ply"].exists)
            app.buttons["Return to original position"].tap()
            XCTAssertTrue(app.staticTexts["0 ply"].exists)
        }
    }
}
