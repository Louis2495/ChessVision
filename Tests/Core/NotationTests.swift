import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import ChessVision
#endif

final class NotationTests: XCTestCase {
    private struct Reference: Decodable {
        struct Case: Decodable { var fen: String; var legal: [String]; var san: [String: String] }
        var cases: [Case]
    }
    func testSANAndLegalMovesAgainstIndependentReference() throws {
        #if canImport(ChessCore)
        let url = try XCTUnwrap(Bundle.module.url(forResource: "notation", withExtension: "json"))
        #else
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "notation", withExtension: "json", subdirectory: "Reference"))
        #endif
        let reference = try JSONDecoder().decode(Reference.self, from: Data(contentsOf: url))
        XCTAssertEqual(reference.cases.count, 159)
        for sample in reference.cases {
            let board = try Position(fen: sample.fen)
            let moves = board.legalMoves()
            XCTAssertEqual(moves.map(\.uci).sorted(), sample.legal, sample.fen)
            for (uci, expected) in sample.san {
                let move = try XCTUnwrap(moves.first { $0.uci == uci }, "\(sample.fen): \(uci)")
                XCTAssertEqual(try board.san(for: move), expected, "\(sample.fen): \(uci)")
            }
        }
    }
    func testStandardMoveGenerationPerft() throws {
        func perft(_ position: Position, _ depth: Int) throws -> Int {
            if depth == 0 { return 1 }
            var total = 0
            for move in position.legalMoves() {
                var next = position; try next.apply(uci: move.uci)
                total += try perft(next, depth - 1)
            }
            return total
        }
        XCTAssertEqual(try perft(.initial, 3), 8902)
        let kiwi = try Position(fen: "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
        XCTAssertEqual(try perft(kiwi, 2), 2039)
        let enPassant = try Position(fen: "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
        XCTAssertEqual(try perft(enPassant, 3), 2812)
    }
    func testWhiteBlackColumnsAndMoveNumbers() throws {
        let board = try Position(fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
        let moves = try ChessNotation.variation(["e7e5", "g1f3", "b8c6"], from: board)
        XCTAssertEqual(moves.map(\.san), ["e5", "Nf3", "Nc6"])
        XCTAssertEqual(moves.map(\.number), [1, 2, 2])
        XCTAssertEqual(moves.map(\.side), [.black, .white, .black])
    }
    func testRejectsIllegalPlayback() {
        XCTAssertThrowsError(try Position.initial.playing(ChessMove(from: 52, to: 28)))
        XCTAssertThrowsError(try ChessNotation.variation(["e2e5"], from: .initial))
    }
    func testEvaluationBarBalance() {
        XCTAssertEqual(EvaluationScale.whiteFraction(centipawns: 0), 0.5)
        XCTAssertGreaterThan(EvaluationScale.whiteFraction(centipawns: 200), 0.5)
        XCTAssertLessThan(EvaluationScale.whiteFraction(centipawns: -200), 0.5)
        XCTAssertEqual(EvaluationScale.whiteFraction(centipawns: nil, mate: 2), 1)
        XCTAssertEqual(EvaluationScale.whiteFraction(centipawns: nil, mate: -2), 0)
        XCTAssertEqual(EvaluationScale.whiteFraction(centipawns: 150), 1 - EvaluationScale.whiteFraction(centipawns: -150), accuracy: 0.000001)
    }
}
