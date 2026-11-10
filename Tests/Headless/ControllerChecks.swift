import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

@main struct ControllerChecks {
    enum Failure: Error { case failed(String) }
    static func require(_ condition: Bool, _ message: String) throws { if !condition { throw Failure.failed(message) } }
    @MainActor static func wait(_ predicate: () -> Bool) async throws {
        for _ in 0..<240 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw Failure.failed("Timed out waiting for the real Stockfish controller")
    }
    @MainActor static func main() async {
        do {
            let engine = EngineController.shared
            engine.analyze(.initial)
            try await wait { engine.ready && engine.lines.first?.depth ?? 0 >= 4 }
            try require(engine.running && engine.searchEngine == "Stockfish 19 NNUE", "Analysis did not use the official NNUE engine")
            try require(engine.analyzedFEN == Position.initial.fen, "Wrong initial FEN")
            let firstDepth = engine.lines.first!.depth
            try await wait { engine.lines.first?.depth ?? 0 > firstDepth }
            var next = Position.initial; try next.apply(uci: "e2e4")
            engine.analyze(next)
            try require(engine.lines.isEmpty, "Old evaluations were retained")
            try await wait { engine.analyzedFEN == next.fen && !engine.lines.isEmpty }
            let replies = Set(next.legalMoves().map(\.uci))
            try require(engine.lines.allSatisfy { $0.moves.first.map { replies.contains($0) } ?? false }, "Stale variation from an old board")
            var final = next; try final.apply(uci: "e7e5")
            engine.analyze(.initial); engine.analyze(next); engine.analyze(final)
            try await wait { engine.analyzedFEN == final.fen && !engine.lines.isEmpty }
            try require(engine.running, "Replacement analysis is not running")
            engine.stop(); try await wait { !engine.running }
            let mate = try Position(fen: "7k/6Q1/6K1/8/8/8/8/8 b - - 0 1")
            engine.analyze(mate)
            try require(engine.terminal == "Checkmate — White wins" && !engine.running, "Checkmate was not handled")
            let draw = try Position(fen: "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
            engine.analyze(draw)
            try require(engine.terminal == "Stalemate — draw" && !engine.running, "Stalemate was not handled")
            engine.analyze(.initial)
            try await wait { engine.running && !engine.lines.isEmpty }
            engine.stop(); try await wait { !engine.running }
            let response = Task { @MainActor in try await engine.computerMove(variant: "chess", history: [], rating: 1000, side: .white) }
            try await Task.sleep(for: .milliseconds(100))
            engine.stopAnalysis() // A departing analysis tab must not cancel another tab's game.
            let reply = try await response.value
            try require(Position.initial.legalMoves().contains { $0.uci == reply }, "Analysis cleanup canceled the game tab")
            let rated = try await engine.computerMove(variant: "chess", history: [], rating: 1320, side: .white)
            try require(engine.searchEngine == "Stockfish 19 NNUE" && Position.initial.legalMoves().contains { $0.uci == rated }, "Rated normal play did not use official Stockfish")
            UserDefaults.standard.set(3, forKey: "analysisCandidates")
            engine.analyze(.initial)
            try await wait { engine.lines.count == 3 && engine.lines.allSatisfy { $0.depth >= 6 } }
            try require(engine.searchEngine == "Stockfish 19 NNUE", "Full-strength analysis did not recover after rated play")
            engine.stop(); try await wait { !engine.running }
            UserDefaults.standard.set(1, forKey: "analysisCandidates")
            engine.analyze(.initial)
            try await wait { engine.lines.count == 1 && (engine.lines.first?.depth ?? 0) >= 6 }
            engine.stop(); try await wait { !engine.running }
            print("PASS: SF19 NNUE routing, full-strength reset after rated play and 1/3-line analysis modes.")
            print("PASS: actual Swift controller + Stockfish: continuous depth, board changes, latest request wins, cancellation, mate/stalemate, restart.")
            fflush(stdout)
            // Match the app's process-lifetime engine; bypass global iostream teardown in this CLI harness.
            _exit(0)
        } catch {
            print("FAIL: \(error)"); fflush(stdout); _exit(1)
        }
    }
}
