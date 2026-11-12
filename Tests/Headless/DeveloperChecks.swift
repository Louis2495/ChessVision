import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif
@main struct DeveloperChecks {
    @MainActor static func main() async {
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let library = LibraryStore(directory: directory, puzzles: [], openings: [])
            let model = ComputerGameModel(); model.activate(library); model.developerOpponent = true; model.human = .black
            guard model.start() else { throw ChessError.invalid("Developer did not start") }
            try await wait { !model.busy }
            guard model.game?.targetRating == 2407, model.game?.moves == ["e2e4"] else { throw ChessError.invalid("Developer rating/first move incorrect") }
            model.play(try model.snapshot!.move(named: "e7e5")); try await wait { !model.busy }
            model.play(try model.snapshot!.move(named: "b8c6")); try await wait { !model.busy }
            guard model.game?.moves == ["e2e4","e7e5","g1f3","b8c6","f1c4"] else { throw ChessError.invalid("Developer did not play the Italian") }
            model.human = .white; guard model.start() else { throw ChessError.invalid("Black Developer setup failed") }
            try await wait { !model.busy }; model.play(try model.snapshot!.move(named: "e2e4")); try await wait { !model.busy }
            guard model.game?.moves.last == "e7e5" else { throw ChessError.invalid("Developer did not answer e4 with e5") }
            guard model.start() else { throw ChessError.invalid("Developer restart failed") }
            try await wait { !model.busy }; model.play(try model.snapshot!.move(named: "d2d4")); try await wait { !model.busy }
            guard model.game?.moves.last == "g8f6" else { throw ChessError.invalid("Developer did not answer d4 with Nf6") }
            model.pause(); EngineController.shared.stop(); try? FileManager.default.removeItem(at: directory)
            print("PASS: Developer 2407 uses Italian as White, e5 against e4 and Nf6 against d4."); fflush(stdout); _exit(0)
        } catch { print("FAIL: \(error)"); fflush(stdout); _exit(1) }
    }
    @MainActor static func wait(_ done: () -> Bool) async throws {
        for _ in 0..<600 { if done() { return }; try await Task.sleep(for: .milliseconds(50)) }
        throw ChessError.invalid("Developer check timed out")
    }
}
