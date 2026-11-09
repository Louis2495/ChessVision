import XCTest
@testable import ChessVision

final class ExpansionIntegrationTests: XCTestCase {
    @MainActor func testLibraryPersistenceAndCorruptBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = LibraryStore(directory: directory, puzzles: [], openings: [])
        library.state.repertoire = [RepertoireLine(name: "Local test", side: .white, moves: ["e2e4"])]
        let restored = LibraryStore(directory: directory, puzzles: [], openings: [])
        XCTAssertEqual(restored.state.repertoire.first?.name, "Local test")
        try Data("invalid-json".utf8).write(to: directory.appendingPathComponent("library.json"))
        let recovered = LibraryStore(directory: directory, puzzles: [], openings: [])
        XCTAssertNotNil(recovered.notice); XCTAssertTrue(recovered.state.repertoire.isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix("library-backup-") })
    }
    @MainActor func testCrazyhouseComputerReplyThroughActualAppModel() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = LibraryStore(directory: directory, puzzles: [], openings: [])
        let model = ComputerGameModel(); model.activate(library)
        defer { model.pause() }
        model.mode = .crazyhouse; model.human = .white; model.ratingText = "1000"
        XCTAssertTrue(model.start())
        for _ in 0..<200 { if !model.busy { break }; try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertNil(model.error); XCTAssertNotNil(model.snapshot)
        model.enter("e4")
        for _ in 0..<200 { if !model.busy { break }; try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertNil(model.error); XCTAssertEqual(model.game?.moves.count, 2); XCTAssertEqual(model.snapshot?.board.turn, .white)
        XCTAssertEqual(library.state.computer?.moves.count, 2)
    }
}
