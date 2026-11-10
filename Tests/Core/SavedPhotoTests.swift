#if canImport(UIKit) && !canImport(ChessCore)
import XCTest
import UIKit
@testable import ChessVision

final class SavedPhotoTests: XCTestCase {
    @MainActor func testMultipleCapturesSurviveReopeningAndDeleteIndividually() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        let store = SavedPhotoStore(directory: directory)
        XCTAssertTrue(store.save(image)); XCTAssertTrue(store.save(image))
        let reopened = SavedPhotoStore(directory: directory)
        XCTAssertEqual(reopened.photos.count, 2)
        XCTAssertNotNil(reopened.image(try XCTUnwrap(reopened.photos.first)))
        reopened.delete(try XCTUnwrap(reopened.photos.first))
        XCTAssertEqual(SavedPhotoStore(directory: directory).photos.count, 1)
    }
}
#endif
