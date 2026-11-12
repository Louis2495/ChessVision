import XCTest
@testable import ChessCore
final class BughouseThinkingTests: XCTestCase {
    func testBotsSpendMoreTimeOnCriticalPositions() throws {
        let quiet = try VariantSnapshot.parse("fen\t" + Position.initial.fen + "\nstatus\tongoing")
        var checked = quiet; checked.inCheck = true
        let normal = BughouseThinkingPlan(state: quiet, rating: 1200, remaining: 300)
        let critical = BughouseThinkingPlan(state: checked, rating: 1200, remaining: 300)
        XCTAssertEqual(normal.minimumMilliseconds, 1400)
        XCTAssertEqual(critical.minimumMilliseconds, 2800)
        XCTAssertGreaterThan(critical.searchMilliseconds, normal.searchMilliseconds)
    }
    func testTimePressureOverridesDeliberation() throws {
        var checked = try VariantSnapshot.parse("fen\t" + Position.initial.fen + "\nstatus\tongoing")
        checked.inCheck = true
        let urgent = BughouseThinkingPlan(state: checked, rating: 2500, remaining: 2)
        XCTAssertLessThanOrEqual(urgent.minimumMilliseconds, 120)
        XCTAssertLessThanOrEqual(urgent.searchMilliseconds, 120)
        XCTAssertEqual(BughouseThinkingPlan(state: checked, rating: 1000, remaining: .nan).minimumMilliseconds, 0)
    }
}
