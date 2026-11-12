import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif

final class PremoveTests: XCTestCase {
    func testRecaptureCanBeQueuedOntoFriendlyPieceAndExecutesAfterCapture() throws {
        var board = try Position(fen: "4k3/8/8/4p3/3P4/8/8/3QK3 b - - 0 1")
        var queue = PremoveQueue(), composer = PremoveComposer()
        composer.tap(Position.index("d1")!, board: board, side: .white, duck: false, queue: &queue)
        composer.tap(Position.index("d4")!, board: board, side: .white, duck: false, queue: &queue)
        XCTAssertEqual(queue.moves, ["d1d4"])
        try board.apply(uci: "e5d4")
        let legal = board.legalMoves().map { VariantMove(uci: $0.uci, san: "") }
        XCTAssertEqual(queue.take(legal: legal)?.uci, "d1d4")
    }
    func testPawnCanPremoveRecaptureOntoFriendlyKnight() throws {
        var board = try Position(fen: "4k3/8/4b3/3N4/4P3/8/8/4K3 b - - 0 1")
        var queue = PremoveQueue(), composer = PremoveComposer()
        composer.tap(Position.index("e4")!, board: board, side: .white, duck: false, queue: &queue)
        composer.tap(Position.index("d5")!, board: board, side: .white, duck: false, queue: &queue)
        XCTAssertEqual(queue.moves, ["e4d5"])
        try board.apply(uci: "e6d5")
        XCTAssertEqual(queue.take(legal: board.legalMoves().map { VariantMove(uci: $0.uci, san: "") })?.uci, "e4d5")
    }
    func testFriendlyDestinationIsNotCapturedIfOpponentDoesSomethingElse() throws {
        var board = try Position(fen: "4k3/8/8/4p3/3P4/8/8/3QK3 b - - 0 1")
        var queue = PremoveQueue(); queue.append("d1d4")
        try board.apply(uci: "e8f8")
        XCTAssertNil(queue.take(legal: board.legalMoves().map { VariantMove(uci: $0.uci, san: "") }))
        XCTAssertTrue(queue.moves.isEmpty)
    }
    func testQueueExecutesInOrderAndCancelsOneAtATime() {
        var queue = PremoveQueue()
        for move in ["e2e4", "g1f3", "f1c4"] { queue.append(move) }
        queue.cancelLast()
        XCTAssertEqual(queue.moves, ["e2e4", "g1f3"])
        let legal = [VariantMove(uci: "e2e4", san: "e4")]
        XCTAssertEqual(queue.take(legal: legal)?.uci, "e2e4")
        XCTAssertEqual(queue.moves, ["g1f3"])
        queue.cancelLast(); queue.cancelLast()
        XCTAssertTrue(queue.moves.isEmpty)
    }
    func testIllegalFirstIntentClearsDependentMoves() {
        var queue = PremoveQueue(); queue.append("e2e5"); queue.append("e5e6")
        XCTAssertNil(queue.take(legal: [VariantMove(uci: "e2e4", san: "e4")]))
        XCTAssertTrue(queue.moves.isEmpty)
    }
    func testProjectedBoardAllowsMovingSamePieceAgainWithoutMutatingGame() {
        var queue = PremoveQueue(); queue.append("g1f3"); queue.append("f3g5")
        let shown = queue.projected(.initial, side: .white)
        XCTAssertNil(shown.squares[Position.index("g1")!])
        XCTAssertEqual(shown.squares[Position.index("g5")!], Piece("N"))
        XCTAssertEqual(Position.initial.squares[Position.index("g1")!], Piece("N"))
    }
    func testUnrelatedTapsCancelOneQueuedMoveEach() {
        var queue = PremoveQueue(); queue.append("e2e4"); queue.append("g1f3")
        var composer = PremoveComposer()
        composer.tap(Position.index("a5")!, board: queue.projected(.initial, side: .white), side: .white, duck: false, queue: &queue)
        XCTAssertEqual(queue.moves, ["e2e4"])
        composer.tap(Position.index("b5")!, board: queue.projected(.initial, side: .white), side: .white, duck: false, queue: &queue)
        XCTAssertTrue(queue.moves.isEmpty)
    }
    func testUnrelatedDestinationCancelsInsteadOfQueuingAnImpossibleMove() {
        var queue = PremoveQueue(); queue.append("e2e4")
        var composer = PremoveComposer()
        let board = queue.projected(.initial, side: .white)
        composer.tap(Position.index("g1")!, board: board, side: .white, duck: false, queue: &queue)
        composer.tap(Position.index("a5")!, board: board, side: .white, duck: false, queue: &queue)
        XCTAssertTrue(queue.moves.isEmpty)
        XCTAssertNil(composer.selected)
    }
    func testDuckRequiresBothPieceAndDuckBeforeQueuing() {
        var queue = PremoveQueue(), composer = PremoveComposer()
        composer.tap(Position.index("e2")!, board: .initial, side: .white, duck: true, queue: &queue)
        composer.tap(Position.index("e4")!, board: .initial, side: .white, duck: true, queue: &queue)
        XCTAssertTrue(queue.moves.isEmpty)
        let shown = VariantMove(uci: "e2e4", san: "").piecePosition(from: .initial)
        composer.tap(Position.index("d4")!, board: shown, side: .white, duck: true, queue: &queue)
        XCTAssertEqual(queue.moves, ["e2e4,e4d4"])
    }
    func testChess960PreviewPreservesBothPiecesIncludingStationaryKing() throws {
        let board = try Position(fen: "4k3/8/8/8/8/8/8/6KR w - - 0 1")
        var queue = PremoveQueue(); queue.append("g1h1")
        let projected = queue.projected(board, side: .white)
        XCTAssertEqual(projected.squares[Position.index("g1")!], Piece("K"))
        XCTAssertEqual(projected.squares[Position.index("f1")!], Piece("R"))
        XCTAssertNil(projected.squares[Position.index("h1")!])
    }
    func testDiagonalPremoveDoesNotEraseAnUnrelatedPiece() throws {
        let board = try Position(fen: "4k3/8/8/8/8/5B2/4P3/4K3 w - - 0 1")
        var queue = PremoveQueue(); queue.append("e2f3")
        // The destination contains a piece; its square alone is replaced in the projection.
        let projected = queue.projected(board, side: .white)
        XCTAssertEqual(projected.squares[Position.index("f3")!], Piece("P"))
        XCTAssertEqual(projected.squares[Position.index("e1")!], Piece("K"))
        let emptyDestination = try Position(fen: "4k3/8/8/8/8/4PB2/8/4K3 w - - 0 1")
        var diagonal = PremoveQueue(); diagonal.append("e3f4")
        XCTAssertEqual(diagonal.projected(emptyDestination, side: .white).squares[Position.index("f3")!], Piece("B"))
    }
    func testUnusualKingPreviewCannotIndexBeyondBoard() throws {
        let board = try Position(fen: "4k3/8/8/8/8/8/8/5K2 w - - 0 1")
        var queue = PremoveQueue(); queue.append("f1h1")
        XCTAssertEqual(queue.projected(board, side: .white).squares[Position.index("h1")!], Piece("K"))
    }
    func testAntichessPremoveCanChooseKingPromotion() throws {
        let board = try Position(fen: "7k/P7/8/8/8/8/8/7K w - - 0 1")
        let old = UserDefaults.standard.object(forKey: "autoQueen")
        UserDefaults.standard.set(false, forKey: "autoQueen")
        defer { if let old { UserDefaults.standard.set(old, forKey: "autoQueen") } else { UserDefaults.standard.removeObject(forKey: "autoQueen") } }
        var queue = PremoveQueue(), composer = PremoveComposer()
        composer.tap(Position.index("a7")!, board: board, side: .white, duck: false, queue: &queue)
        composer.tap(Position.index("a8")!, board: board, side: .white, duck: false, promotionKinds: "qrbnk", queue: &queue)
        XCTAssertTrue(composer.promotions.contains { $0.promotion == "k" })
        XCTAssertTrue(queue.moves.isEmpty)
    }
    func testDropAndTypedBlindfoldIntent() {
        var queue = PremoveQueue(), composer = PremoveComposer(); composer.drop = "N"
        composer.tap(Position.index("f6")!, board: .initial, side: .black, duck: false, queue: &queue)
        XCTAssertEqual(queue.projected(.initial, side: .black).squares[Position.index("f6")!], Piece("n"))
        XCTAssertEqual(PremoveQueue.coordinateIntent("g1f3"), "g1f3")
        XCTAssertEqual(PremoveQueue.coordinateIntent("n@f6"), "N@f6")
        XCTAssertNil(PremoveQueue.coordinateIntent("Nf3"))
        XCTAssertNil(PremoveQueue.coordinateIntent("a9b2"))
    }
    func testStartingWhiteByTappingBlackDoesNotAwardAnUnplayedMove() {
        var clock = ChessClock(control: ClockTimeControl(seconds: 60, increment: 2))
        clock.press(.black, at: 10)
        XCTAssertEqual(clock.remaining(for: .black, at: 10), 60)
        clock.press(.white, at: 13)
        XCTAssertEqual(clock.remaining(for: .white, at: 13), 59)
        clock.press(.black, at: 16)
        XCTAssertEqual(clock.remaining(for: .black, at: 16), 59)
    }
    func testFirstFaceTapAwardsMoveOneIncrement() {
        var clock = ChessClock(control: ClockTimeControl(seconds: 60, increment: 2))
        clock.press(.white, at: 10)
        XCTAssertEqual(clock.remaining(for: .white, at: 10), 62)
        XCTAssertEqual(clock.active, .black)
        clock.press(.black, at: 13)
        XCTAssertEqual(clock.remaining(for: .black, at: 13), 59)
    }
}
