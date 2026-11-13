import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif
@main struct EndgameChecks {
    enum Failure: Error { case failed(String) }
    static func require(_ condition: Bool, _ message: String) throws { if !condition { throw Failure.failed(message) } }
    @MainActor static func wait(_ model: EndgameTrainerModel) async throws {
        for _ in 0..<600 {
            if !model.busy { try require(model.error == nil, model.error ?? ""); return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw Failure.failed("Endgame engine response timed out")
    }
    @MainActor static func run() async throws {
        let model = EndgameTrainerModel(); defer { model.pause() }
        guard let general = EndgameExercise.all.first(where: { $0.id == "queen-king" }),
              let promotion = EndgameExercise.all.first(where: { $0.id == "promotion" }),
              let mate = EndgameExercise.all.first(where: { $0.id == "queen-finish" }) else { throw Failure.failed("Missing endgames") }
        model.start(general)
        guard let board = model.session?.board, let move = board.legalMoves().first(where: { $0.uci == "e3f3" }) else { throw Failure.failed("Missing legal move") }
        model.play(move); try await wait(model)
        try require(model.session?.moves.count == 2 && model.session?.board.turn == .white, "Engine did not answer the arbitrary-FEN position")
        model.showHint(); try await wait(model)
        try require(model.hint != nil && model.session?.moves.count == 2, "Hint changed the board or did not return SAN")
        model.start(general); model.play(move); model.pause()
        try require(model.session?.moves.count == 1 && model.session?.board.turn == .black, "Pause corrupted the pending endgame")
        model.resume(); try await wait(model)
        try require(model.session?.moves.count == 2, "Resume duplicated or lost an engine reply")
        model.start(general); model.play(move); model.start(promotion)
        try await Task.sleep(for: .milliseconds(150))
        try require(model.session?.exercise.id == "promotion" && model.session?.moves.isEmpty == true, "An old reply affected a restarted exercise")
        model.start(mate)
        guard let winning = model.session?.board.legalMoves().first(where: { $0.uci == "f7g7" }) else { throw Failure.failed("Missing mating move") }
        model.play(winning)
        try require(model.session?.outcome == .success && !model.busy, "Completion started an unnecessary engine search")
        print("PASS: endgame Stockfish FEN replies, SAN hints, pause/resume, restart cancellation and mate completion.")
    }
    @MainActor static func main() async {
        do { try await run(); EngineController.shared.stop(); fflush(stdout); _exit(0) }
        catch { print("FAIL: \(error)"); fflush(stdout); _exit(1) }
    }
}
