import Foundation

@main struct RatingChecks {
    enum Failure: Error { case failed(String) }
    static func require(_ condition: Bool, _ message: String) throws { if !condition { throw Failure.failed(message) } }
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("nova-rating-check-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var saved = LibraryState(), rating = PlayerRating()
        rating.record(score: 1, opponent: 1200)
        saved.playProgress.ratings[GameMode.normal.rawValue] = rating
        var game = SavedComputerGame(mode: .normal, human: .white, targetRating: 1200); game.rated = true
        saved.history = [CompletedGame(game: game, result: "white")]
        try JSONEncoder().encode(saved).write(to: directory.appendingPathComponent("library.json"))
        let store = LibraryStore(directory: directory, puzzles: [], openings: [])
        try require(store.state.playProgress.rating(for: .normal).value == 1600, "Library did not migrate Standard rating")
        try require(store.state.history.first?.ratingChange == 600, "Migration did not update archived change")
        let restored = LibraryStore(directory: directory, puzzles: [], openings: [])
        try require(restored.state.playProgress.rating(for: .normal).value == 1600, "Migration was applied twice or not persisted")
        let model = ComputerGameModel(); model.activate(store); defer { model.pause() }
        model.rated = true
        model.chooseOpponent(.developer, matchedRating: 1550, customRating: "1100")
        try require(model.developerOpponent && !model.adaptive && model.ratingText == "2407", "Developer choice is not exclusive")
        model.chooseOpponent(.adaptive, matchedRating: 1550, customRating: "1100")
        try require(!model.developerOpponent && model.adaptive && !model.rated && model.ratingText == "1550", "Adaptive choice is not exclusive/unrated")
        model.chooseOpponent(.matched, matchedRating: 1550, customRating: "1100")
        try require(!model.developerOpponent && !model.adaptive && model.ratingText == "1550", "Match my level retained another mode")
        model.chooseOpponent(.custom, matchedRating: 1550, customRating: "1100")
        try require(!model.developerOpponent && !model.adaptive && model.ratingText == "1100", "Custom retained another mode")
        model.rated = true
        for (mode, targets) in [(GameMode.normal, [100, 4000, 10000]), (.threeCheck, [100, 3190, 4000])] {
            model.mode = mode
            for target in targets {
                model.ratingText = String(target)
                try require(!model.start(), "Unsupported rated game started")
                try require(model.error?.contains("For rated games") == true, "Missing supported-range explanation")
            }
        }
        print("PASS: exclusive Developer/adaptive/matched/custom opponent choices.")
        print("PASS: LibraryStore persists rating migration once; New game rejects unsupported rated targets.")
    }
}
