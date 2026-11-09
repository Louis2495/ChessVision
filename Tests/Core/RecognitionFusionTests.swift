import XCTest
#if canImport(ChessCore)
@testable import ChessCore
#else
@testable import ChessVision
#endif
final class RecognitionFusionTests: XCTestCase {
    func testFusionMatchesPhotoBenchmarkForAllSquares() throws {
        struct Reference: Decodable {
            var primary: [String: Float]
            var verifier: [String: Float]?
            var needsVerifier: Bool
            var label: String
            var confidence: Float
            var uncertain: Bool
        }
        #if canImport(ChessCore)
        let url = try XCTUnwrap(Bundle.module.url(forResource: "recognition", withExtension: "json"))
        #else
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "recognition", withExtension: "json", subdirectory: "Reference"))
        #endif
        let references = try JSONDecoder().decode([Reference].self, from: Data(contentsOf: url))
        XCTAssertEqual(references.count, 320)
        for (index, reference) in references.enumerated() {
            XCTAssertEqual(RecognitionFusion.needsVerification(reference.primary), reference.needsVerifier, "Square \(index)")
            let result = RecognitionFusion.classify(primary: reference.primary, verifier: reference.verifier)
            XCTAssertEqual(result.label, reference.label, "Square \(index)")
            XCTAssertEqual(result.confidence, reference.confidence, accuracy: 0.00001)
            XCTAssertEqual(result.uncertain, reference.uncertain, "Square \(index)")
        }
    }
    func testVerifierCanRecoverKingFromBishopPrediction() {
        let result = RecognitionFusion.classify(primary: ["B": 0.55, "K": 0.4, "empty": 0.05], verifier: ["K": 0.8, "B": 0.15, "empty": 0.05])
        XCTAssertEqual(result.label, "K")
        XCTAssertTrue(result.uncertain)
    }
    func testApparentlyEmptySquaresAreVerified() {
        let primary: [String: Float] = ["empty": 0.9, "k": 0.1]
        XCTAssertTrue(RecognitionFusion.needsVerification(primary))
        let result = RecognitionFusion.classify(primary: primary, verifier: ["k": 0.95, "empty": 0.05])
        XCTAssertEqual(result.label, "k")
        XCTAssertTrue(result.uncertain)
    }
    func testDoesNotInventMissingKings() {
        let result = RecognitionFusion.classify(primary: ["empty": 0.99, "K": 0.01], verifier: ["empty": 0.98, "K": 0.02])
        XCTAssertEqual(result.label, "empty")
        XCTAssertFalse(result.uncertain)
    }
    func testKingsAndBishopsGetSecondOpinionEvenWhenConfident() {
        XCTAssertTrue(RecognitionFusion.needsVerification(["B": 0.99, "K": 0.01]))
        XCTAssertTrue(RecognitionFusion.needsVerification(["k": 0.99, "b": 0.01]))
    }
    func testConfidentPieceUsesFastModel() {
        let primary: [String: Float] = ["P": 0.97, "B": 0.03]
        XCTAssertFalse(RecognitionFusion.needsVerification(primary))
        XCTAssertEqual(RecognitionFusion.classify(primary: primary).label, "P")
    }
    func testDisagreementAlwaysRemainsVisible() {
        let result = RecognitionFusion.classify(primary: ["B": 0.999, "K": 0.001], verifier: ["K": 0.99, "B": 0.01])
        XCTAssertTrue(result.uncertain)
    }
}
