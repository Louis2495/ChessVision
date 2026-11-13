import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class EndgameTrainingTests: XCTestCase {
    private func exercise(_ id: String) throws -> EndgameExercise { try XCTUnwrap(EndgameExercise.all.first { $0.id == id }) }
    func testEveryEndgameLoadsLegalAndNonterminal() throws {
        XCTAssertEqual(EndgameExercise.all.count, 17)
        XCTAssertEqual(Set(EndgameExercise.all.map(\.id)).count, 17)
        for exercise in EndgameExercise.all {
            let session = try EndgameSession(exercise: exercise)
            XCTAssertTrue(session.board.problems.isEmpty, exercise.id)
            XCTAssertEqual(session.board.turn, exercise.side)
            XCTAssertFalse(CorrespondenceGame.deadMaterial(session.board), exercise.id)
            XCTAssertEqual(session.outcome, .ongoing)
        }
    }
    func testCheckmateGoalsAndStalemateFailure() throws {
        var queen = try EndgameSession(exercise: exercise("queen-finish"))
        try queen.play("f7g7")
        XCTAssertEqual(queen.outcome, .success); XCTAssertEqual(queen.result, "Checkmate")
        XCTAssertThrowsError(try queen.play("h8h7"))
        var rook = try EndgameSession(exercise: exercise("rook-finish"))
        try rook.play("a7a8"); XCTAssertEqual(rook.outcome, .success)
        var stalemate = try EndgameSession(exercise: exercise("queen-finish"))
        try stalemate.play("f7g6")
        XCTAssertEqual(stalemate.outcome, .failure); XCTAssertEqual(stalemate.result, "Draw")
    }
    func testPromotionIncludesUnderpromotionAndDrawObjectives() throws {
        var pawn = try EndgameSession(exercise: exercise("promotion"))
        try pawn.play("f7f8n"); XCTAssertEqual(pawn.outcome, .success)
        for (id, move) in [("bishop-pawn","b3f7"),("knight-pawn","b6a4"),("rook-pawn-defense","a8a7")] {
            var session = try EndgameSession(exercise: exercise(id)); try session.play(move)
            XCTAssertEqual(session.outcome, .success, id); XCTAssertEqual(session.result, "Draw", id)
        }
    }
    func testClaimableDrawAndCheckmateTakePriority() throws {
        var defense = try exercise("philidor"); defense.fen = defense.fen.replacingOccurrences(of: "0 1", with: "100 1")
        var drawn = try EndgameSession(exercise: defense)
        XCTAssertTrue(drawn.canClaimDraw); try drawn.claimDraw(); XCTAssertEqual(drawn.outcome, .success)
        var mating = try exercise("queen-finish"); mating.fen = mating.fen.replacingOccurrences(of: "0 1", with: "149 1")
        var session = try EndgameSession(exercise: mating)
        try session.play("f7g7"); XCTAssertEqual(session.outcome, .success); XCTAssertEqual(session.result, "Checkmate")
    }
    func testRepetitionAndIllegalMoveDoNotCorruptProgress() throws {
        var session = try EndgameSession(exercise: exercise("queen-king"))
        let fen = session.board.fen
        XCTAssertThrowsError(try session.play("a1a8")); XCTAssertEqual(session.board.fen, fen); XCTAssertTrue(session.moves.isEmpty)
        for _ in 0..<2 { for move in ["e3f3","e7f7","f3e3","f7e7"] { try session.play(move) } }
        XCTAssertTrue(session.canClaimDraw); XCTAssertEqual(session.outcome, .ongoing)
        for _ in 0..<2 { for move in ["e3f3","e7f7","f3e3","f7e7"] { try session.play(move) } }
        XCTAssertEqual(session.result, "Draw"); XCTAssertEqual(session.outcome, .failure)
    }
    func testCompletionPersistenceAndLegacyLibraries() throws {
        var library = LibraryState(); library.completedEndgames.insert("queen-finish")
        let data = try JSONEncoder().encode(library)
        XCTAssertEqual(try JSONDecoder().decode(LibraryState.self, from: data).completedEndgames, ["queen-finish"])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]); json.removeValue(forKey: "completedEndgames")
        XCTAssertTrue(try JSONDecoder().decode(LibraryState.self, from: JSONSerialization.data(withJSONObject: json)).completedEndgames.isEmpty)
    }
    func testCountLabelsAndOpponentOrder() {
        for unit in ["move", "game", "second", "minute", "photo", "training session", "file"] {
            XCTAssertEqual(CountText.value(1, unit), "1 " + unit)
            XCTAssertEqual(CountText.value(2, unit), "2 " + unit + "s")
        }
        XCTAssertEqual(CountText.value(0, "move"), "0 moves")
        XCTAssertEqual(CountText.value(1, "country", plural: "countries"), "1 country")
        XCTAssertEqual(CountText.value(2, "country", plural: "countries"), "2 countries")
        XCTAssertEqual(OpponentChoice.allCases, [.matched, .adaptive, .developer, .custom])
        XCTAssertEqual(OpponentChoice.matched.title, "Current Rating")
    }
}
