import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif

final class ClockTests: XCTestCase {
    func testPausedClockResumesFromEitherFaceWithoutCompletingAMove() {
        var clock = ChessClock(control: ClockTimeControl(seconds: 60, increment: 2, delay: 5))
        clock.start(at: 0); clock.pause(at: 7)
        clock.press(.black, at: 100)
        XCTAssertEqual(clock.phase, .running); XCTAssertEqual(clock.active, .white)
        XCTAssertEqual(clock.remaining(for: .white, at: 101), 57)
    }
    func testDelayAppliesToFirstAndLaterMoves() {
        var clock = ChessClock(control: ClockTimeControl(seconds: 60, increment: 2, delay: 5))
        clock.start(at: 0)
        XCTAssertEqual(clock.remaining(for: .white, at: 4), 60)
        XCTAssertEqual(clock.remaining(for: .white, at: 7), 58)
        clock.press(.white, at: 7)
        XCTAssertEqual(clock.remaining(for: .white, at: 20), 60)
        XCTAssertEqual(clock.remaining(for: .black, at: 11), 60)
        XCTAssertEqual(clock.remaining(for: .black, at: 14), 58)
        XCTAssertEqual(clock.deadline, 72)
    }
    func testPauseDoesNotRefreshDelay() {
        var clock = ChessClock(control: ClockTimeControl(seconds: 60, delay: 5))
        clock.start(at: 0); clock.pause(at: 3); clock.start(at: 100)
        XCTAssertEqual(clock.remaining(for: .white, at: 101), 60)
        XCTAssertEqual(clock.remaining(for: .white, at: 104), 58)
        XCTAssertEqual(clock.deadline, 162)
        clock.pause(at: 105); clock.start(at: 200)
        XCTAssertEqual(clock.remaining(for: .white, at: 201), 56)
    }
    func testElapsedTimeAndIncrementAreAppliedOnlyToActivePlayer() {
        var clock = ChessClock(control: ClockTimeControl(seconds: 180, increment: 2))
        clock.start(at: 100)
        clock.press(.black, at: 103)
        XCTAssertEqual(clock.remaining(for: .white, at: 104), 176, accuracy: 0.001)
        clock.press(.white, at: 105)
        XCTAssertEqual(clock.remaining(for: .white, at: 110), 177, accuracy: 0.001)
        XCTAssertEqual(clock.remaining(for: .black, at: 110), 175, accuracy: 0.001)
        XCTAssertEqual(clock.active, .black)
    }
    func testPauseResumeDoesNotChargePausedTime() {
        var clock = ChessClock(control: ClockTimeControl(seconds: 60))
        clock.start(at: 10); clock.pause(at: 14.25)
        XCTAssertEqual(clock.remaining(for: .white, at: 200), 55.75, accuracy: 0.001)
        clock.start(at: 200)
        XCTAssertEqual(clock.remaining(for: .white, at: 201.5), 54.25, accuracy: 0.001)
    }
    func testFlagCannotBeReversedByTapOrIncrement() {
        var clock = ChessClock(control: ClockTimeControl(seconds: 1, increment: 10))
        clock.start(at: 0)
        XCTAssertEqual(clock.flagged(at: 1), .white)
        clock.press(.white, at: 1.2)
        XCTAssertEqual(clock.phase, .finished)
        XCTAssertEqual(clock.remaining(for: .white, at: 50), 0)
        clock.start(at: 100)
        XCTAssertEqual(clock.phase, .finished)
    }
    func testFaceTapStartsOpponentAndLongBackgroundTimeIsCharged() {
        var clock = ChessClock(control: ClockTimeControl(seconds: 600))
        clock.press(.black, at: 1000)
        XCTAssertEqual(clock.active, .white)
        XCTAssertEqual(clock.remaining(for: .white, at: 1250), 350)
        XCTAssertEqual(clock.remaining(for: .black, at: 1250), 600)
    }
    func testDuckPreviewHandlesCastlingEnPassantAndPromotionWithoutChangingTurn() throws {
        let castle = try Position(fen: "4k3/8/8/8/8/8/8/4K2R w K - 0 1")
        let castled = VariantMove(uci: "e1g1,g1a1", san: "O-O,a1").piecePosition(from: castle)
        XCTAssertEqual(castled.squares[Position.index("g1")!], Piece("K"))
        XCTAssertEqual(castled.squares[Position.index("f1")!], Piece("R"))
        XCTAssertNil(castled.squares[Position.index("h1")!])
        XCTAssertEqual(castled.turn, .white)
        let ep = try Position(fen: "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
        let captured = VariantMove(uci: "e5d6,d6a1", san: "exd6,a1").piecePosition(from: ep)
        XCTAssertNil(captured.squares[Position.index("d5")!])
        XCTAssertEqual(captured.squares[Position.index("d6")!], Piece("P"))
        let promotion = try Position(fen: "4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
        let promoted = VariantMove(uci: "a7a8q,a8b2", san: "a8=Q,b2").piecePosition(from: promotion)
        XCTAssertEqual(promoted.squares[Position.index("a8")!], Piece("Q"))
    }
}
