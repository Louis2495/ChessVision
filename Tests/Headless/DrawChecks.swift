import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif
@main struct DrawChecks {
    @MainActor static func main() async {
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: folder) }
            let store = LibraryStore(directory: folder, puzzles: [], openings: [])
            let model = ComputerGameModel(); model.activate(store)
            guard model.start() else { throw ChessError.invalid("Could not start Standard") }
            try await wait { !model.busy }
            model.offerDraw()
            guard model.error?.contains("declines") == true, model.snapshot?.finished == false else { throw ChessError.invalid("Early draw offer ended the game") }
            model.pause()
            let berlin = "e2e4 e7e5 g1f3 b8c6 f1b5 g8f6 e1g1 f6e4 d2d4 e4d6 b5c6 d7c6 d4e5 d6f5 d1d8 e8d8 b1c3 f8e7 h2h3 h7h6".split(separator: " ").map(String.init)
            var game = SavedComputerGame(mode: .normal, human: .white, targetRating: 1000, moves: berlin)
            game.id = UUID(); store.state.computer = game
            let equal = ComputerGameModel(); equal.activate(store)
            try await wait { !equal.busy }
            equal.offerDraw(); try await wait { !equal.busy }
            guard equal.game?.agreedDraw == true, equal.snapshot?.status == "draw", store.state.history.first?.result == "draw" else { throw ChessError.invalid("Equal-position draw was not accepted and archived: \(equal.error ?? "no error")") }
            equal.pause()
            let reloaded = LibraryStore(directory: folder, puzzles: [], openings: [])
            let restored = ComputerGameModel(); restored.activate(reloaded)
            try await wait { !restored.busy }
            guard restored.snapshot?.status == "draw", reloaded.state.history.count == 1 else { throw ChessError.invalid("Agreed draw was not restored safely") }
            restored.pause(); EngineController.shared.stop(); try await wait { !EngineController.shared.running }
            print("PASS: Standard draw offers decline early, accept balanced positions, archive once and survive reload.")
            fflush(stdout); _exit(0)
        } catch { EngineController.shared.stop(); try? await wait { !EngineController.shared.running }; fputs("FAIL: \(error)\n", stderr); fflush(stderr); _exit(1) }
    }
    @MainActor static func wait(_ done: () -> Bool) async throws {
        for _ in 0..<600 { if done() { return }; try await Task.sleep(for: .milliseconds(50)) }
        throw ChessError.invalid("Draw check timed out")
    }
}
