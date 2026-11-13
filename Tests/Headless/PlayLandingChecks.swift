import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif
@main struct PlayLandingChecks {
    enum Failure: Error { case failed(String) }
    static func require(_ condition: Bool, _ message: String) throws { if !condition { throw Failure.failed(message) } }
    @MainActor static func wait(_ model: ComputerGameModel) async throws {
        for _ in 0..<600 {
            if !model.busy { try require(model.error == nil, model.error ?? ""); return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw Failure.failed("Setup validation timed out")
    }
    @MainActor static func run() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("nova-play-landing-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = LibraryStore(directory: directory, puzzles: [], openings: [])
        let fresh = ComputerGameModel(); fresh.prepare(library); defer { fresh.pause() }
        try require(fresh.game == nil && !fresh.busy, "Fresh landing created a game")
        try require(fresh.start(), "Start from landing failed")
        try require(library.state.computer?.id == fresh.game?.id && fresh.game?.moves.isEmpty == true, "Landing did not save the new game")
        fresh.activate(library); try await wait(fresh)
        try require(fresh.snapshot?.board == .initial, "Start did not show the initial position")
        fresh.pause()
        var saved = SavedComputerGame(mode: .normal, human: .black, targetRating: 2407)
        saved.developerBot = true; library.state.computer = saved
        let resumed = ComputerGameModel(); resumed.prepare(library); defer { resumed.pause() }
        try await wait(resumed)
        try require(resumed.game?.moves.isEmpty == true && resumed.snapshot?.board == .initial, "Computer moved behind the landing page")
        resumed.activate(library); try await wait(resumed)
        try require(resumed.game?.id == saved.id && resumed.game?.moves == ["e2e4"], "Resume lost identity or the computer reply")
        resumed.pause()
        var rated = SavedComputerGame(mode: .normal, human: .white, targetRating: 1000, moves: ["e2e4","e7e5"])
        rated.rated = true; rated.source = "bot"; library.state.computer = rated
        let replacing = ComputerGameModel(); replacing.prepare(library); defer { replacing.pause() }
        try require(!replacing.start(), "An unloaded rated game was silently replaced")
        try require(library.state.computer?.id == rated.id, "Saved rated game was overwritten")
        // The passive loader clears the temporary start error once resumed validation completes.
        try await wait(replacing)
        try require(replacing.start(), "Validated rated game could not be replaced")
        try require(library.state.history.filter { $0.id == rated.id }.count == 1, "Old rated game was not settled exactly once")
        try require(library.state.history.first(where: { $0.id == rated.id })?.result == "black", "Old rated game was not resigned correctly")
        replacing.activate(library); try await wait(replacing)
        try require(replacing.game?.moves.isEmpty == true && replacing.snapshot?.board == .initial, "A stale saved position replaced the new board")
        print("PASS: fresh Play setup, no hidden computer moves, saved-game resume and rated replacement protection.")
    }
    @MainActor static func main() async {
        do { try await run(); EngineController.shared.stop(); fflush(stdout); _exit(0) }
        catch { print("FAIL: \(error)"); fflush(stdout); _exit(1) }
    }
}
