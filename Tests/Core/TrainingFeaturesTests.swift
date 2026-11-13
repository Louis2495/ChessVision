import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class TrainingFeaturesTests: XCTestCase {
    func testCuratedLessonsAreLongerLegalAndCoverManyFamilies() throws {
        let lessons = OpeningLessons.curated(in: try TrainingAssets.openings())
        print("Learn curriculum: \(lessons.count) lessons")
        XCTAssertGreaterThanOrEqual(lessons.count, 25)
        XCTAssertEqual(OpeningLessons.additional.count, 3)
        XCTAssertEqual(Set(lessons.map(\.id)).count, lessons.count)
        for line in lessons {
            XCTAssertTrue((16...40).contains(line.moves.count), line.name)
            var board = Position.initial
            for uci in line.moves { try board.apply(uci: uci) }
            XCTAssertEqual(board.openingKey, line.key)
        }
    }
    func testDailySelectionUsesCalendarDateAndNotLibraryOrdering() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: -7 * 3600)!
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let key = DailyPuzzle.key(for: date, calendar: calendar)
        XCTAssertEqual(key, DailyPuzzle.key(for: date.addingTimeInterval(1), calendar: calendar))
        XCTAssertNotEqual(key, DailyPuzzle.key(for: date.addingTimeInterval(86400), calendar: calendar))
        let puzzles = try TrainingAssets.puzzles()
        let first = try XCTUnwrap(DailyPuzzle.choose(day: key, puzzles: puzzles))
        XCTAssertEqual(first.id, DailyPuzzle.choose(day: key, puzzles: puzzles.reversed())?.id)
        XCTAssertTrue((1000...2200).contains(first.sourceRating))
        XCTAssertNil(DailyPuzzle.choose(day: key, puzzles: []))
        let saved = DailyPuzzleRecord(puzzleID: puzzles[0].id, correct: true)
        XCTAssertEqual(DailyPuzzle.choose(day: key, puzzles: puzzles, saved: saved)?.id, saved.puzzleID)
    }
    func testDailyResultCountsOnceAcrossRestartAndCompletionRetainsFirstAttempt() throws {
        let puzzle = try XCTUnwrap(TrainingAssets.puzzles().first)
        var state = LibraryState()
        XCTAssertTrue(state.recordPuzzle(puzzle, correct: false, daily: "2026-11-12"))
        state.completeDailyPuzzle(day: "2026-11-12")
        state = try JSONDecoder().decode(LibraryState.self, from: JSONEncoder().encode(state))
        let rating = state.puzzle.rating
        XCTAssertFalse(state.recordPuzzle(puzzle, correct: true, daily: "2026-11-12"))
        XCTAssertEqual(state.puzzle.attempts, 1); XCTAssertEqual(state.puzzle.rating, rating)
        XCTAssertEqual(state.dailyPuzzles["2026-11-12"]?.correct, false)
        XCTAssertEqual(state.dailyPuzzles["2026-11-12"]?.completed, true)
        XCTAssertTrue(state.recordPuzzle(puzzle, correct: true, daily: "2026-11-13"))
        XCTAssertEqual(state.puzzle.attempts, 2)
    }
    func testDailyFieldMigratesOlderLibraries() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(LibraryState())) as? [String: Any])
        object.removeValue(forKey: "dailyPuzzles")
        let decoded = try JSONDecoder().decode(LibraryState.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(decoded.dailyPuzzles.isEmpty)
    }
    func testAssessmentPersistsTopMoveAndExactTopSelection() throws {
        let before = try VariantSnapshot.parse("fen\t\(Position.initial.fen)\nstatus\tongoing\nmove\te2e4\te4\nmove\td2d4\td4")
        var board = Position.initial; try board.apply(uci: "d2d4")
        let after = try VariantSnapshot.parse("fen\t\(board.fen)\nstatus\tongoing")
        let line = EngineLine(depth: 20, rank: 1, centipawns: 0, mate: nil, moves: ["e2e4"])
        let different = MoveAssessment.make(ply: 0, move: before.moves[1], before: before, after: after, baseline: line, outcome: line)
        XCTAssertEqual(different.bestSAN, "e4"); XCTAssertFalse(different.playedTopMove)
        let top = MoveAssessment.make(ply: 0, move: before.moves[0], before: before, after: after, baseline: line, outcome: line)
        XCTAssertTrue(top.playedTopMove)
        let restored = try JSONDecoder().decode(MoveAssessment.self, from: JSONEncoder().encode(top))
        XCTAssertEqual(restored.bestUCI, "e2e4")
    }
    func testPerformanceEstimatesSeparateSidesAndNeedEnoughEvidence() {
        let good = MoveAssessment(ply: 0, side: .white, uci: "e2e4", san: "e4", quality: .good, loss: 20, depth: 20)
        let poor = MoveAssessment(ply: 1, side: .black, uci: "e7e5", san: "e5", quality: .mistake, loss: 200, depth: 20)
        let moves = Array(repeating: good, count: 8) + Array(repeating: poor, count: 8)
        XCTAssertGreaterThan(ReviewSummary(moves, side: .white).performanceEstimate ?? 0, ReviewSummary(moves, side: .black).performanceEstimate ?? 0)
        XCTAssertNil(ReviewSummary([good], side: .white).performanceEstimate)
    }
    func testImprovementPatternsAggregateOnlyPlayersMovesAndDeduplicateGames() {
        let game = SavedComputerGame(mode: .normal, human: .white, targetRating: 1000)
        var entry = CompletedGame(game: game, result: "draw"), review = GameReview(signature: "test")
        let suggestion = GameSuggestion(ply: 0, number: 1, side: .white, played: "e4", recommended: ["d4"], recommendedUCI: ["d2d4"], source: .engine, concept: .calculation, explanation: "", repertoireIDs: [])
        var opponent = suggestion; opponent.ply = 1; opponent.side = .black
        review.suggestions = [suggestion, suggestion, opponent]; entry.review = review
        let stats = ImprovementStatistics(history: [entry, entry])
        XCTAssertEqual(stats.reviewedGames, 1); XCTAssertEqual(stats.counts[.calculation], 1)
    }
}
