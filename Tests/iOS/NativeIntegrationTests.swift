import XCTest
import CoreML
import Vision
import UIKit
@testable import ChessVision

final class NativeIntegrationTests: XCTestCase {
    func testBundledModelContract() throws {
        let bundle = Bundle(for: AppBundleMarker.self)
        let url = try XCTUnwrap(bundle.url(forResource:"ChessPieces",withExtension:"mlmodelc"))
        let model = try MLModel(contentsOf:url)
        XCTAssertEqual(Set(model.modelDescription.classLabels as? [String] ?? []),Set(["B","K","N","P","Q","R","empty","b","k","n","p","q","r"]))
        let constraint = try XCTUnwrap(model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint)
        XCTAssertEqual(constraint.pixelsWide,224); XCTAssertEqual(constraint.pixelsHigh,224)
        // Core ML prediction cannot execute on Linux. Exercise the real bundled artifact here.
        let image = UIGraphicsImageRenderer(size:CGSize(width:224,height:224)).image { context in UIColor.gray.setFill();context.fill(CGRect(x:0,y:0,width:224,height:224)) }
        let request = VNCoreMLRequest(model:try VNCoreMLModel(for:model))
        request.imageCropAndScaleOption = .scaleFill
        try VNImageRequestHandler(cgImage:try XCTUnwrap(image.cgImage)).perform([request])
        let results = try XCTUnwrap(request.results as? [VNClassificationObservation])
        XCTAssertEqual(results.count,13)
        XCTAssertEqual(results.reduce(Float(0)){$0+$1.confidence},1,accuracy:0.01)
    }
    func testConvertedModelMatchesONNXPhotoFixtures() throws {
        struct Reference: Decodable { let image: String; let probabilities: [String:Float] }
        let testBundle=Bundle(for:NativeIntegrationTests.self)
        let referenceURL=try XCTUnwrap(testBundle.url(forResource:"reference",withExtension:"json",subdirectory:"Fixtures"))
        let references=try JSONDecoder().decode([Reference].self,from:Data(contentsOf:referenceURL))
        let config=MLModelConfiguration();config.computeUnits = .cpuOnly
        let modelURL=try XCTUnwrap(Bundle(for:AppBundleMarker.self).url(forResource:"ChessPieces",withExtension:"mlmodelc"))
        let model=try VNCoreMLModel(for:MLModel(contentsOf:modelURL,configuration:config))
        for reference in references {
            let imageURL=referenceURL.deletingLastPathComponent().appendingPathComponent(reference.image)
            let image=try XCTUnwrap(UIImage(contentsOfFile:imageURL.path)?.cgImage)
            let request=VNCoreMLRequest(model:model);request.imageCropAndScaleOption = .scaleFill
            try VNImageRequestHandler(cgImage:image).perform([request])
            let predictions=try XCTUnwrap(request.results as? [VNClassificationObservation])
            for prediction in predictions {XCTAssertEqual(prediction.confidence,try XCTUnwrap(reference.probabilities[prediction.identifier]),accuracy:0.025,"Model parity: \(reference.image), \(prediction.identifier)")}
        }
    }
    @MainActor func testEmbeddedStockfishSearchAndCancellation() async throws {
        let engine=EngineController.shared
        engine.analyze(.initial,seconds:3)
        for _ in 0..<150 {
            if !engine.running && engine.bestMove != nil { break }
            try await Task.sleep(for:.milliseconds(100))
        }
        XCTAssertTrue(engine.ready)
        XCTAssertNotNil(engine.bestMove)
        XCTAssertFalse(engine.lines.isEmpty)
        XCTAssertFalse(engine.running)
        engine.analyze(.initial,seconds:30)
        try await Task.sleep(for:.milliseconds(300))
        engine.stop()
        for _ in 0..<50 { if !engine.running {break};try await Task.sleep(for:.milliseconds(100)) }
        XCTAssertFalse(engine.running)
    }
}
