import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class DeveloperRepertoireTests: XCTestCase {
    private func reply(_ pgn: String) throws -> String? {
        let history = try PGNGame.parse(pgn).moves
        var board = Position.initial
        for uci in history { try board.apply(uci: uci) }
        return DeveloperOpeningBook.move(history: history, side: board.turn, legal: board.legalMoves().map { VariantMove(uci: $0.uci, san: "") })
    }
    func testAllRepertoireLinesParseAndStayLegal() throws {
        XCTAssertEqual(DeveloperOpeningBook.lines.count, 17)
        for line in DeveloperOpeningBook.lines {
            var board = Position.initial
            for uci in line.moves { try board.apply(uci: uci) }
        }
        XCTAssertEqual(DeveloperOpeningBook.rating, 2407)
    }
    func testWhiteUsesItalianGrandPrixAndTarrasch() throws {
        XCTAssertEqual(try reply("1. e4 e5"), "g1f3")
        XCTAssertEqual(try reply("1. e4 e5 2. Nf3 Nc6"), "f1c4")
        XCTAssertEqual(try reply("1. e4 c5"), "b1c3")
        XCTAssertEqual(try reply("1. e4 c5 2. Nc3 Nc6"), "f2f4")
        XCTAssertEqual(try reply("1. e4 c5 2. Nc3 d6"), "f2f4")
        XCTAssertEqual(try reply("1. e4 c5 2. Nc3 e6"), "f2f4")
        XCTAssertEqual(try reply("1. e4 c5 2. Nc3 g6"), "f2f4")
        XCTAssertEqual(try reply("1. e4 c5 2. Nc3 a6"), "f2f4")
        XCTAssertEqual(try reply("1. e4 e6"), "d2d4")
        XCTAssertEqual(try reply("1. e4 e6 2. d4 d5"), "b1d2")
    }
    func testBlackUsesOpenRuyLopez() throws {
        XCTAssertEqual(try reply("1. e4"), "e7e5")
        XCTAssertEqual(try reply("1. e4 e5 2. Nf3"), "b8c6")
        XCTAssertEqual(try reply("1. e4 e5 2. Nf3 Nc6 3. Bb5"), "a7a6")
        XCTAssertEqual(try reply("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4"), "g8f6")
        XCTAssertEqual(try reply("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O"), "f6e4")
    }
    func testBlackUsesNimzoIncludingTranspositions() throws {
        XCTAssertEqual(try reply("1. d4"), "g8f6")
        XCTAssertEqual(try reply("1. d4 Nf6 2. c4"), "e7e6")
        XCTAssertEqual(try reply("1. d4 Nf6 2. c4 e6 3. Nc3"), "f8b4")
        XCTAssertEqual(try reply("1. c4 Nf6 2. Nc3 e6 3. d4"), "f8b4")
    }
    func testCatalanIsAcceptedAtFirstOpportunity() throws {
        for pgn in ["1. d4 Nf6 2. c4 e6 3. Nf3 d5 4. g3", "1. d4 Nf6 2. c4 e6 3. g3 d5 4. Bg2", "1. d4 Nf6 2. Nf3 e6 3. g3 d5 4. c4", "1. d4 Nf6 2. g3 e6 3. Bg2 d5 4. c4", "1. Nf3 Nf6 2. c4 e6 3. g3 d5 4. d4"] {
            XCTAssertEqual(try reply(pgn), "d5c4")
        }
    }
    func testAlekhineUsesExchangeInsteadOfFourPawns() throws {
        XCTAssertEqual(try reply("1. e4 Nf6"), "e4e5")
        XCTAssertEqual(try reply("1. e4 Nf6 2. e5 Nd5"), "d2d4")
        XCTAssertEqual(try reply("1. e4 Nf6 2. e5 Nd5 3. d4 d6"), "e5d6")
    }
    func testIllegalUnknownAndWrongTurnInputsFallBackToEngine() throws {
        XCTAssertNil(DeveloperOpeningBook.move(history: [], side: .white, legal: []))
        XCTAssertNil(DeveloperOpeningBook.move(history: ["a1a8"], side: .black, legal: []))
        XCTAssertNil(DeveloperOpeningBook.move(history: [], side: .black, legal: Position.initial.legalMoves().map { VariantMove(uci: $0.uci, san: "") }))
        XCTAssertNil(try reply("1. b3"))
    }
}
