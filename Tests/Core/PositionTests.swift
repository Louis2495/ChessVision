import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class PositionTests: XCTestCase {
    func testStartingPositionRoundTrip() throws {
        let position=Position.initial
        XCTAssertEqual(try Position(fen:position.fen),position)
        XCTAssertTrue(position.problems.isEmpty)
        XCTAssertEqual(position.squares.compactMap{$0}.count,32)
    }
    func testCoordinates() {for i in 0..<64 {XCTAssertEqual(Position.index(Position.name(i)),i)}; XCTAssertNil(Position.index("i9")); XCTAssertNil(Position.index("a0"))}
    func testMalformedFEN() {for fen in ["", "/8/8/8/8/8/8/8/8 w - - 0 1", "8/8/8/8/8/8/8/8/ w - - 0 1", "8/8/8/8/8/8/8/9 w - - 0 1","8/8/8/8/8/8/8/8 x - - 0 1","8/8/8/8/8/8/8/8 w KK - 0 1","8/8/8/8/8/8/8/8 w - i3 0 1"] {XCTAssertThrowsError(try Position(fen:fen))}}
    func testMissingKings() {XCTAssertEqual(Position().problems.count,2)}
    func testAdjacentKingsInvalid() throws {XCTAssertFalse(try Position(fen:"8/8/8/8/8/8/4k3/4K3 w - - 0 1").problems.isEmpty)}
    func testWrongSideInCheck() throws {XCTAssertFalse(try Position(fen:"4k3/8/8/8/8/8/4R3/4K3 w - - 0 1").problems.isEmpty)}
    func testSideToMoveMayBeInCheck() throws {XCTAssertTrue(try Position(fen:"4k3/8/8/8/8/8/4r3/4K3 w - - 0 1").problems.isEmpty)}
    func testBlockedSlidingAttack() throws {let p=try Position(fen:"4k3/8/8/8/8/4P3/4r3/4K3 b - - 0 1");XCTAssertFalse(p.attacked(4,by:.black))}
    func testPawnsOnBackRank() throws {XCTAssertFalse(try Position(fen:"P3k3/8/8/8/8/8/8/4K3 w - - 0 1").problems.isEmpty)}
    func testCastlingRightsRequireRooks() throws {XCTAssertFalse(try Position(fen:"4k3/8/8/8/8/8/8/4K3 w K - 0 1").problems.isEmpty)}
    func testPawnDoubleAndCounters() throws {var p=Position.initial;try p.apply(uci:"e2e4");XCTAssertEqual(p.enPassant,"e3");XCTAssertEqual(p.turn,.black);XCTAssertEqual(p.fullmove,1);XCTAssertTrue(p.problems.isEmpty);try p.apply(uci:"e7e5");XCTAssertEqual(p.fullmove,2)}
    func testEnPassantCapture() throws {var p=try Position(fen:"4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2");XCTAssertTrue(p.problems.isEmpty);try p.apply(uci:"e5d6");XCTAssertNil(p.squares[Position.index("d5")!]);XCTAssertEqual(p.squares[Position.index("d6")!],Piece("P"))}
    func testInvalidEnPassant() throws {XCTAssertFalse(try Position(fen:"4k3/8/8/8/8/8/8/4K3 w - e3 0 1").problems.isEmpty)}
    func testCastlePlayback() throws {var p=try Position(fen:"4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1");try p.apply(uci:"e1g1");XCTAssertEqual(p.squares[61],Piece("R"));XCTAssertEqual(p.squares[62],Piece("K"));XCTAssertEqual(p.castling,"")}
    func testPromotion() throws {var p=try Position(fen:"4k3/P7/8/8/8/8/8/4K3 w - - 0 1");try p.apply(uci:"a7a8n");XCTAssertEqual(p.squares[0],Piece("N"))}
    func testInvalidMoveInput() {var p=Position.initial;XCTAssertThrowsError(try p.apply(uci:"e2e2"));XCTAssertThrowsError(try p.apply(uci:"h9h8"));XCTAssertThrowsError(try p.apply(uci:"e7e5"))}
    func testRookCaptureClearsRights() throws {var p=try Position(fen:"r3k3/8/8/8/8/8/8/R3K3 w Qq - 0 1");try p.apply(uci:"a1a8");XCTAssertEqual(p.castling,"")}
    func testEngineCentipawnsWhitePerspective() {let line=EngineLine.parse("info depth 12 multipv 2 score cp 150 nodes 10 pv e7e5 g1f3",turn:.black);XCTAssertEqual(line?.evaluation,"-1.50");XCTAssertEqual(line?.rank,2);XCTAssertEqual(line?.moves,["e7e5","g1f3"])}
    func testEngineMate() {XCTAssertEqual(EngineLine.parse("info depth 9 score mate -3 pv e2e4",turn:.black)?.evaluation,"M3")}
    func testIgnoreBoundAndIncompleteInfo() {XCTAssertNil(EngineLine.parse("info depth 1 score cp 12 lowerbound pv e2e4",turn:.white));XCTAssertNil(EngineLine.parse("info nodes 123",turn:.white))}
}
