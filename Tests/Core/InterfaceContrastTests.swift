import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import NovaChess
#endif
final class InterfaceContrastTests: XCTestCase {
    func testEveryThemeHasAtLeastAAContrastForPrimaryButtonText() {
        for theme in AppTheme.allCases {
            let background = InterfaceContrast.luminance(theme.hex)
            let foreground = InterfaceContrast.luminance(InterfaceContrast.foreground(on: theme.hex))
            let ratio = (max(background, foreground) + 0.05) / (min(background, foreground) + 0.05)
            XCTAssertGreaterThanOrEqual(ratio, 4.5, theme.rawValue)
        }
    }
    func testLightAndDarkBackgroundsUseOppositeTextColors() {
        XCTAssertEqual(InterfaceContrast.foreground(on: 0xFFFFFF), 0x000000)
        XCTAssertEqual(InterfaceContrast.foreground(on: 0x000000), 0xFFFFFF)
        XCTAssertEqual(InterfaceContrast.foreground(on: 0xB4E8C4), 0x000000)
    }
}
