import XCTest
import CoreML
import Vision
import UIKit
import ImageIO
@testable import ChessVision

final class NativeIntegrationTests: XCTestCase {
    func testBundledModelContract() throws {
        for modelName in ["ChessPieces", "ChessPiecesDetail"] {
        let bundle = Bundle(for: AppBundleMarker.self)
        let url = try XCTUnwrap(bundle.url(forResource:modelName,withExtension:"mlmodelc"))
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
    }
    func testConvertedModelMatchesONNXPhotoFixtures() throws {
        struct Reference: Decodable { let image: String; let model: String; let probabilities: [String:Float] }
        let testBundle=Bundle(for:NativeIntegrationTests.self)
        let referenceURL=try XCTUnwrap(testBundle.url(forResource:"reference",withExtension:"json",subdirectory:"Fixtures"))
        let references=try JSONDecoder().decode([Reference].self,from:Data(contentsOf:referenceURL))
        let config=MLModelConfiguration();config.computeUnits = .cpuOnly
        for reference in references {
            let modelURL=try XCTUnwrap(Bundle(for:AppBundleMarker.self).url(forResource:reference.model,withExtension:"mlmodelc"))
            let model=try VNCoreMLModel(for:MLModel(contentsOf:modelURL,configuration:config))
            let imageURL=referenceURL.deletingLastPathComponent().appendingPathComponent(reference.image)
            let image=try XCTUnwrap(UIImage(contentsOfFile:imageURL.path)?.cgImage)
            let request=VNCoreMLRequest(model:model);request.imageCropAndScaleOption = .scaleFill
            try VNImageRequestHandler(cgImage:image).perform([request])
            let predictions=try XCTUnwrap(request.results as? [VNClassificationObservation])
            for prediction in predictions {XCTAssertEqual(prediction.confidence,try XCTUnwrap(reference.probabilities[prediction.identifier]),accuracy:0.025,"Model parity: \(reference.image), \(prediction.identifier)")}
        }
    }
    @MainActor func testEmbeddedStockfishContinuousSearchAndPositionChanges() async throws {
        let engine = EngineController.shared
        engine.analyze(.initial)
        defer { engine.stop() }
        for _ in 0..<150 {
            if engine.lines.first?.depth ?? 0 >= 4 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(engine.ready)
        XCTAssertTrue(engine.running)
        XCTAssertFalse(engine.lines.isEmpty)
        XCTAssertEqual(engine.analyzedFEN, Position.initial.fen)
        var next = Position.initial; try next.apply(uci: "e2e4")
        engine.analyze(next)
        XCTAssertTrue(engine.lines.isEmpty, "Old-position evaluations must disappear immediately")
        for _ in 0..<150 {
            if engine.analyzedFEN == next.fen && !engine.lines.isEmpty { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(engine.analyzedFEN, next.fen)
        let legal = Set(next.legalMoves().map(\.uci))
        XCTAssertTrue(engine.lines.allSatisfy { $0.moves.first.map { legal.contains($0) } ?? false })
        // Rapid taps must keep the newest position, rather than restarting an older queued search.
        var latest = next; try latest.apply(uci: "e7e5")
        engine.analyze(.initial); engine.analyze(next); engine.analyze(latest)
        for _ in 0..<150 {
            if engine.analyzedFEN == latest.fen && !engine.lines.isEmpty { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(engine.analyzedFEN, latest.fen)
        engine.stop()
        for _ in 0..<50 { if !engine.running { break }; try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertFalse(engine.running)
        let mate = try Position(fen: "7k/6Q1/6K1/8/8/8/8/8 b - - 0 1")
        engine.analyze(mate)
        XCTAssertEqual(engine.terminal, "Checkmate — White wins")
        XCTAssertFalse(engine.running)
    }
    @MainActor func testFilledPieceAssetsAndBoardImageExport() throws {
        for side in ["w", "b"] {
            for kind in ["K", "Q", "R", "B", "N", "P"] { XCTAssertNotNil(UIImage(named: side + kind)) }
        }
        let image = try XCTUnwrap(BoardImageExporter.image(for: .initial))
        XCTAssertEqual(image.cgImage?.width, 1120)
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 10000)
    }
}

extension NativeIntegrationTests {
    @MainActor func testAnimatedGameGIFHasEveryFrameAndLoops() async throws {
        let start = Position.initial
        let after = try start.playing(start.move(forSAN: "e4"))
        let url = try await BoardImageExporter.gif(for: [start, after])
        defer { try? FileManager.default.removeItem(at: url) }
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetCount(source), 2)
        let first = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let second = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 1, nil))
        XCTAssertNotEqual(UIImage(cgImage: first).pngData(), UIImage(cgImage: second).pngData())
        let properties = try XCTUnwrap(CGImageSourceCopyProperties(source, nil) as? [String: Any])
        let gif = try XCTUnwrap(properties[kCGImagePropertyGIFDictionary as String] as? [String: Any])
        XCTAssertEqual(gif[kCGImagePropertyGIFLoopCount as String] as? Int, 0)
        let frame = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        let timing = try XCTUnwrap(frame[kCGImagePropertyGIFDictionary as String] as? [String: Any])
        XCTAssertGreaterThan(timing[kCGImagePropertyGIFDelayTime as String] as? Double ?? 0, 0)
    }
}
