import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if os(Linux)
import Glibc
#else
import Darwin
#endif

@main struct FeatureChecks {
    enum Failure: Error { case failed(String) }
    static func require(_ value: Bool, _ message: String) throws { if !value { throw Failure.failed(message) } }
    @MainActor static func wait(_ predicate: () -> Bool) async throws {
        for _ in 0..<1200 { if predicate() { return }; try await Task.sleep(for: .milliseconds(50)) }
        throw Failure.failed("Feature workflow timed out")
    }
    @MainActor static func publicAPIChecks() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [PublicAPIStub.self]
        let service = PublicGameService(session: URLSession(configuration: config))
        let chesscom = try await service.load(site: .chesscom, username: "Alice") { _ in }
        try require(chesscom.games.count == 1 && chesscom.games[0].moves == ["e2e4", "e7e5"], "Chess.com export import failed")
        let fallback = try await service.load(site: .chesscom, username: "Fallback") { _ in }
        try require(fallback.games.count == 2, "Missing JSON game fields did not fall back to PGN")
        let lichess = try await service.load(site: .lichess, username: "Alice") { _ in }
        try require(lichess.games.count == 1 && lichess.fetched == 2 && lichess.skipped == 1, "Lichess NDJSON import/variant filter failed")
        do { _ = try await service.load(site: .chesscom, username: "Missing") { _ in }; throw Failure.failed("404 was accepted") }
        catch let error as ChessError { try require(error.localizedDescription.contains("not found"), "Missing-profile error was lost") }
        let bulkChess = try await service.load(site: .chesscom, username: "Bulk") { _ in }
        try require(bulkChess.games.count == 1200, "Archive import stopped at 1000 or skipped older months")
        let bulkLichess = try await service.load(site: .lichess, username: "Bulk") { _ in }
        try require(bulkLichess.games.count == 1005, "Lichess export was capped")
        let explorer = OpeningExplorerModel(service: service)
        explorer.username = "Bulk"; explorer.load()
        explorer.cancel()
        explorer.username = "Alice"; explorer.load()
        try await wait { !explorer.busy }
        try require(explorer.error == nil && explorer.profileLabel == "Alice · Chess.com" && explorer.tree.gameCount == 1, "Canceled import overwrote the latest profile")
        explorer.username = "Missing"; explorer.load()
        try await wait { !explorer.busy }
        try require(explorer.error != nil && explorer.tree.gameCount == 1 && explorer.profileLabel == "Alice · Chess.com", "Failed import discarded previous results")
        explorer.filter = .black; explorer.refilter()
        try await wait { !explorer.busy }
        try require(explorer.error == nil && explorer.tree.gameCount == 0, "Refilter retained an obsolete import error")
        explorer.filter = .white; explorer.refilter()
        explorer.cancel()
        try await Task.sleep(for: .milliseconds(100))
        try require(!explorer.busy && explorer.status == "Import canceled.", "Canceled filter changed state after cancellation")
        print("PASS: public API fixtures, cancellation/restart, failure preservation and filter error recovery.")
    }
    @MainActor static func main() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NovaChess-features-\(UUID().uuidString)")
        do {
            let root = URL(fileURLWithPath: CommandLine.arguments[1])
            let puzzles = try JSONDecoder().decode([ChessPuzzle].self, from: Data(contentsOf: root.appendingPathComponent("NovaChess/Core/Resources/Puzzles.json")))
            let openings = try JSONDecoder().decode([OpeningLine].self, from: Data(contentsOf: root.appendingPathComponent("NovaChess/Core/Resources/Openings.json")))
            let store = LibraryStore(directory: directory, puzzles: puzzles, openings: openings)
            store.state.repertoire = [RepertoireLine(name: "Test line", side: .white, moves: ["e2e4", "e7e5"])]
            store.state.puzzle.record(puzzles[0], correct: true)
            let restored = LibraryStore(directory: directory, puzzles: puzzles, openings: openings)
            try require(restored.state.repertoire.first?.name == "Test line" && restored.state.puzzle.attempts == 1, "Local library did not persist")
            try await publicAPIChecks()
            try await EngineController.shared.prepareVariant("bughouse")
            var linked = [try BughouseRules.snapshot(), try BughouseRules.snapshot()]
            for move in ["e2e4", "d7d5", "e4d5"] { try BughouseRules.play(move, on: 0, states: &linked) }
            try require(linked[0].pockets.isEmpty && linked[1].pockets.filter { $0.symbol == "p" }.count == 1, "Capture did not go exclusively to partner's pocket")
            try BughouseRules.play("e2e4", on: 1, states: &linked)
            let drop = try linked[1].moves.first { $0.drop == "P" && $0.to == Position.index("e6") }.unwrap("Delivered pawn cannot be dropped")
            try require(!linked[1].moves.contains { $0.drop == "P" && ($0.to! / 8 == 0 || $0.to! / 8 == 7) }, "Illegal back-rank pawn drop")
            try BughouseRules.play(drop.uci, on: 1, states: &linked)
            try require(linked[1].pockets.isEmpty && linked[1].board.squares[Position.index("e6")!] == Piece("p"), "Drop did not consume partner's pocket")
            let promotedCapture = try BughouseRules.snapshot(fen: "r3k3/Q~7/8/8/8/8/8/7K[] b - - 0 1", move: "a8a7")
            try require(promotedCapture.transferred == "P", "Promoted piece did not revert to a pawn for partner")
            let shield = try BughouseRules.snapshot(fen: "4r1k1/8/8/8/8/8/8/4K3[N] w - - 0 1")
            try require(shield.moves.contains { $0.drop == "N" && $0.to == Position.index("e2") }, "Pocket drop could not block check")
            let bugs = BughouseModel(); bugs.attach(store)
            bugs.newMatch(BughouseConfig(human: .white, ratings: [1200,800,1300,1800], seconds: 30, increment: 1))
            try await wait { !bugs.loading && bugs.states.count == 2 && bugs.running }
            bugs.play(try bugs.states[0].move(named: "e4"))
            bugs.premoves.append("g1f3"); bugs.premoves.append("f3g5")
            try await wait { (bugs.match?.events.filter { $0.board == 0 }.count ?? 0) >= 6 || bugs.error != nil }
            try require(bugs.premoves.moves.isEmpty && bugs.match?.events.filter { $0.board == 0 && $0.side == .white }.count == 3, "Bughouse consecutive premoves did not execute")
            try require(bugs.error == nil, "Bughouse AI failed: \(bugs.error ?? "")")
            bugs.pause()
            let savedCount = bugs.match!.events.count
            try require(store.state.bughouse?.events.count == savedCount && store.state.bughouse?.remaining.count == 4, "Bughouse session was not saved")
            bugs.resume(); try await wait { (bugs.match?.events.count ?? 0) > savedCount || bugs.error != nil }
            try require(bugs.error == nil, "Bughouse failed to resume")
            bugs.resign()
            let bugID = bugs.match!.id
            try require(store.state.history.contains { $0.id == bugID && $0.bughouse != nil }, "Bughouse match not archived")
            let bugReview = GameReviewModel(); bugReview.start(id: bugID, library: store)
            try await wait { !bugReview.busy }
            try require(bugReview.error == nil && bugReview.review?.complete == true && bugReview.partnerPositions.count == bugReview.positions.count, "Bughouse review failed: \(bugReview.error ?? "")")
            bugs.newMatch(BughouseConfig(seconds: 1, increment: 0))
            try await wait { !bugs.loading && bugs.running && bugs.match?.winner == nil }
            try await wait { bugs.match?.winner != nil || bugs.error != nil }
            try require(bugs.error == nil && bugs.match?.reason?.contains("Flag") == true, "Bughouse clocks did not end the match")
            bugs.pause()
            print("PASS: linked Bughouse capture/drop/promotion rules, four clocks, three AI seats, save/resume, flagging and two-board review."); fflush(stdout)
            let model = ComputerGameModel(); model.activate(store)
            for mode in GameMode.allCases where mode != .bughouse {
                model.mode = mode; model.human = .white; model.ratingText = "1000"
                try require(model.start(), "New game did not start")
                try await wait { !model.busy && model.snapshot != nil }
                try require(model.error == nil && model.snapshot?.board.turn == .white, "Variant setup failed: \(mode)")
                let move = (mode == .horde || mode == .duck || mode == .chess960) ? model.snapshot!.moves[0] : try model.snapshot!.move(named: "e4")
                model.play(move)
                if mode == .duck {
                    try await wait { model.computerPiecePreview != nil || !model.busy }
                    try require(model.computerPiecePreview != nil, "Duck computer piece preview was not shown")
                    let began = ProcessInfo.processInfo.systemUptime
                    try await wait { !model.busy }
                    try require(ProcessInfo.processInfo.systemUptime - began >= 0.40, "Duck was placed without the half-second pause")
                    try require(model.computerPiecePreview == nil, "Duck preview survived the completed turn")
                } else { try await wait { !model.busy } }
                try require(model.error == nil, "Computer reply failed: \(model.error ?? "")")
                try require(model.game?.moves.count == 2, "Computer did not reply in \(mode)")
                try require(model.snapshot?.board.turn == .white, "Turn did not return to the user")
                if [.threeCheck, .duck, .crazyhouse, .chess960, .antichess].contains(mode) {
                    model.resign()
                    let originalID = try (model.game?.id).unwrap("Variant game missing ID")
                    let variantReview = GameReviewModel(); variantReview.start(id: originalID, library: store)
                    try await wait { !variantReview.busy }
                    try require(variantReview.error == nil && variantReview.review?.complete == true && variantReview.positions.count == 3, "Variant review failed: \(mode.title), \(variantReview.error ?? "")")
                    model.undo(); try await wait { !model.busy }
                    try require(model.game?.id != originalID && store.state.history.contains { $0.id == originalID }, "Takeback changed the archived result instead of creating a new game")
                } else { model.undo(); try await wait { !model.busy } }
                try require(model.game?.moves.isEmpty == true, "Takeback did not restore the start")
                print("Checked model: \(mode.title)"); fflush(stdout)
            }
            // A deterministic book reply tests actual model scheduling through two queued turns.
            let premoveBook = try openings.first(where: { $0.moves.count >= 6 }).unwrap("Missing premove opening fixture")
            model.mode = .normal; model.human = .white; model.requestedOpening = premoveBook
            try require(model.start(), "Premove setup failed"); try await wait { !model.busy }
            model.play(try model.snapshot!.move(named: premoveBook.moves[0]))
            model.premoves.append(premoveBook.moves[2]); model.premoves.append(premoveBook.moves[4])
            try await wait { !model.busy && (model.game?.moves.count ?? 0) >= 6 }
            try require(Array(model.game!.moves.prefix(6)) == Array(premoveBook.moves.prefix(6)) && model.premoves.moves.isEmpty, "Multiple premoves did not execute across consecutive computer replies")
            try require(model.start(), "Illegal premove setup failed"); try await wait { !model.busy }
            model.play(try model.snapshot!.move(named: premoveBook.moves[0]))
            model.premoves.append("a1a8"); model.premoves.append(premoveBook.moves[2])
            try await wait { !model.busy }
            try require(model.game?.moves.count == 2 && model.premoves.moves.isEmpty && model.error == nil, "Illegal premove was played or dependent queue survived")
            model.requestedOpening = nil
            print("PASS: consecutive legal premoves execute automatically; illegal intents cancel their dependent queue."); fflush(stdout)
            model.mode = .normal; model.human = .white; model.rated = true; model.adaptive = false; model.ratingText = "1000"
            try require(model.start(), "Rated game did not start"); try await wait { !model.busy }
            model.enter("e4"); try await wait { !model.busy }
            model.resign()
            let ratedGames = store.state.playProgress.rating(for: .normal).games
            try require(ratedGames == 1, "Rated result was not recorded")
            model.activate(store); try await wait { !model.busy }
            try require(store.state.playProgress.rating(for: .normal).games == ratedGames, "Rated result was recorded twice")
            let ratedMoves = model.game!.moves
            model.undo(); try require(model.game!.moves == ratedMoves, "Takeback changed a rated result")
            model.rated = false; model.adaptive = true
            try require(model.start(), "Adaptive game did not start"); try await wait { !model.busy }
            model.enter("e4"); try await wait { !model.busy }
            try require(model.error == nil && model.game?.lastAdaptedPly == 1 && model.game?.adaptiveRating != nil, "Adaptive move-quality assessment failed")
            model.pause()
            try require(store.state.computer?.adaptiveRating == model.game?.adaptiveRating, "Adaptive strength was not saved")
            model.adaptive = false; model.activate(store)
            print("PASS: persistent rated games, duplicate protection, rated takeback guard and adaptive strength updates."); fflush(stdout)
            model.mode = .duck; model.human = .black; model.ratingText = "1000"
            try require(model.start(), "Duck cancellation setup failed")
            try await wait { model.computerPiecePreview != nil }
            model.pause()
            try await Task.sleep(for: .milliseconds(600))
            try require(model.game?.moves.isEmpty == true && model.computerPiecePreview == nil, "Interrupted duck turn was partially saved")
            model.activate(store); try await wait { !model.busy }
            try require(model.error == nil && model.game?.moves.count == 1, "Interrupted duck turn did not resume safely")
            model.mode = .pawnWars; model.pawnWarsKings = false; model.human = .white
            try require(model.start(), "Pawn race setup failed"); try await wait { !model.busy }
            try require(model.error == nil && model.snapshot?.board.squares.compactMap { $0 }.allSatisfy { $0.kind == "p" } == true, "No-kings pawn race still has kings")
            model.play(model.snapshot!.moves[0]); try await wait { !model.busy }
            try require(model.error == nil && model.game?.moves.count == 2, "Pawn race computer failed")
            model.pawnWarsKings = true
            model.mode = .threeCheck; model.human = .white; model.ratingText = "1000"
            try require(model.start(), "3-Check regression setup failed"); try await wait { !model.busy }
            for _ in 0..<30 {
                guard let state = model.snapshot, !state.finished else { break }
                let move = state.moves.first(where: { $0.san.contains("+") || $0.san.contains("#") }) ?? state.moves[0]
                model.play(move); try await wait { !model.busy }
                try require(model.error == nil, "3-Check multi-move regression failed")
            }
            print("PASS: multi-turn 3-Check computer game with assertions enabled when ENGINE_ASSERTIONS=1."); fflush(stdout)
            for mode in [GameMode.normal, .horde, .crazyhouse] {
                model.mode = mode; model.human = .black; model.ratingText = "1000"
                try require(model.start(), "Black-side game did not start"); try await wait { !model.busy }
                try require(model.error == nil && model.game?.moves.count == 1 && model.snapshot?.board.turn == .black, "Computer did not open for White")
                model.play(model.snapshot!.moves[0]); try await wait { !model.busy }
                try require(model.error == nil && model.game?.moves.count == 3, "Black-side game reply failed")
            }
            for rating in [200, 500, 2850, 4000] {
                model.mode = .normal; model.human = .black; model.ratingText = String(rating)
                try require(model.start(), "Rating rejected"); try await wait { !model.busy }
                try require(model.error == nil && model.game?.moves.count == 1, "Rated engine did not respond at \(rating)")
            }
            model.mode = .normal; model.human = .white; model.ratingText = "1000"
            model.requestedOpening = try openings.first { $0.moves.count >= 4 && $0.moves.prefix(2) == ["e2e4", "e7e5"] }.unwrap("Missing book line")
            try require(model.start(), "Opening game failed"); try await wait { !model.busy }
            model.enter("e4"); try await wait { !model.busy }
            try require(model.game?.moves.prefix(2) == ["e2e4", "e7e5"], "Requested opening was not followed")
            model.resign()
            let completedID = try (model.game?.id).unwrap("Completed game has no ID")
            try require(store.state.history.contains { $0.id == completedID }, "Finished game was not archived")
            model.activate(store); try await wait { !model.busy }
            try require(store.state.history.filter { $0.id == completedID }.count == 1, "Finished game was archived twice")
            let personalized = GameReviewModel(); personalized.start(id: completedID, library: store)
            try await wait { !personalized.busy }
            try require(personalized.error == nil && personalized.review?.complete == true, "Personalized review did not complete")
            try require(personalized.review?.repertoireMatches == 1, "Saved repertoire was not checked first")
            model.pause()
            var scholar = SavedComputerGame(mode: .normal, human: .black, targetRating: 1000, moves: "e2e4 e7e5 d1h5 b8c6 f1c4 g8f6 h5f7".split(separator: " ").map(String.init))
            scholar.notation = ["e4", "e5", "Qh5", "Nc6", "Bc4", "Nf6", "Qxf7#"]
            var matingGame = scholar; matingGame.id = UUID(); matingGame.human = .white
            matingGame.moves = Array(scholar.moves.prefix(6)); matingGame.notation = Array(scholar.notation.prefix(6))
            store.state.computer = matingGame
            let finisher = ComputerGameModel(); finisher.activate(store); try await wait { !finisher.busy }
            try require(finisher.enter("Qxf7#"), "Natural checkmate move was rejected"); try await wait { !finisher.busy }
            try require(finisher.snapshot?.status == "white" && store.state.history.filter { $0.id == matingGame.id }.count == 1, "Natural checkmate was not saved exactly once")
            finisher.pause()
            let scholarID = try store.recordCompleted(scholar, result: "white").unwrap("History insertion failed")
            let reviewer = GameReviewModel(); reviewer.start(id: scholarID, library: store)
            try await wait { (reviewer.review?.assessedMoves ?? 0) >= 1 || !reviewer.busy }
            reviewer.cancel()
            let partial = try (store.state.history.first { $0.id == scholarID }?.review).unwrap("Partial review was not saved")
            try require(partial.complete == false && partial.nextPly >= 2, "Review did not checkpoint before cancellation")
            reviewer.start(id: scholarID, library: store); try await wait { !reviewer.busy }
            try require(reviewer.error == nil && reviewer.review?.complete == true, "Engine review did not resume")
            try require(reviewer.positions.count == 8, "History replay lost positions")
            try require(reviewer.review?.assessments?.count == 7, "Review did not grade both sides")
            try require(reviewer.review?.assessments?.first(where: { $0.ply == 5 })?.quality == .blunder, "Review badge missed the mating blunder")
            try require(reviewer.review?.suggestions.contains { $0.ply == 5 && $0.source == .engine } == true, "Engine missed the forced-mate blunder on Nf6")
            let restoredHistory = LibraryStore(directory: directory, puzzles: puzzles, openings: openings)
            try require(restoredHistory.state.history.contains { $0.id == scholarID && $0.review?.complete == true }, "Game/review history did not persist")
            print("PASS: automatic history, duplicate protection, repertoire-first review, forced-mate engine correction, pause/resume and persistence."); fflush(stdout)
            EngineController.shared.analyze(.initial)
            try await wait { !EngineController.shared.lines.isEmpty }
            try require(EngineController.shared.selectedVariant == "chess", "Analysis did not restore standard chess")
            EngineController.shared.stop(); try await wait { !EngineController.shared.running }
            try FileManager.default.removeItem(at: directory)
            print("PASS: real feature models: persistent library, thirteen game styles with computer replies, takebacks, opening requests, analysis handover.")
            fflush(stdout); _exit(0)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            print("FAIL: \(error)"); fflush(stdout); _exit(1)
        }
    }
}
private extension Optional {
    func unwrap(_ message: String) throws -> Wrapped {
        guard let self else { throw FeatureChecks.Failure.failed(message) }; return self
    }
}

