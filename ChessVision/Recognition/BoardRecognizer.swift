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
    func recognize(_ image: UIImage) throws -> RecognitionResult {
        guard let url = Bundle.main.url(forResource: "ChessPieces", withExtension: "mlmodelc") else {
            throw RecognitionFailure(message: "Piece recognition is not installed in this build. A licensed, validated ChessPieces Core ML classifier is required. Your photograph has not been guessed or uploaded. See the project's Recognition documentation.")
        }
        let config = MLModelConfiguration(); config.computeUnits = .all
        let model = try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: config))
        guard let cg = image.cgImage else { throw RecognitionFailure(message: "Unable to read this photograph. Please retake it.") }
        let rectangles = VNDetectRectanglesRequest()
        rectangles.maximumObservations = 8; rectangles.minimumConfidence = 0.8
        rectangles.minimumAspectRatio = 0.65; rectangles.maximumAspectRatio = 1
        rectangles.minimumSize = 0.35; rectangles.quadratureTolerance = 18
        try VNImageRequestHandler(cgImage: cg).perform([rectangles])
        guard let board = rectangles.results?.filter({ $0.boundingBox.minX > 0.015 && $0.boundingBox.minY > 0.015 && $0.boundingBox.maxX < 0.985 && $0.boundingBox.maxY < 0.985 }).max(by: { $0.boundingBox.width*$0.boundingBox.height < $1.boundingBox.width*$1.boundingBox.height }) else {
            throw RecognitionFailure(message: "No complete board boundary found. Retake directly above the board, include all four corners with a little space around them, and avoid glare.")
        }
        let input = CIImage(cgImage: cg), size = input.extent.size
        func vector(_ p: CGPoint) -> CIVector { CIVector(x: p.x*size.width, y: p.y*size.height) }
        let corrected = input.applyingFilter("CIPerspectiveCorrection", parameters: ["inputTopLeft":vector(board.topLeft), "inputTopRight":vector(board.topRight), "inputBottomLeft":vector(board.bottomLeft), "inputBottomRight":vector(board.bottomRight)])
        let context = CIContext()
        guard let rectified = context.createCGImage(corrected, from: corrected.extent) else { throw RecognitionFailure(message:"Perspective correction failed. Please retake the photo.") }
        let width = CGFloat(rectified.width), height = CGFloat(rectified.height)
        var position = Position(), uncertain: Set<Int> = [], confidence: [Float] = []
        for index in 0..<64 {
            let crop = CGRect(x: CGFloat(index%8)*width/8, y: CGFloat(index/8)*height/8, width: width/8, height: height/8).integral
            guard let square = rectified.cropping(to: crop) else { throw RecognitionFailure(message:"Could not extract square \(Position.name(index)).") }
            let request = VNCoreMLRequest(model: model); request.imageCropAndScaleOption = .scaleFill
            try VNImageRequestHandler(cgImage: square).perform([request])
            guard let predictions = request.results as? [VNClassificationObservation], let best = predictions.first, best.identifier == "empty" || (best.identifier.count == 1 && "KQRBNPkqrbnp".contains(best.identifier)) else { throw RecognitionFailure(message:"The installed model does not use the required chess-piece labels.") }
            confidence.append(best.confidence)
            let margin = best.confidence - (predictions.dropFirst().first?.confidence ?? 0)
            if best.confidence < 0.85 || margin < 0.25 { uncertain.insert(index) }
            position.squares[index] = best.identifier == "empty" ? nil : Piece(best.identifier.first!)
        }
        return RecognitionResult(position: position, uncertain: uncertain, image: UIImage(cgImage:rectified), confidence:confidence)
    }
}
