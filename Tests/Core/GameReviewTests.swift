import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import ChessVision
#endif

final class GameReviewTests: XCTestCase {
    private func snapshot(_ board: Position, moves: [(String, String)], status: String = "ongoing") throws -> VariantSnapshot {
        let text = "fen\t\(board.fen)\nstatus\t\(status)\n" + moves.map { "move\t\($0.0)\t\($0.1)" }.joined(separator: "\n")
        return try VariantSnapshot.parse(text)
    }
    func testOldLibraryWithoutHistoryOrGameIDPreservesExistingData() throws {
        var state = LibraryState(); state.puzzle.attempts = 42
        state.repertoire = [RepertoireLine(name: "My Italian", side: .white, moves: ["e2e4", "e7e5"])]
        state.computer = SavedComputerGame(mode: .normal, human: .black, targetRating: 1700, moves: ["e2e4"])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        object.removeValue(forKey: "history")
        var game = try XCTUnwrap(object["computer"] as? [String: Any]); game.removeValue(forKey: "id"); object["computer"] = game
        let restored = try JSONDecoder().decode(LibraryState.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(restored.puzzle.attempts, 42); XCTAssertEqual(restored.repertoire.first?.name, "My Italian")
        XCTAssertEqual(restored.computer?.moves, ["e2e4"]); XCTAssertNil(restored.computer?.id); XCTAssertTrue(restored.history.isEmpty)
    }
    func testPersonalizedSeventhMoveSuggestionAndAlternateBranches() throws {
        let opening = try PGNGame.parse("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3")
        let line = RepertoireLine(name: "Ruy Lopez main line", side: .white, moves: opening.moves)
        var board = Position.initial
        for move in opening.moves.prefix(12) { try board.apply(uci: move) }
        let played = try board.move(forSAN: "Bxb5")
        let index = try ReviewRepertoireIndex(lines: [line])
        let answer = GameReviewLogic.repertoireSuggestion(at: board, played: played.uci, san: "Bxb5", ply: 12, choices: index.positions[board.openingKey])
        let suggestion = try XCTUnwrap(answer.suggestion)
        XCTAssertEqual(suggestion.number, 7); XCTAssertEqual(suggestion.recommended, ["Bb3"])
        XCTAssertEqual(suggestion.source, .repertoire); XCTAssertTrue(suggestion.explanation.contains(line.name))
        let branches = [RepertoireLine(name: "e4", side: .white, moves: ["e2e4"]), RepertoireLine(name: "d4", side: .white, moves: ["d2d4"])]
        let accepted = GameReviewLogic.repertoireSuggestion(at: .initial, played: "d2d4", san: "d4", ply: 0, lines: branches)
        XCTAssertTrue(accepted.matched); XCTAssertNil(accepted.suggestion)
    }
    func testEngineLossIsMeasuredFromBlackPerspective() throws {
        let board = try Position.initial.playing(Position.initial.move(forSAN: "e4"))
        let before = try snapshot(board, moves: [("e7e5", "e5"), ("d7d5", "d5")])
        let afterBoard = try board.playing(board.move(forSAN: "d5"))
        let after = try snapshot(afterBoard, moves: [("e4d5", "exd5")])
        let baseline = EngineLine(depth: 14, rank: 1, centipawns: -40, mate: nil, moves: ["e7e5"])
        let outcome = EngineLine(depth: 15, rank: 1, centipawns: 180, mate: nil, moves: ["e4d5"])
        let result = try XCTUnwrap(GameReviewLogic.engineSuggestion(ply: 1, side: .black, number: 1, played: before.moves[1], before: before, after: after, baseline: baseline, outcome: outcome, standard: true))
        XCTAssertEqual(result.centipawnLoss, 220); XCTAssertEqual(result.label, "Mistake")
        XCTAssertEqual(result.concept, .material); XCTAssertTrue(result.explanation.contains("exd5"))
    }
    func testSmallLossAndWinningMoveAreNotCalledMistakes() throws {
        let before = try snapshot(.initial, moves: [("e2e4", "e4"), ("d2d4", "d4")])
        let afterBoard = try Position.initial.playing(Position.initial.move(forSAN: "d4"))
        let after = try snapshot(afterBoard, moves: [("d7d5", "d5")])
        let baseline = EngineLine(depth: 12, rank: 1, centipawns: 25, mate: nil, moves: ["e2e4"])
        let outcome = EngineLine(depth: 12, rank: 1, centipawns: -10, mate: nil, moves: ["d7d5"])
        XCTAssertNil(GameReviewLogic.engineSuggestion(ply: 0, side: .white, number: 1, played: before.moves[1], before: before, after: after, baseline: baseline, outcome: outcome, standard: true))
        var win = after; win.status = "white"
        XCTAssertNil(GameReviewLogic.engineSuggestion(ply: 0, side: .white, number: 1, played: before.moves[1], before: before, after: win, baseline: baseline, outcome: nil, standard: false))
    }
    func testMissedMateAndReviewAreasHaveConcreteMoveEvidence() throws {
        let before = try snapshot(.initial, moves: [("e2e4", "e4"), ("d2d4", "d4")])
        let after = try snapshot(Position.initial.playing(Position.initial.move(forSAN: "d4")), moves: [("d7d5", "d5")])
        let baseline = EngineLine(depth: 12, rank: 1, centipawns: nil, mate: 3, moves: ["e2e4"])
        let outcome = EngineLine(depth: 12, rank: 1, centipawns: 500, mate: nil, moves: ["d7d5"])
        let suggestion = try XCTUnwrap(GameReviewLogic.engineSuggestion(ply: 0, side: .white, number: 1, played: before.moves[1], before: before, after: after, baseline: baseline, outcome: outcome, standard: true))
        XCTAssertEqual(suggestion.concept, .matingPatterns); XCTAssertNil(suggestion.centipawnLoss)
        var review = GameReview(signature: "test"); review.suggestions = [suggestion]
        XCTAssertEqual(review.areas, [.matingPatterns])
    }
    func testSignatureTracksRepertoireMovesButNotTrainingDatesOrOrder() {
        var first = RepertoireLine(name: "Main", side: .white, moves: ["e2e4"])
        let second = RepertoireLine(name: "Other", side: .white, moves: ["d2d4"])
        let signature = GameReviewLogic.signature([first, second]); first.record(correct: true)
        XCTAssertEqual(signature, GameReviewLogic.signature([second, first]))
        first.moves = ["c2c4"]
        XCTAssertNotEqual(signature, GameReviewLogic.signature([first, second]))
    }
}

extension GameReviewTests {
    func testVariantGoalIsNotLabeledMissedCheckmate() throws {
        let before = try snapshot(.initial, moves: [("e2e4", "e4"), ("d2d4", "d4")])
        let after = try snapshot(Position.initial.playing(Position.initial.move(forSAN: "d4")), moves: [("d7d5", "d5")])
        let baseline = EngineLine(depth: 10, rank: 1, centipawns: nil, mate: 3, moves: ["e2e4"])
        let outcome = EngineLine(depth: 10, rank: 1, centipawns: 500, mate: nil, moves: ["d7d5"])
        let item = try XCTUnwrap(GameReviewLogic.engineSuggestion(ply: 0, side: .white, number: 1, played: before.moves[1], before: before, after: after, baseline: baseline, outcome: outcome, standard: false, variant: "3check"))
        XCTAssertEqual(item.concept, .variantStrategy)
        XCTAssertNotEqual(item.label, "Missed mate")
        XCTAssertTrue(item.explanation.contains("variant win"))
    }
    func testCompletedHistoryRoundTripKeepsReplayAndReview() throws {
        let game = SavedComputerGame(mode: .duck, human: .black, targetRating: 1500, moves: ["e2e4,e4d5"])
        var record = CompletedGame(game: game, result: "white")
        record.positions = ["first", "last"]
        var review = GameReview(signature: "current"); review.complete = true; review.nextPly = 1; record.review = review
        var state = LibraryState(); state.history = [record]
        let restored = try JSONDecoder().decode(LibraryState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.history[0].id, game.id)
        XCTAssertEqual(restored.history[0].game.moves, game.moves)
        XCTAssertEqual(restored.history[0].humanMoveCount, 0)
        XCTAssertEqual(restored.history[0].positions, ["first", "last"])
        XCTAssertTrue(restored.history[0].review?.complete == true)
    }
}
