import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class PlayProgressTests: XCTestCase {
    func testRatedResultsPersistAndSettleExactlyOnce() throws {
        var progress = PlayProgress(), game = SavedComputerGame(mode: .normal, human: .white, targetRating: 1000)
        game.rated = true
        XCTAssertEqual(progress.finish(game, result: "white"), 32)
        XCTAssertNil(progress.finish(game, result: "white"))
        XCTAssertEqual(progress.rating(for: .normal).games, 1)
        XCTAssertEqual(progress.completed, 1)
        let restored = try JSONDecoder().decode(PlayProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(restored.rating(for: .normal).value, 1032)
        XCTAssertEqual(restored.achievements[Achievement.firstWin.rawValue] != nil, true)
    }
    func testUnratedAndAdaptiveGamesDoNotChangeRating() {
        var progress = PlayProgress(), game = SavedComputerGame(mode: .normal, human: .black, targetRating: 1400)
        game.adaptive = true
        XCTAssertNil(progress.finish(game, result: "black"))
        XCTAssertEqual(progress.rating(for: .normal).games, 0)
        XCTAssertEqual(progress.completed, 1)
    }
    func testDifferentModesHaveSeparateRatingsAndLossesReduceRating() {
        var progress = PlayProgress(), game = SavedComputerGame(mode: .threeCheck, human: .white, targetRating: 1000)
        game.rated = true
        XCTAssertEqual(progress.finish(game, result: "black"), -32)
        XCTAssertEqual(progress.rating(for: .normal).value, 1000)
        XCTAssertEqual(progress.rating(for: .threeCheck).value, 968)
    }
    func testAdaptiveDifficultyChangesBothDirectionsAndIsBounded() {
        XCTAssertLessThan(AdaptiveStrength.adjusted(1600, loss: 300), 1600)
        XCTAssertGreaterThan(AdaptiveStrength.adjusted(1600, loss: 0), 1600)
        XCTAssertEqual(AdaptiveStrength.adjusted(100, loss: 500), 100)
        XCTAssertEqual(AdaptiveStrength.adjusted(3500, loss: 0), 3500)
    }
    func testLegacyLibraryWithoutNewFieldsMigrates() throws {
        // Use the current puzzle representation while omitting all new game progress fields.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(LibraryState())) as? [String: Any])
        json.removeValue(forKey: "playProgress")
        let restored = try JSONDecoder().decode(LibraryState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.playProgress.rating(for: .normal).value, 1000)
        XCTAssertTrue(restored.history.isEmpty)
    }
    func testThreePremovesCancelNewestOnePerUnrelatedTap() {
        var queue = PremoveQueue(), composer = PremoveComposer()
        ["e2e4", "g1f3", "f3g5"].forEach { queue.append($0) }
        for expected in [2,1,0] {
            composer.tap(Position.index("a5")!, board: queue.projected(.initial, side: .white), side: .white, duck: false, queue: &queue)
            XCTAssertEqual(queue.moves.count, expected)
        }
    }
    func testPawnCheckmateAchievementRequiresActualPawnMate() throws {
        let position = try Position(fen: "7k/5K2/6P1/8/8/3B4/8/8 w - - 0 1")
        XCTAssertEqual(PlayProgress.matingAchievement(before: position, uci: "g6g7"), .pawnMate)
        XCTAssertNil(PlayProgress.matingAchievement(before: .initial, uci: "e2e4"))
    }
    func testPawnPromotionDoesNotFalselyAwardPawnCheckmate() {
        var progress = PlayProgress()
        let game = SavedComputerGame(mode: .normal, human: .white, targetRating: 1000, moves: ["a7a8q"])
        progress.finish(game, result: "white")
        XCTAssertNil(progress.achievements[Achievement.pawnMate.rawValue])
    }
}
