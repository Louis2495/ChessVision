import XCTest
@testable import ChessCore
final class CameraRecordingTests: XCTestCase {
    func testStableLegalMoveAndUndo() throws {
        var tracker = CameraGameTracker()
        let move = try XCTUnwrap(Position.initial.legalMoves().first { $0.uci == "e2e4" })
        let next = try Position.initial.playing(move)
        XCTAssertFalse(try tracker.observe(next.squares, uncertain: []))
        XCTAssertTrue(try tracker.observe(next.squares, uncertain: []))
        XCTAssertEqual(tracker.notation, ["e4"])
        XCTAssertFalse(try tracker.observe(next.squares, uncertain: []))
        tracker.undo(); XCTAssertEqual(tracker.board, .initial); XCTAssertTrue(tracker.notation.isEmpty)
    }
    func testOcclusionResetsStabilityAndMissedMovesAreRejected() throws {
        var tracker = CameraGameTracker()
        let next = try Position.initial.playing(XCTUnwrap(Position.initial.legalMoves().first { $0.uci == "e2e4" }))
        XCTAssertFalse(try tracker.observe(next.squares, uncertain: []))
        XCTAssertFalse(try tracker.observe(next.squares, uncertain: [12]))
        XCTAssertFalse(try tracker.observe(next.squares, uncertain: []))
        let later = try next.playing(XCTUnwrap(next.legalMoves().first { $0.uci == "e7e5" }))
        XCTAssertFalse(try tracker.observe(later.squares, uncertain: []))
        XCTAssertFalse(try tracker.observe(later.squares, uncertain: []))
        XCTAssertTrue(tracker.notation.isEmpty)
    }
    func testManualRecoveryOnlyAcceptsLegalMoves() throws {
        var tracker = CameraGameTracker()
        try tracker.recordManual("e4")
        XCTAssertThrowsError(try tracker.recordManual("e5e4"))
        try tracker.recordManual("e5")
        XCTAssertEqual(tracker.notation, ["e4", "e5"])
        XCTAssertEqual(tracker.positions.count, 3)
    }
    func testFolderPersistenceAndOldLibrary() throws {
        var state = LibraryState()
        let folder = GameFolder(name: "Club games")
        state.folders = [folder]
        var game = SavedBoardGame(title: "Round one", positions: [Position.initial.fen], notation: [])
        game.folderID = folder.id; state.savedGames = [game]
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(LibraryState.self, from: data)
        XCTAssertEqual(restored.savedGames.first?.folderID, folder.id)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "folders"); json.removeValue(forKey: "savedGames")
        let old = try JSONDecoder().decode(LibraryState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.folders.isEmpty); XCTAssertTrue(old.savedGames.isEmpty)
    }
}
