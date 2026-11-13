import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class PuzzleStreakTests: XCTestCase {
    func testConsecutiveCorrectAttemptsIncrementAndIncorrectResets() throws {
        let puzzle = try XCTUnwrap(TrainingAssets.puzzles().first)
        var progress = PuzzleProgress()
        XCTAssertEqual(progress.streak, 0)
        for expected in 1...4 { progress.record(puzzle, correct: true); XCTAssertEqual(progress.streak, expected) }
        XCTAssertEqual(progress.solved, 4)
        progress.record(puzzle, correct: false)
        XCTAssertEqual(progress.streak, 0); XCTAssertEqual(progress.solved, 4)
        progress.record(puzzle, correct: true)
        XCTAssertEqual(progress.streak, 1); XCTAssertEqual(progress.solved, 5); XCTAssertEqual(progress.attempts, 6)
    }
    func testStreakPersistsAndOldProgressStartsAtZero() throws {
        let puzzle = try XCTUnwrap(TrainingAssets.puzzles().first)
        var progress = PuzzleProgress(); progress.record(puzzle, correct: true); progress.record(puzzle, correct: true)
        let restored = try JSONDecoder().decode(PuzzleProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(restored.streak, 2); XCTAssertEqual(restored.solved, 2)
        let legacy = Data(#"{"rating":1500,"attempts":70,"solved":60,"completed":["old"],"scaleVersion":1}"#.utf8)
        let old = try JSONDecoder().decode(PuzzleProgress.self, from: legacy)
        XCTAssertEqual(old.streak, 0); XCTAssertEqual(old.solved, 60); XCTAssertEqual(old.completed, ["old"])
    }
    func testDailyReplaysDoNotAlterStreakOrEraseFirstAttempt() throws {
        let puzzle = try XCTUnwrap(TrainingAssets.puzzles().first)
        var state = LibraryState()
        XCTAssertTrue(state.recordPuzzle(puzzle, correct: true, daily: "day-1"))
        XCTAssertEqual(state.puzzle.streak, 1)
        state.completeDailyPuzzle(day: "day-1")
        XCTAssertFalse(state.recordPuzzle(puzzle, correct: false, daily: "day-1"))
        XCTAssertEqual(state.puzzle.streak, 1)
        XCTAssertTrue(state.recordPuzzle(puzzle, correct: false, daily: "day-2"))
        XCTAssertEqual(state.puzzle.streak, 0)
        state.completeDailyPuzzle(day: "day-2")
        XCTAssertFalse(state.recordPuzzle(puzzle, correct: true, daily: "day-2"))
        XCTAssertEqual(state.puzzle.streak, 0); XCTAssertEqual(state.puzzle.solved, 1)
    }
    func testNewActionColorsRetainReadableContrast() {
        for background: UInt32 in [0x39D5F5, 0x8D4DE8] {
            let foreground = InterfaceContrast.foreground(on: background)
            let a = InterfaceContrast.luminance(background), b = InterfaceContrast.luminance(foreground)
            XCTAssertGreaterThanOrEqual((max(a,b)+0.05)/(min(a,b)+0.05), 4.5)
        }
    }
}