private final class PublicAPIStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!, path = url.path.lowercased()
        var status = 200, body = ""
        if path == "/pub/player/bulk/games/archives" {
            body = #"{"archives":["https://api.chess.com/pub/player/bulk/games/2026/09","https://api.chess.com/pub/player/bulk/games/2026/10"]}"#
        } else if path.hasPrefix("/pub/player/bulk/games/2026/") {
            let game = #"{"pgn":"[White \"Bulk\"]\n[Black \"Bob\"]\n[Result \"1-0\"]\n\n1. e4 e5 1-0","rules":"chess"}"#
            body = "{\"games\":[" + Array(repeating: game, count: 600).joined(separator: ",") + "]}"
        } else if path == "/api/games/user/bulk" {
            let game = #"{"players":{"white":{"user":{"name":"Bulk"}},"black":{}},"variant":"standard","status":"mate","winner":"white","moves":"e4 e5"}"#
            body = Array(repeating: game, count: 1005).joined(separator: "\n")
            if URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "max" }) == true { status = 400 }
        } else if path == "/pub/player/alice/games/archives" {
            body = #"{"archives":["https://api.chess.com/pub/player/alice/games/2026/10"]}"#
        } else if path == "/pub/player/alice/games/2026/10" {
            body = #"{"games":[{"pgn":"[White \"Alice\"]\n[Black \"Bob\"]\n[Result \"1-0\"]\n\n1. e4 e5 1-0","rules":"chess"},{"rules":"chess"}]}"#
        } else if path == "/pub/player/fallback/games/archives" {
            body = #"{"archives":["https://api.chess.com/pub/player/fallback/games/2026/10"]}"#
        } else if path == "/pub/player/fallback/games/2026/10" {
            body = #"{"games":[{"rules":"chess"}]}"#
        } else if path == "/pub/player/fallback/games/2026/10/pgn" {
            body = "[Event \"Test\"]\n[Result \"1-0\"]\n\n1. e4 e5 1-0\n\n[Event \"Test 2\"]\n[Result \"0-1\"]\n\n1. d4 d5 0-1"
        } else if path == "/api/games/user/alice" {
            body = #"{"players":{"white":{"user":{"name":"Alice"}},"black":{"user":{"name":"Bob"}}},"variant":"standard","status":"mate","winner":"white","moves":"e4 e5"}"# + "\n" + #"{"players":{"white":{},"black":{}},"variant":"crazyhouse","status":"mate","moves":"e4 e5"}"#
        } else { status = 404; body = "{}" }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
