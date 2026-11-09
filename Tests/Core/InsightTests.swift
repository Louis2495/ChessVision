import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import ChessVision
#endif

final class InsightTests: XCTestCase {
    func testStartingPositionHasNoHangingPieceClaim() {
        XCTAssertFalse(PositionInsights.observations(in: .initial).contains { $0.contains("undefended") })
    }
    func testAttackedUndefendedPawnAndRemoval() throws {
        var board = try Position(fen: "4k3/8/8/6P1/8/8/8/4K1r1 w - - 0 1")
        XCTAssertTrue(PositionInsights.observations(in: board).contains { $0.contains("g5") && $0.contains("undefended") })
        board.squares[Position.index("g1")!] = nil
        XCTAssertFalse(PositionInsights.observations(in: board).contains { $0.contains("g5") })
    }
    func testBishopBoxedInByOwnPawns() throws {
        let board = try Position(fen: "4k3/8/8/8/8/8/1P1P4/2B1K3 w - - 0 1")
        XCTAssertTrue(PositionInsights.observations(in: board).contains { $0.contains("c1") && $0.contains("boxed in") })
    }
    func testVariantOrderAnd960Save() throws {
        XCTAssertEqual(Array(GameMode.allCases.prefix(6)), [.normal, .crazyhouse, .fogOfWar, .chess960, .threeCheck, .kingOfTheHill])
        XCTAssertEqual(Array(GameMode.allCases.suffix(2)), [.blindBoard, .blindText])
        var game = SavedComputerGame(mode: .chess960, human: .white, targetRating: 1200)
        game.chess960Index = 518
        let restored = try JSONDecoder().decode(SavedComputerGame.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(restored.variant, "cv960518")
    }
}
