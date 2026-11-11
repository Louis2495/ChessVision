import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import ChessVision
#endif
final class CorrespondenceTests: XCTestCase {
    func testPayloadReplaysAndRejectsIllegalOrOutOfTurnMoves() throws {
        var game = CorrespondenceGame(whitePlayerID: "white-player")
        try game.play("e2e4")
        XCTAssertThrowsError(try game.play("d2d4"))
        try game.play("e7e5")
        let restored = try JSONDecoder().decode(CorrespondenceGame.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(try restored.validated().notation, ["e4","e5"])
        XCTAssertEqual(CorrespondenceGame.turnSeconds, 259200)
    }
    func testMateAndResignationPreventFurtherMoves() throws {
        var game = CorrespondenceGame(whitePlayerID: "alice")
        for uci in ["f2f3","e7e5","g2g4","d8h4"] { try game.play(uci) }
        XCTAssertEqual(try game.validated().result, "black")
        XCTAssertThrowsError(try game.play("a2a3"))
        var resigned = CorrespondenceGame(whitePlayerID: "alice"); resigned.resigned = .black
        XCTAssertEqual(try resigned.validated().result, "white")
        XCTAssertThrowsError(try resigned.play("e2e4"))
    }
    func testOnlineArchiveIdentityIsStableAcrossReloads() {
        XCTAssertEqual(CorrespondenceGame.archiveID("game-center-match-123"), CorrespondenceGame.archiveID("game-center-match-123"))
        XCTAssertNotEqual(CorrespondenceGame.archiveID("game-center-match-123"), CorrespondenceGame.archiveID("game-center-match-124"))
    }
    func testMalformedHistoryIsRejectedBeforeBoardDisplay() {
        var game = CorrespondenceGame(whitePlayerID: "alice"); game.moves = ["e2e5"]
        XCTAssertThrowsError(try game.validated())
        game.moves = []; game.whitePlayerID = ""
        XCTAssertThrowsError(try game.validated())
    }
}
