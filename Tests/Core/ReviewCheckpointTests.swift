import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class ReviewCheckpointTests: XCTestCase {
    func testCompletedGameCarriesVersionedIdleScoresAndSurvivesEncoding() throws {
        var game = SavedComputerGame(mode: .normal, human: .white, targetRating: 1000, moves: ["e2e4"])
        let line = EngineLine(depth: 22, rank: 1, centipawns: 25, mate: nil, moves: ["e2e4"])
        game.reviewEvaluationVersion = GameReviewLogic.evaluationVersion
        game.prefetchedEvaluations = [0:line, 99:line]
        let entry = CompletedGame(game: game, result: "black")
        XCTAssertEqual(entry.engineEvaluations, [0:line])
        XCTAssertNil(entry.game.prefetchedEvaluations)
        XCTAssertEqual(entry.evaluationSignature, GameReviewLogic.evaluationSignature(for: entry))
        let decoded = try JSONDecoder().decode(CompletedGame.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(decoded.engineEvaluations, entry.engineEvaluations)
        game.reviewEvaluationVersion = "old-engine"
        XCTAssertNil(CompletedGame(game: game, result: "black").engineEvaluations)
    }
    func testEvaluationIdentityChangesWithMovesAndVariantButNotRepertoire() {
        var a = CompletedGame(game: SavedComputerGame(mode: .normal, human: .white, targetRating: 1000, moves: ["e2e4"]), result: "black")
        let first = GameReviewLogic.evaluationSignature(for: a)
        a.game.moves = ["d2d4"]
        XCTAssertNotEqual(first, GameReviewLogic.evaluationSignature(for: a))
        a.game.moves = ["e2e4"]; a.game.mode = .threeCheck
        XCTAssertNotEqual(first, GameReviewLogic.evaluationSignature(for: a))
    }
}
