import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class SocialAndScreenTests: XCTestCase {
    func testUsernamesAreCanonicalAndRejectAmbiguousOrReservedInput() throws {
        XCTAssertEqual(try Usernames.canonical("  Knight_42 "), "knight_42")
        for value in ["ad", "admin", "name with spaces", "👑player", String(repeating: "a", count: 21)] { XCTAssertThrowsError(try Usernames.canonical(value)) }
        XCTAssertEqual(Usernames.prefix(" Kn "), "kn")
        XCTAssertNil(Usernames.prefix("k"))
    }
    func testOldContainerBackupIsCopiedWithoutDeletingOriginal() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = base.appendingPathComponent("ChessVision/BoardPhotos")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data("old library".utf8).write(to: legacy.deletingLastPathComponent().appendingPathComponent("library.json"))
        try Data("image".utf8).write(to: legacy.appendingPathComponent("sample.jpg"))
        let migrated = ApplicationStorage.directory(in: base)
        XCTAssertEqual(migrated.lastPathComponent, "NovaChess")
        XCTAssertEqual(try Data(contentsOf: migrated.appendingPathComponent("library.json")), Data("old library".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("sample.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: migrated.appendingPathComponent("BoardPhotos/sample.jpg").path))
        XCTAssertEqual(ApplicationStorage.directory(in: base), migrated)
    }
    func testDigitalMatcherFindsKnownPieceAndEmptySquare() throws {
        let size = 16, count = size*size
        var rgba = [UInt8](repeating: 0, count: count*4)
        var gray = [UInt8](repeating: 180, count: count)
        for y in 3..<13 { for x in 5..<11 {
            let i = y*size+x; gray[i] = 20
            rgba[i*4] = 20; rgba[i*4+1] = 20; rgba[i*4+2] = 20; rgba[i*4+3] = 255
        } }
        let templates = [DigitalPieceTemplate(label: "p", rgba: rgba), DigitalPieceTemplate(label: "N", rgba: Array(repeating: 0, count: count*4))]
        XCTAssertEqual(DigitalPieceMatcher.recognize(gray: gray, size: size, templates: templates)?.label, "p")
        XCTAssertEqual(DigitalPieceMatcher.recognize(gray: Array(repeating: 180, count: count), size: size, templates: templates)?.label, "empty")
        var labeledEmpty = [UInt8](repeating: 180, count: count)
        for index in [size+2, 2*size+2, 3*size+2] { labeledEmpty[index] = 0 }
        XCTAssertEqual(DigitalPieceMatcher.recognize(gray: labeledEmpty, size: size, templates: templates)?.label, "empty")
        XCTAssertNil(DigitalPieceMatcher.recognize(gray: [], size: size, templates: templates))
    }
    func testPublicBoardDataIsReadOnlyAndRejectsMalformedFen() throws {
        var game = PublicGame(id: "record", gameID: "game", publisher: "player", white: "player", black: "Bot", mode: "Normal", fen: Position.initial.fen, notation: [], updated: Date(), result: nil, consentUsers: [])
        XCTAssertEqual(try game.board().board, .initial)
        game.fen = "invalid"
        XCTAssertThrowsError(try game.board())
    }
}
