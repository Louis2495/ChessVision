import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif

final class PlayerPresentationTests: XCTestCase {
    func testHistoryOutcomeFollowsPlayerColor() {
        for side in [Side.white, .black] {
            let game = SavedComputerGame(mode: .normal, human: side, targetRating: 1000)
            XCTAssertEqual(CompletedGame(game: game, result: side.title.lowercased()).playerOutcome, "Win")
            XCTAssertEqual(CompletedGame(game: game, result: side.opposite.title.lowercased()).playerOutcome, "Loss")
            XCTAssertEqual(CompletedGame(game: game, result: "draw").playerOutcome, "Draw")
        }
    }
    func testBughouseHistoryUsesTeamRatherThanBoardColor() {
        for side in [Side.white, .black] {
            var entry = CompletedGame(game: SavedComputerGame(mode: .bughouse, human: side, targetRating: 1000), result: "white")
            var match = BughouseMatch(config: BughouseConfig(human: side))
            match.winner = match.config.humanTeam; entry.bughouse = match
            XCTAssertEqual(entry.playerOutcome, "Win")
            match.winner = 1 - match.config.humanTeam; entry.bughouse = match
            XCTAssertEqual(entry.playerOutcome, "Loss")
            match.winner = 2; entry.bughouse = match
            XCTAssertEqual(entry.playerOutcome, "Draw")
        }
    }
    func testVariantSymbolsAreDistinct() {
        XCTAssertEqual(Set(GameMode.allCases.map(\.symbol)).count, GameMode.allCases.count)
        XCTAssertTrue(GameMode.allCases.allSatisfy { !$0.symbol.isEmpty })
    }
    func testResignConfirmationIsOptIn() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "confirmResign")
        defer { if let previous { defaults.set(previous, forKey: "confirmResign") } else { defaults.removeObject(forKey: "confirmResign") } }
        defaults.removeObject(forKey: "confirmResign")
        XCTAssertFalse(MovePreferences.confirmResign)
        defaults.set(true, forKey: "confirmResign")
        XCTAssertTrue(MovePreferences.confirmResign)
    }
}
