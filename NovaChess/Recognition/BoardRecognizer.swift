import UIKit
import Vision
import CoreML
import CoreImage

struct RecognitionResult {
    var position: Position
    var uncertain: Set<Int>
    var image: UIImage
    var confidence: [Float]
}
struct RecognitionFailure: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}
final class BoardRecognizer {
    // Contract: 13-class per-square image classifier, labels K,Q,R,B,N,P,k,q,r,b,n,p,empty.
    // No fabricated fallback. A real licensed model is required to recognize pieces.
    func recognize(_ image: UIImage, screen: Bool = false, blackAtBottom: Bool = false, progress: (@Sendable (Int) -> Void)? = nil) throws -> RecognitionResult {
        guard let url = Bundle.main.url(forResource: "ChessPieces", withExtension: "mlmodelc") else {
            throw RecognitionFailure(message: "This build is missing its piece-recognition component. Reinstall a complete build of NovaChess. Your photograph has not been uploaded.")
        }
        let config = MLModelConfiguration(); config.computeUnits = .all
        let model = try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: config))
        guard let cg = image.cgImage else { throw RecognitionFailure(message: "Unable to read this photograph. Please retake it.") }
        let rectangles = VNDetectRectanglesRequest()
        rectangles.maximumObservations = screen ? 16 : 8; rectangles.minimumConfidence = screen ? 0.6 : 0.8
        rectangles.minimumAspectRatio = screen ? 0.4 : 0.65; rectangles.maximumAspectRatio = 1
        rectangles.minimumSize = screen ? 0.12 : 0.35; rectangles.quadratureTolerance = screen ? 35 : 18
        try VNImageRequestHandler(cgImage: cg).perform([rectangles])
        let candidates = rectangles.results?.filter {
            screen || ($0.boundingBox.minX > 0.01 && $0.boundingBox.minY > 0.01 && $0.boundingBox.maxX < 0.99 && $0.boundingBox.maxY < 0.99)
        } ?? []
        guard screen || !candidates.isEmpty else {
            throw RecognitionFailure(message: "No complete board boundary found. Include all four corners with a little space around them, face the board or screen directly, and avoid glare.")
        }
        let input = CIImage(cgImage: cg), size = input.extent.size
        let context = CIContext()
        func vector(_ point: CGPoint) -> CIVector { CIVector(x: point.x * size.width, y: point.y * size.height) }
        var bestArea: CGImage?
        var bestScore = -Double.infinity
        var areas: [(CGImage, Double)] = screen ? ScreenRecognition.candidates(cg).map { ($0, 1) } : []
        for board in candidates {
            try Task.checkCancellation()
            let corrected = input.applyingFilter("CIPerspectiveCorrection", parameters: ["inputTopLeft": vector(board.topLeft), "inputTopRight": vector(board.topRight), "inputBottomLeft": vector(board.bottomLeft), "inputBottomRight": vector(board.bottomRight)])
            if let rectified = context.createCGImage(corrected, from: corrected.extent) { areas.append((rectified, sqrt(Double(board.boundingBox.width * board.boundingBox.height)))) }
        }
        for (rectified, areaWeight) in areas {
            try Task.checkCancellation()
            let sampleSize = 256
            var gray = [UInt8](repeating: 0, count: sampleSize * sampleSize)
            let sampled = gray.withUnsafeMutableBytes { bytes -> Bool in
                guard let bitmap = CGContext(data: bytes.baseAddress, width: sampleSize, height: sampleSize, bitsPerComponent: 8, bytesPerRow: sampleSize, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
                bitmap.translateBy(x: 0, y: CGFloat(sampleSize)); bitmap.scaleBy(x: 1, y: -1)
                bitmap.draw(rectified, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize)); return true
            }
            guard sampled, let grid = BoardGrid.locate(gray: gray, width: sampleSize, height: sampleSize) else { continue }
            let sx = CGFloat(rectified.width) / CGFloat(sampleSize), sy = CGFloat(rectified.height) / CGFloat(sampleSize)
            let bounds = CGRect(x: CGFloat(grid.left) * sx, y: CGFloat(grid.top) * sy, width: CGFloat(grid.right - grid.left) * sx, height: CGFloat(grid.bottom - grid.top) * sy).integral
            guard let area = rectified.cropping(to: bounds) else { continue }
            let score = grid.quality * areaWeight
            if score > bestScore { bestScore = score; bestArea = area }
        }
        guard var playingArea = bestArea else {
            throw RecognitionFailure(message: "The board's 8 × 8 grid was not clear. Face the board or screen directly with even light and all corners visible.")
        }
        if blackAtBottom {
            let rotated = CIImage(cgImage: playingArea).oriented(.down)
            if let image = context.createCGImage(rotated, from: rotated.extent) { playingArea = image }
        }
        let screenRecognizer = screen ? ScreenRecognition() : nil
        let width = CGFloat(playingArea.width), height = CGFloat(playingArea.height)
        var detailModel: VNCoreMLModel?
        func classify(_ square: CGImage, using model: VNCoreMLModel) throws -> [String: Float] {
            let request = VNCoreMLRequest(model: model); request.imageCropAndScaleOption = .scaleFill
            try VNImageRequestHandler(cgImage: square).perform([request])
            guard let predictions = request.results as? [VNClassificationObservation], predictions.count == 13,
                  Set(predictions.map(\.identifier)) == Set(RecognitionFusion.labels),
                  predictions.allSatisfy({ $0.confidence.isFinite && $0.confidence >= 0 && $0.confidence <= 1 }) else {
                throw RecognitionFailure(message: "The recognition component in this build is incompatible. Reinstall a complete build of NovaChess.")
            }
            return Dictionary(uniqueKeysWithValues: predictions.map { ($0.identifier, $0.confidence) })
        }
        var position = Position(), uncertain: Set<Int> = [], confidence: [Float] = []
        for index in 0..<64 {
            let crop = CGRect(x: CGFloat(index%8)*width/8, y: CGFloat(index/8)*height/8, width: width/8, height: height/8).integral
            guard let square = playingArea.cropping(to: crop) else { throw RecognitionFailure(message:"Could not extract square \(Position.name(index)).") }
            try Task.checkCancellation()
            if let digital = screenRecognizer?.recognize(square), !digital.uncertain {
                confidence.append(digital.confidence)
                position.squares[index] = digital.label == "empty" ? nil : Piece(digital.label.first!)
                progress?(index + 1); continue
            }
            let primary = try classify(square, using: model)
            var verifier: [String: Float]?
            if RecognitionFusion.needsVerification(primary) {
                if detailModel == nil {
                    guard let detailURL = Bundle.main.url(forResource: "ChessPiecesDetail", withExtension: "mlmodelc") else {
                        throw RecognitionFailure(message: "This build is missing its recognition verifier. Reinstall a complete build of NovaChess.")
                    }
                    detailModel = try VNCoreMLModel(for: MLModel(contentsOf: detailURL, configuration: config))
                }
                if let detailModel { verifier = try classify(square, using: detailModel) }
            }
            let physical = RecognitionFusion.classify(primary: primary, verifier: verifier)
            let digital = screenRecognizer?.recognize(square)
            let decision = digital ?? physical
            confidence.append(decision.confidence)
            if decision.uncertain { uncertain.insert(index) }
            position.squares[index] = decision.label == "empty" ? nil : Piece(decision.label.first!)
            progress?(index + 1)
        }
        return RecognitionResult(position: position, uncertain: uncertain, image: UIImage(cgImage:playingArea), confidence:confidence)
    }
}
