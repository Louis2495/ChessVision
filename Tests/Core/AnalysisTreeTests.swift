import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class AnalysisTreeTests: XCTestCase {
    private func positions(_ moves: [String]) throws -> [Position] {
        var board = Position.initial, result = [board]
        for move in moves { try board.apply(uci: move); result.append(board) }
        return result
    }
    func testBranchPreservationPromotionDemotionAndSubtreeDeletion() throws {
        var tree = AnalysisTree(position: .initial)
        let main = try positions(["e2e4","e7e5","g1f3"])
        let alternative = try positions(["e2e4","c7c5","g1f3"])
        let first = tree.record(main), second = tree.record(alternative)
        XCTAssertEqual(tree.leaves.count, 2)
        XCTAssertEqual(tree.positions(tree.mainLine), main)
        tree.promote(second[2]); XCTAssertEqual(tree.positions(tree.mainLine), alternative)
        tree.demote(second[2]); XCTAssertEqual(tree.positions(tree.mainLine), main)
        tree.delete(first[2])
        XCTAssertNil(tree.nodes[first[2]]); XCTAssertNil(tree.nodes[first[3]])
        XCTAssertEqual(tree.positions(tree.mainLine), alternative)
        XCTAssertEqual(tree.leaves.count, 1)
        tree.delete(tree.root); XCTAssertNotNil(tree.nodes[tree.root])
    }
    func testReplayingExistingMoveDoesNotDuplicateOrLoseContinuation() throws {
        var tree = AnalysisTree(position: .initial)
        let line = try positions(["d2d4","d7d5"])
        tree.record(line)
        let prefix = tree.record(Array(line.prefix(2)))
        XCTAssertEqual(tree.nodes.count, 3)
        XCTAssertEqual(tree.positions(tree.continuation(from: prefix.last!)), line)
    }
    func testSavedVariationsRoundTrip() throws {
        var game = SavedBoardGame(title: "Branches", positions: [Position.initial.fen], notation: [])
        game.variations = [SavedGameVariation(title: "Main line", positions: [Position.initial.fen], notation: [])]
        let decoded = try JSONDecoder().decode(SavedBoardGame.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(decoded.variations?.first?.positions, [Position.initial.fen])
    }
}
