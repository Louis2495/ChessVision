import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class MoveAssessmentTests: XCTestCase {
    func testBlackPerspectiveAndMoveGradeAreConsistent() throws {
        let before = try VariantSnapshot.parse("fen\trnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1\nstatus\tongoing")
        let after = try VariantSnapshot.parse("fen\trnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2\nstatus\tongoing")
        let baseline = EngineLine(depth: 15, rank: 1, centipawns: -100, mate: nil, moves: ["c7c5"])
        let outcome = EngineLine(depth: 16, rank: 1, centipawns: 200, mate: nil, moves: ["g1f3"])
        let assessment = MoveAssessment.make(ply: 1, move: VariantMove(uci: "e7e5", san: "e5"), before: before, after: after, baseline: baseline, outcome: outcome)
        XCTAssertEqual(assessment.loss, 300); XCTAssertEqual(assessment.quality, .blunder)
        XCTAssertEqual(assessment.destination, Position.index("e5"))
    }
    func testSummaryReportsMeasuredLossRatherThanHumanRating() {
        let move = MoveAssessment(ply: 0, side: .white, uci: "e2e4", san: "e4", quality: .good, loss: 30, depth: 14)
        XCTAssertNil(ReviewSummary([], side: .white).averageCentipawnLoss)
        XCTAssertEqual(ReviewSummary([move], side: .white).count(.good), 1)
        XCTAssertEqual(ReviewSummary([move], side: .white).averageCentipawnLoss, 30)
        XCTAssertEqual(ReviewSummary([move], side: .black).count(.good), 0)
    }
}
