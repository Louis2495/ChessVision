import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import ChessVision
#endif
final class BoardGridTests: XCTestCase {
    func testFindsPlayingAreaInsideBorder() throws {
        let size=256, margin=16, square=28
        var gray=Array(repeating:UInt8(120),count:size*size)
        for y in margin..<(size-margin) {for x in margin..<(size-margin) {gray[y*size+x] = ((x-margin)/square+(y-margin)/square).isMultiple(of:2) ? 220 : 40}}
        let bounds=try XCTUnwrap(BoardGrid.locate(gray:gray,width:size,height:size))
        XCTAssertEqual(bounds.left,margin,accuracy:4);XCTAssertEqual(bounds.top,margin,accuracy:4)
        XCTAssertEqual(bounds.right,size-margin,accuracy:4);XCTAssertEqual(bounds.bottom,size-margin,accuracy:4)
    }
    func testRejectsBlankRectangle() {XCTAssertNil(BoardGrid.locate(gray:Array(repeating:120,count:256*256),width:256,height:256))}
    func testRejectsMalformedImage() {XCTAssertNil(BoardGrid.locate(gray:[0],width:256,height:256))}
}
