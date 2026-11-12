import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif

final class InsightTests: XCTestCase {
    func testStartingPositionHasNoHangingPieceClaim() {
        XCTAssertFalse(PositionInsights.observations(in: .initial).contains { $0.contains("undefended") })
    }
    func testAttackedUndefendedPawnAndRemoval() throws {
        var board = try Position(fen: "4k3/8/8/6P1/8/8/8/4K1r1 w - - 0 1")
        XCTAssertTrue(PositionInsights.observations(in: board).contains { $0.contains("g5") && $0.contains("undefended") })
        board.squares[Position.index("g1")!] = nil
        XCTAssertFalse(PositionInsights.observations(in: board).contains { $0.contains("g5") && $0.contains("undefended") })
    }
    func testBishopBoxedInByOwnPawns() throws {
        let board = try Position(fen: "4k3/8/8/8/8/8/1P1P4/2B1K3 w - - 0 1")
        XCTAssertTrue(PositionInsights.observations(in: board).contains { $0.contains("c1") && $0.contains("boxed in") })
    }
    func testVariantOrderAnd960Save() throws {
        XCTAssertEqual(Array(GameMode.allCases.prefix(6)), [.normal, .crazyhouse, .fogOfWar, .chess960, .threeCheck, .kingOfTheHill])
        XCTAssertEqual(Array(GameMode.allCases.suffix(2)), [.blindBoard, .blindText])
        var game = SavedComputerGame(mode: .chess960, human: .white, targetRating: 1200)
        game.chess960Index = 518
        let restored = try JSONDecoder().decode(SavedComputerGame.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(restored.variant, "cv960518")
    }
}

extension InsightTests {
    func testPinsAndOpenFilesAreExplained() throws {
        let board = try Position(fen: "4r1k1/8/8/8/8/8/4N3/4K3 w - - 0 1")
        let notes = PositionInsights.observations(in: board)
        XCTAssertTrue(notes.contains { $0.contains("e2") && $0.contains("pinned") })
        XCTAssertTrue(notes.contains { $0.contains("open file") })
    }
    func testPawnStructureAndPassedPawnsAreIndependentFindings() throws {
        let board = try Position(fen: "6k1/7p/8/2P5/2P5/8/P7/6K1 w - - 0 1")
        let notes = PositionInsights.observations(in: board)
        XCTAssertTrue(notes.contains { $0.contains("doubled") })
        XCTAssertTrue(notes.contains { $0.contains("isolated") })
        XCTAssertTrue(notes.contains { $0.contains("passed pawn") })
    }
    func testPawnForkAndEngineContinuation() throws {
        let fork = try Position(fen: "6k1/8/3n1r2/4P3/8/8/8/6K1 w - - 0 1")
        XCTAssertTrue(PositionInsights.observations(in: fork).contains { $0.contains("pawn fork") })
        let line = EngineLine(depth: 18, rank: 1, centipawns: 25, mate: nil, moves: ["e2e4", "e7e5"])
        let notes = PositionInsights.observations(in: .initial, engine: line)
        XCTAssertTrue(notes.contains { $0.contains("Engine plan: e4") && $0.contains("e5") })
        XCTAssertTrue(notes.contains { $0.contains("depth 18") })
        XCTAssertFalse(notes.contains { $0.contains("captures") })
    }
    func testOpeningPrioritiesAreNotNormalBlockedBishopWarnings() {
        let notes = PositionInsights.observations(in: .initial)
        XCTAssertTrue(notes.contains { $0.contains("Development") })
        XCTAssertFalse(notes.contains { $0.contains("boxed in") })
    }
    func testGameRecordingCustomStartBranchAndTurnEdit() throws {
        var start = Position.initial; start.fullmove = 12; start.turn = .black
        let e5 = try start.playing(start.move(forSAN: "e5"))
        let nf3 = try e5.playing(e5.move(forSAN: "Nf3"))
        let line = try GameRecording.build(from: [start, e5, nf3])
        XCTAssertEqual(line.moves.map(\.san), ["e5", "Nf3"])
        XCTAssertEqual(line.moves.map(\.number), [12, 13])
        XCTAssertEqual(line.moves.first?.side, .black)
        let nc3 = try e5.playing(e5.move(forSAN: "Nc3"))
        XCTAssertEqual(try GameRecording.build(from: [start, e5, nc3]).moves.map(\.san), ["e5", "Nc3"])
        var edited = nf3; edited.turn = .white
        let d4 = try edited.playing(edited.move(forSAN: "d4"))
        let reset = try GameRecording.build(from: [start, e5, nf3, edited, d4])
        XCTAssertEqual(reset.startIndex, 3)
        XCTAssertEqual(reset.moves.map(\.san), ["d4"])
    }
}

extension InsightTests {
    func testDeadMaterialAndDrawClaimAreExplainedInsteadOfPlans() throws {
        let kings = try Position(fen: "7k/8/8/8/8/8/8/K7 w - - 0 1")
        XCTAssertEqual(PositionInsights.observations(in: kings), ["The position is drawn by insufficient mating material."])
        var position = Position.initial; position.halfmove = 100
        XCTAssertTrue(PositionInsights.observations(in: position).contains { $0.contains("50-move rule") })
    }
}
