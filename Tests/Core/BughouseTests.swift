import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif

final class BughouseTests: XCTestCase {
    func testTeamsAreDiagonalAndEachSeatHasItsOwnRating() throws {
        let config = BughouseConfig(human: .black, ratings: [700,1200,1800,2300])
        try config.validate()
        XCTAssertEqual(BughouseConfig.team(0, .white), BughouseConfig.team(1, .black))
        XCTAssertEqual(BughouseConfig.team(0, .black), BughouseConfig.team(1, .white))
        XCTAssertEqual(config.humanTeam, 1)
        XCTAssertEqual(config.ratings[BughouseConfig.seat(1, .white)], 1800)
        XCTAssertThrowsError(try BughouseConfig(ratings: [1000]).validate())
    }
    func testPocketDeliveryPreservesColorAndFenState() throws {
        let fen = Position.initial.fen.replacingOccurrences(of: " w ", with: "[] w ")
        let delivered = try BughouseMatch.delivered("p", to: fen)
        let snapshot = try VariantSnapshot.parse("fen\t\(delivered)\nstatus\tongoing")
        XCTAssertEqual(snapshot.pockets, [Piece("p")])
        XCTAssertEqual(snapshot.board.turn, .white)
        XCTAssertThrowsError(try BughouseMatch.delivered("K", to: fen))
    }
    func testFourClocksCanRestoreWithoutChargingPausedTime() {
        let control = ClockTimeControl(seconds: 300, increment: 2)
        var clock = ChessClock(control: control, white: 120, black: 80, active: .black)
        XCTAssertEqual(clock.remaining(for: .black, at: 900), 80)
        clock.start(at: 1000)
        XCTAssertEqual(clock.deadline, 1080)
        clock.press(.black, at: 1005)
        XCTAssertEqual(clock.remaining(for: .black, at: 1010), 77)
        XCTAssertEqual(clock.active, .white)
    }
    func testBughouseHistoryHasHumanMoveCountsAndTeamResult() throws {
        var match = BughouseMatch(config: BughouseConfig(human: .black))
        match.events = [BughouseEvent(board: 1, side: .white, number: 1, uci: "e2e4", san: "e4"), BughouseEvent(board: 0, side: .white, number: 1, uci: "d2d4", san: "d4"), BughouseEvent(board: 0, side: .black, number: 1, uci: "d7d5", san: "d5")]
        match.winner = 1
        var proxy = SavedComputerGame(mode: .bughouse, human: .black, targetRating: 1000, moves: match.events.map(\.uci)); proxy.id = match.id
        var entry = CompletedGame(game: proxy, result: "black"); entry.bughouse = match
        XCTAssertEqual(entry.humanMoveCount, 1)
        XCTAssertEqual(entry.resultTitle, "Your team wins")
        let roundtrip = try JSONDecoder().decode(CompletedGame.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(roundtrip.bughouse?.events.count, 3)
    }
}
