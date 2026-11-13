import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

@main struct DeveloperChecks {
    enum Failure: Error { case failed(String) }
    static func require(_ condition: Bool, _ message: String) throws { if !condition { throw Failure.failed(message) } }
    @MainActor static func wait(_ model: ComputerGameModel) async throws {
        for _ in 0..<400 {
            if !model.busy { try require(model.error == nil, model.error ?? ""); return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw Failure.failed("Developer response timed out")
    }
    @MainActor static func main() async {
        do { try await run(); EngineController.shared.stop(); fflush(stdout); _exit(0) }
        catch { print("FAIL: \(error)"); fflush(stdout); _exit(1) }
    }
    @MainActor static func run() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("nova-developer-check-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = LibraryStore(directory: directory, puzzles: [], openings: [])
        let model = ComputerGameModel(); model.activate(library); defer { model.pause() }
        model.developerOpponent = true; model.mode = .normal
        @MainActor func setup(_ human: Side) async throws {
            model.human = human
            try require(model.start(), "Developer game did not start")
            try await wait(model)
            try require(model.game?.targetRating == 2407 && model.game?.developerBot == true, "Developer identity/rating changed")
            if human == .black { try require(model.game?.moves == ["e2e4"], "Developer did not start with e4") }
        }
        @MainActor func play(_ san: String, reply: String) async throws {
            guard let move = try model.snapshot?.move(named: san) else { throw Failure.failed("Missing board") }
            model.play(move); try await wait(model)
            try require(model.game?.moves.last == reply, "After \(san), expected \(reply), got \(model.game?.moves.last ?? "none")")
        }
        try await setup(.white)
        for (san, expected) in [("e4","e7e5"),("Nf3","b8c6"),("Bb5","a7a6"),("Ba4","g8f6"),("O-O","f6e4")] { try await play(san, reply: expected) }
        try await setup(.white)
        for (san, expected) in [("d4","g8f6"),("c4","e7e6"),("Nc3","f8b4")] { try await play(san, reply: expected) }
        try await setup(.white)
        for (san, expected) in [("d4","g8f6"),("c4","e7e6"),("Nf3","d7d5"),("g3","d5c4")] { try await play(san, reply: expected) }
        try await setup(.black)
        try await play("e5", reply: "g1f3"); try await play("Nc6", reply: "f1c4")
        try await setup(.black)
        try await play("c5", reply: "b1c3"); try await play("Nc6", reply: "f2f4")
        try await setup(.black)
        try await play("e6", reply: "d2d4"); try await play("d5", reply: "b1d2")
        try await setup(.black)
        for (san, expected) in [("Nf6","e4e5"),("Nd5","d2d4"),("d6","e5d6")] { try await play(san, reply: expected) }
        print("PASS: live Developer games follow Open Ruy Lopez, Nimzo, accepted Catalan, Grand Prix, Tarrasch and Alekhine Exchange at target 2407.")
    }
}
