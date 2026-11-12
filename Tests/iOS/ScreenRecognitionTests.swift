#if canImport(UIKit)
import XCTest
import UIKit
@testable import NovaChess

final class ScreenRecognitionTests: XCTestCase {
    @MainActor func testBorderlessDigitalBoardInsideScreenshot() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 760), format: format).image { context in
            UIColor(white: 0.95, alpha: 1).setFill(); context.fill(CGRect(x: 0, y: 0, width: 400, height: 760))
            for index in 0..<64 {
                let square = CGRect(x: (index % 8)*50, y: 180+(index/8)*50, width: 50, height: 50)
                ((index/8+index%8).isMultiple(of: 2) ? UIColor(red: 0.94, green: 0.90, blue: 0.79, alpha: 1) : UIColor(red: 0.42, green: 0.56, blue: 0.35, alpha: 1)).setFill()
                context.fill(square)
                if let piece = Position.initial.squares[index] { UIImage(named: PieceStyle.illustrated.asset(for: piece))?.draw(in: square.insetBy(dx: 4, dy: 4)) }
            }
        }
        let result = try await Task.detached { try BoardRecognizer().recognize(image, screen: true) }.value
        XCTAssertEqual(result.position.squares, Position.initial.squares)
        let upsideDown = CameraView.normalized(UIImage(cgImage: try XCTUnwrap(image.cgImage), scale: 1, orientation: .down))
        let flipped = try await Task.detached { try BoardRecognizer().recognize(upsideDown, screen: true, blackAtBottom: true) }.value
        XCTAssertEqual(flipped.position.squares, Position.initial.squares)
    }
}
#endif
