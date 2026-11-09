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
        for _ in 0..<400 { if predicate() { return }; try await Task.sleep(for: .milliseconds(50)) }
        throw Failure.failed("Feature workflow timed out")
    }
    @MainActor static func publicAPIChecks() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [PublicAPIStub.self]
        let service = PublicGameService(session: URLSession(configuration: config))
        let chesscom = try await service.load(site: .chesscom, username: "Alice", limit: 200) { _ in }
        try require(chesscom.games.count == 1 && chesscom.games[0].moves == ["e2e4", "e7e5"], "Chess.com export import failed")
        let fallback = try await service.load(site: .chesscom, username: "Fallback", limit: 200) { _ in }
        try require(fallback.games.count == 2, "Missing JSON game fields did not fall back to PGN")
        let lichess = try await service.load(site: .lichess, username: "Alice", limit: 200) { _ in }
        try require(lichess.games.count == 1 && lichess.fetched == 2 && lichess.skipped == 1, "Lichess NDJSON import/variant filter failed")
        do { _ = try await service.load(site: .chesscom, username: "Missing", limit: 200) { _ in }; throw Failure.failed("404 was accepted") }
        catch let error as ChessError { try require(error.localizedDescription.contains("not found"), "Missing-profile error was lost") }
        print("PASS: actual public API client with isolated HTTP fixtures (not live service access).")
    }
    @MainActor static func main() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ChessVision-features-\(UUID().uuidString)")
        do {
            let root = URL(fileURLWithPath: CommandLine.arguments[1])
            let puzzles = try JSONDecoder().decode([ChessPuzzle].self, from: Data(contentsOf: root.appendingPathComponent("ChessVision/Core/Resources/Puzzles.json")))
            let openings = try JSONDecoder().decode([OpeningLine].self, from: Data(contentsOf: root.appendingPathComponent("ChessVision/Core/Resources/Openings.json")))
            let store = LibraryStore(directory: directory, puzzles: puzzles, openings: openings)
            store.state.repertoire = [RepertoireLine(name: "Test line", side: .white, moves: ["e2e4", "e7e5"])]
            store.state.puzzle.record(puzzles[0], correct: true)
            let restored = LibraryStore(directory: directory, puzzles: puzzles, openings: openings)
            try require(restored.state.repertoire.first?.name == "Test line" && restored.state.puzzle.attempts == 1, "Local library did not persist")
            try await publicAPIChecks()
            let model = ComputerGameModel(); model.activate(store)
            for mode in GameMode.allCases {
                model.mode = mode; model.human = .white; model.ratingText = "1000"
                try require(model.start(), "New game did not start")
                try await wait { !model.busy && model.snapshot != nil }
                try require(model.error == nil && model.snapshot?.board.turn == .white, "Variant setup failed: \(mode)")
                let move = (mode == .horde || mode == .duck) ? model.snapshot!.moves[0] : try model.snapshot!.move(named: "e4")
                model.play(move)
                try await wait { !model.busy }
                try require(model.error == nil, "Computer reply failed: \(model.error ?? "")")
                try require(model.game?.moves.count == 2, "Computer did not reply in \(mode)")
                try require(model.snapshot?.board.turn == .white, "Turn did not return to the user")
                model.undo(); try await wait { !model.busy }
                try require(model.game?.moves.isEmpty == true, "Takeback did not restore the start")
                print("Checked model: \(mode.title)"); fflush(stdout)
            }
            model.mode = .pawnWars; model.pawnWarsKings = false; model.human = .white
            try require(model.start(), "Pawn race setup failed"); try await wait { !model.busy }
            try require(model.error == nil && model.snapshot?.board.squares.compactMap { $0 }.allSatisfy { $0.kind == "p" } == true, "No-kings pawn race still has kings")
            model.play(model.snapshot!.moves[0]); try await wait { !model.busy }
            try require(model.error == nil && model.game?.moves.count == 2, "Pawn race computer failed")
            model.pawnWarsKings = true
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
            model.pause()
            EngineController.shared.analyze(.initial)
            try await wait { !EngineController.shared.lines.isEmpty }
            try require(EngineController.shared.selectedVariant == "chess", "Analysis did not restore standard chess")
            EngineController.shared.stop(); try await wait { !EngineController.shared.running }
            try FileManager.default.removeItem(at: directory)
            print("PASS: real feature models: persistent library, twelve game styles with computer replies, takebacks, opening requests, analysis handover.")
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
        if path == "/pub/player/alice/games/archives" {
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
