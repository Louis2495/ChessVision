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
    func recognize(_ image: UIImage, progress: (@Sendable (Int) -> Void)? = nil) throws -> RecognitionResult {
        guard let url = Bundle.main.url(forResource: "ChessPieces", withExtension: "mlmodelc") else {
            throw RecognitionFailure(message: "This build is missing its piece-recognition component. Reinstall a complete build of ChessVision. Your photograph has not been uploaded.")
        }
        let config = MLModelConfiguration(); config.computeUnits = .all
        let model = try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: config))
        guard let cg = image.cgImage else { throw RecognitionFailure(message: "Unable to read this photograph. Please retake it.") }
        let rectangles = VNDetectRectanglesRequest()
        rectangles.maximumObservations = 8; rectangles.minimumConfidence = 0.8
        rectangles.minimumAspectRatio = 0.65; rectangles.maximumAspectRatio = 1
        rectangles.minimumSize = 0.35; rectangles.quadratureTolerance = 18
        try VNImageRequestHandler(cgImage: cg).perform([rectangles])
        let candidates = rectangles.results?.filter {
            $0.boundingBox.minX > 0.01 && $0.boundingBox.minY > 0.01 && $0.boundingBox.maxX < 0.99 && $0.boundingBox.maxY < 0.99
        } ?? []
        guard !candidates.isEmpty else {
            throw RecognitionFailure(message: "No complete board boundary found. Retake directly above the board, include all four corners with a little space around them, and avoid glare.")
        }
        let input = CIImage(cgImage: cg), size = input.extent.size
        let context = CIContext()
        func vector(_ point: CGPoint) -> CIVector { CIVector(x: point.x * size.width, y: point.y * size.height) }
        var bestArea: CGImage?
        var bestScore = -Double.infinity
        // A tabletop can be larger than the board. Test every complete candidate's actual grid.
        for board in candidates {
            try Task.checkCancellation()
            let corrected = input.applyingFilter("CIPerspectiveCorrection", parameters: ["inputTopLeft": vector(board.topLeft), "inputTopRight": vector(board.topRight), "inputBottomLeft": vector(board.bottomLeft), "inputBottomRight": vector(board.bottomRight)])
            guard let rectified = context.createCGImage(corrected, from: corrected.extent) else { continue }
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
            let score = grid.quality * sqrt(Double(board.boundingBox.width * board.boundingBox.height))
            if score > bestScore { bestScore = score; bestArea = area }
        }
        guard let playingArea = bestArea else {
            throw RecognitionFailure(message: "The board's 8 × 8 grid was not clear. Retake directly above the board with even light and all corners visible.")
        }
        let width = CGFloat(playingArea.width), height = CGFloat(playingArea.height)
        var detailModel: VNCoreMLModel?
        func classify(_ square: CGImage, using model: VNCoreMLModel) throws -> [String: Float] {
            let request = VNCoreMLRequest(model: model); request.imageCropAndScaleOption = .scaleFill
            try VNImageRequestHandler(cgImage: square).perform([request])
            guard let predictions = request.results as? [VNClassificationObservation], predictions.count == 13,
                  Set(predictions.map(\.identifier)) == Set(RecognitionFusion.labels),
                  predictions.allSatisfy({ $0.confidence.isFinite && $0.confidence >= 0 && $0.confidence <= 1 }) else {
                throw RecognitionFailure(message: "The recognition component in this build is incompatible. Reinstall a complete build of ChessVision.")
            }
            return Dictionary(uniqueKeysWithValues: predictions.map { ($0.identifier, $0.confidence) })
        }
        var position = Position(), uncertain: Set<Int> = [], confidence: [Float] = []
        for index in 0..<64 {
            let crop = CGRect(x: CGFloat(index%8)*width/8, y: CGFloat(index/8)*height/8, width: width/8, height: height/8).integral
            guard let square = playingArea.cropping(to: crop) else { throw RecognitionFailure(message:"Could not extract square \(Position.name(index)).") }
            try Task.checkCancellation()
            let primary = try classify(square, using: model)
            var verifier: [String: Float]?
            if RecognitionFusion.needsVerification(primary) {
                if detailModel == nil {
                    guard let detailURL = Bundle.main.url(forResource: "ChessPiecesDetail", withExtension: "mlmodelc") else {
                        throw RecognitionFailure(message: "This build is missing its recognition verifier. Reinstall a complete build of ChessVision.")
                    }
                    detailModel = try VNCoreMLModel(for: MLModel(contentsOf: detailURL, configuration: config))
                }
                if let detailModel { verifier = try classify(square, using: detailModel) }
            }
            let decision = RecognitionFusion.classify(primary: primary, verifier: verifier)
            confidence.append(decision.confidence)
            if decision.uncertain { uncertain.insert(index) }
            position.squares[index] = decision.label == "empty" ? nil : Piece(decision.label.first!)
            progress?(index + 1)
        }
        return RecognitionResult(position: position, uncertain: uncertain, image: UIImage(cgImage:playingArea), confidence:confidence)
    }
}
