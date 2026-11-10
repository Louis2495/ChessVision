import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import ChessVision
#endif

final class ExpansionTests: XCTestCase {
    func testExactly2000UniquePuzzlesAndAllSolutionPliesAreLegal() throws {
        let puzzles = try TrainingAssets.puzzles()
        XCTAssertEqual(puzzles.count, 2000); XCTAssertEqual(Set(puzzles.map(\.id)).count, 2000)
        for puzzle in puzzles {
            var board = try Position(fen: puzzle.fen)
            XCTAssertTrue(board.problems.isEmpty, puzzle.id)
            XCTAssertGreaterThanOrEqual(puzzle.moves.count, 2)
            for uci in puzzle.moves {
                let move = try XCTUnwrap(board.legalMoves().first { $0.uci == uci }, puzzle.id + ": " + uci)
                board = try board.playing(move)
            }
            XCTAssertEqual(puzzle.estimatedRating, max(200, Int((Double(puzzle.sourceRating) * 0.8 / 50).rounded()) * 50))
            _ = try puzzle.startingPosition()
        }
    }
    func testPuzzleProgressStartsAt1000AndAdaptsBothWays() throws {
        let puzzle = try XCTUnwrap(TrainingAssets.puzzles().min { abs($0.estimatedRating - 1000) < abs($1.estimatedRating - 1000) })
        var progress = PuzzleProgress(); XCTAssertEqual(progress.rating, 1000)
        progress.record(puzzle, correct: true); XCTAssertGreaterThan(progress.rating, 1000)
        let raised = progress.rating; progress.record(puzzle, correct: false)
        XCTAssertLessThan(progress.rating, raised); XCTAssertEqual(progress.attempts, 2); XCTAssertEqual(progress.solved, 1)
        XCTAssertEqual(progress.completed.count, 1)
    }
    func testNextPuzzleTracksRatingAndAvoidsCompletedItems() throws {
        let puzzles = try TrainingAssets.puzzles(); var progress = PuzzleProgress()
        let first = try XCTUnwrap(progress.next(in: puzzles)); XCTAssertLessThanOrEqual(abs(first.estimatedRating - 1000), 50)
        progress.record(first, correct: true)
        XCTAssertNotEqual(progress.next(in: puzzles)?.id, first.id)
        progress.rating = 2000; XCTAssertLessThanOrEqual(abs(try XCTUnwrap(progress.next(in: puzzles)).estimatedRating - 2000), 100)
    }
    func testStrongPlayerPlacementReaches2000WithinSixPuzzles() throws {
        let puzzles = try TrainingAssets.puzzles()
        var progress = PuzzleProgress()
        for _ in 0..<6 { progress.record(try XCTUnwrap(progress.next(in: puzzles)), correct: true) }
        XCTAssertGreaterThanOrEqual(progress.rating, 2000)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(progress.next(in: puzzles)).estimatedRating, 1950)
        let before = progress.rating
        progress.record(try XCTUnwrap(progress.next(in: puzzles)), correct: false)
        XCTAssertLessThan(progress.rating, before)
    }
    func testMissingPGNDoesNotDiscardArchive() throws {
        let data = Data(#"{"games":[{"rules":"chess"},{"pgn":42},{"pgn":"1. e4 e5 1-0","rules":"chess"}]}"#.utf8)
        let month = try JSONDecoder().decode(PublicGames.ChessComMonth.self, from: data)
        XCTAssertEqual(month.unreadable, 1)
        XCTAssertNil(try PublicGames.chessComGame(month.games[0]))
        XCTAssertEqual(try PublicGames.chessComGame(month.games[1])?.moves, ["e2e4", "e7e5"])
    }
    func testFogNeverRevealsOpponentArmyAtStart() {
        let hidden = FogVisibility.hidden(in: .initial, for: .white)
        for index in 0..<16 { XCTAssertTrue(hidden.contains(index)) }
        for index in 48..<64 { XCTAssertFalse(hidden.contains(index)) }
        XCTAssertFalse(hidden.contains(Position.index("e4")!))
    }
    func testDuckCompoundMovesAndNeutralSquare() throws {
        let state = try VariantSnapshot.parse("fen\trnbqkbnr/pppppppp/8/8/4P3/3*4/PPPP1PPP/RNBQKBNR b KQkq - 0 1\nstatus\tongoing\nmove\ta7a6,a6e4\ta6,e4")
        XCTAssertEqual(state.duckSquare, Position.index("d3"))
        XCTAssertNil(state.board.squares[Position.index("d3")!])
        XCTAssertEqual(state.moves[0].from, Position.index("a7"))
        XCTAssertEqual(state.moves[0].duckDestination, Position.index("e4"))
    }
    func testOldPuzzleProgressKeepsHistoryAndGetsFreshPlacement() throws {
        let data = Data(#"{"rating":1100,"attempts":80,"solved":70,"completed":["old"]}"#.utf8)
        var progress = try JSONDecoder().decode(PuzzleProgress.self, from: data)
        XCTAssertEqual(progress.attempts, 80); XCTAssertEqual(progress.completed, ["old"])
        XCTAssertEqual(progress.placementAttempts, 0)
        let puzzles = try TrainingAssets.puzzles()
        progress.record(try XCTUnwrap(progress.next(in: puzzles)), correct: true)
        XCTAssertGreaterThan(progress.rating, 1250)
    }
    func testRecordedChessComExport() throws {
        #if SWIFT_PACKAGE
        let url = try XCTUnwrap(Bundle.module.url(forResource: "ChessComRecorded", withExtension: "pgn"))
        #else
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "ChessComRecorded", withExtension: "pgn", subdirectory: "Reference"))
        #endif
        let pgn = try String(contentsOf: url, encoding: .utf8)
        let game = try PGNGame.parse(pgn, maxPlies: 40)
        XCTAssertEqual(game.tags["White"], "FabianoCaruana")
        XCTAssertEqual(game.moves.count, 40)
    }
    func testAllOpeningLinesAndKeysAreValid() throws {
        let lines = try TrainingAssets.openings(); XCTAssertGreaterThan(lines.count, 1000)
        XCTAssertEqual(Set(lines.map(\.id)).count, lines.count)
        for line in lines {
            var board = Position.initial
            for uci in line.moves { let move = try XCTUnwrap(board.legalMoves().first { $0.uci == uci }, line.name); board = try board.playing(move) }
            XCTAssertEqual(board.openingKey, line.key, line.name)
        }
    }
    func testPGNMainLineCommentsVariationsAndMoveNumbers() throws {
        let game = try PGNGame.parse("""
        [White "Alice"]
        [Black "Bob"]
        [Result "1-0"]

        1.e4 { [%clk 0:05:00] } e5 2.Nf3 (2. Bc4 Nc6 (2... Nf6)) Nc6 $1
        3.Bb5 a6 ; a line comment
        4.Ba4 Nf6 1-0
        """)
        XCTAssertEqual(game.tags["White"], "Alice")
        XCTAssertEqual(game.moves, ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6"])
        XCTAssertThrowsError(try PGNGame.parse("1. e5"))
        XCTAssertThrowsError(try PGNGame.parse("1. e4 { open"))
    }
    func testPGNPrefixLimitAndSANInput() throws {
        let game = try PGNGame.parse("1. e4 e5 2. Nf3 Nc6 3. Bc4", maxPlies: 3)
        XCTAssertEqual(game.moves.count, 3)
        XCTAssertEqual(try Position.initial.move(forSAN: "e4!").uci, "e2e4")
        XCTAssertEqual(try Position.initial.move(forSAN: "g1f3").uci, "g1f3")
    }
    func testOpeningTreeResultsAndInvalidGameAtomicity() throws {
        var tree = OpeningTree()
        try tree.add(OpeningGame(white: "Alice", black: "Bob", result: .white, moves: ["e2e4", "e7e5"]))
        try tree.add(OpeningGame(white: "Bob", black: "Alice", result: .draw, moves: ["e2e4", "c7c5"]))
        let root = try XCTUnwrap(tree.branches(at: .initial).first)
        XCTAssertEqual(root.san, "e4"); XCTAssertEqual(root.counts.games, 2); XCTAssertEqual(root.counts.whiteWins, 1); XCTAssertEqual(root.counts.draws, 1)
        var e4 = Position.initial; try e4.apply(uci: "e2e4")
        XCTAssertEqual(tree.branches(at: e4).count, 2)
        XCTAssertThrowsError(try tree.add(OpeningGame(white: "A", black: "B", result: .black, moves: ["d2d4", "e7e4"])))
        XCTAssertEqual(tree.gameCount, 2); XCTAssertEqual(tree.branches(at: .initial).count, 1)
    }
    func testTranspositionsAndRepertoireBranches() throws {
        let a = try PGNGame.parse("1. Nf3 Nf6 2. d4 d5")
        let b = try PGNGame.parse("1. d4 d5 2. Nf3 Nf6")
        var left = Position.initial, right = Position.initial
        for move in a.moves { try left.apply(uci: move) }; for move in b.moves { try right.apply(uci: move) }
        XCTAssertEqual(left.openingKey, right.openingKey)
        let lines = [RepertoireLine(name: "King pawn", side: .white, moves: ["e2e4", "e7e5"]), RepertoireLine(name: "Queen pawn", side: .white, moves: ["d2d4", "d7d5"])]
        XCTAssertEqual(Set(RepertoireTraining.choices(at: .initial, in: lines).map(\.move)), Set(["e2e4", "d2d4"]))
    }
    func testRepertoireNeedsMovesForTheTrainingSide() {
        XCTAssertThrowsError(try RepertoireLine(name: "Black line", side: .black, moves: ["e2e4"]).validated())
        XCTAssertNoThrow(try RepertoireLine(name: "Black line", side: .black, moves: ["e2e4", "e7e5"]).validated())
    }
    func testLibraryRoundTripAndSevenGameStyles() throws {
        var state = LibraryState()
        state.repertoire = [RepertoireLine(name: "Italian", side: .white, moves: ["e2e4", "e7e5", "g1f3"])]
        state.computer = SavedComputerGame(mode: .crazyhouse, human: .black, targetRating: 1400, moves: ["e2e4"])
        state.computer?.notation = ["e4"]
        let decoded = try JSONDecoder().decode(LibraryState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.repertoire.first?.name, "Italian"); XCTAssertEqual(decoded.computer?.notation, ["e4"])
        XCTAssertEqual(GameMode.allCases.count, 14); XCTAssertEqual(GameMode.blindText.variant, "chess")
        XCTAssertEqual(GameMode.horde.variant, "horde"); XCTAssertEqual(GameMode.crazyhouse.variant, "crazyhouse")
    }
    func testPublicGameExportDecodingAndUsernameValidation() throws {
        let raw = #"{"games":[{"pgn":"[White \"Alice\"]\n[Black \"Bob\"]\n[Result \"1-0\"]\n\n1. e4 e5 2. Nf3 Nc6 1-0","rules":"chess"}]}"#.data(using: .utf8)!
        let month = try JSONDecoder().decode(PublicGames.ChessComMonth.self, from: raw)
        let game = try XCTUnwrap(PublicGames.chessComGame(month.games[0]))
        XCTAssertEqual(game.white, "Alice"); XCTAssertEqual(game.result, .white); XCTAssertEqual(game.moves.count, 4)
        let lichess = #"{"players":{"white":{"user":{"name":"Alice"}},"black":{"user":{"name":"Bob"}}},"variant":"standard","status":"mate","winner":"black","moves":"e4 e5 Nf3 Nc6"}"#.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(PublicGames.LichessGame.self, from: lichess)
        XCTAssertEqual(try parsed.openingGame()?.result, .black)
        var unfinished = parsed; unfinished.status = "started"; unfinished.winner = nil
        XCTAssertNil(try unfinished.openingGame())
        unfinished.status = "unknownFinish"; XCTAssertNil(try unfinished.openingGame())
        XCTAssertTrue(PublicGames.validUsername("Alice_123")); XCTAssertFalse(PublicGames.validUsername("../Alice")); XCTAssertFalse(PublicGames.validUsername("Alice?token=x"))
    }
    func testVariantSnapshotPreservesPocketsAndCheckCounters() throws {
        let crazy = try VariantSnapshot.parse("fen\t4k3/8/8/8/8/8/8/4K3[PNq] w - - 0 1\nturn\tw\ncheck\t0\nstatus\tongoing\nmove\tN@f7\tN@f7+\n")
        XCTAssertEqual(crazy.pockets.map(\.symbol), ["P", "N", "q"])
        XCTAssertEqual(try crazy.move(named: "N@f7").to, Position.index("f7"))
        let three = try VariantSnapshot.parse("fen\t4k3/8/8/8/8/8/8/4K3 w - - 2+1 0 1\nstatus\twhite\ncheck\t0\n")
        XCTAssertEqual(three.checksRemaining, "2+1"); XCTAssertTrue(three.finished); XCTAssertEqual(three.result, "White wins")
    }
    func testOpeningGameRepetitionsAreCountedOncePerPosition() throws {
        var tree = OpeningTree()
        try tree.add(OpeningGame(white: "A", black: "B", result: .draw, moves: ["g1f3", "g8f6", "f3g1", "f6g8", "g1f3"]))
        XCTAssertEqual(tree.nodes[Position.initial.openingKey]?.counts.games, 1)
    }
}
