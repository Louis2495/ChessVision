import Foundation

public struct DigitalPieceTemplate: Sendable {
    public var label: String
    public var rgba: [UInt8]
    public init(label: String, rgba: [UInt8]) { self.label = label; self.rgba = rgba }
}
public enum DigitalPieceMatcher {
    /// Compares a screen square against transparent piece templates on its actual background.
    /// This is a conservative template check, not a calibrated neural probability.
    public static func recognize(gray: [UInt8], size: Int, templates: [DigitalPieceTemplate]) -> SquareRecognition? {
        guard size >= 16, gray.count == size * size else { return nil }
        var corners: [Double] = []
        for y in [1,2,3,size-4,size-3,size-2] { for x in [1,2,3,size-4,size-3,size-2] { corners.append(Double(gray[y*size+x])) } }
        corners.sort()
        let background = corners[corners.count/2]
        let edgeMargin = max(3, size/6)
        var energy = 0.0
        for y in edgeMargin..<size-edgeMargin { for x in edgeMargin..<size-edgeMargin { energy += abs(Double(gray[y*size+x]) - background) } }
        let centralCount = Double((size-2*edgeMargin)*(size-2*edgeMargin))
        if energy / centralCount < 3 { return SquareRecognition(label: "empty", confidence: 0.9, uncertain: false) }
        let count = Double((size-4)*(size-4))
        var errors: [String: Double] = [:]
        for template in templates where template.rgba.count == size * size * 4 {
            var error = 0.0
            for y in 2..<size-2 { for x in 2..<size-2 {
                let index = y * size + x, i = index * 4
                let alpha = Double(template.rgba[i+3]) / 255
                let luma = Double(template.rgba[i]) * 0.299 + Double(template.rgba[i+1]) * 0.587 + Double(template.rgba[i+2]) * 0.114
                let target = alpha * luma + (1-alpha) * background
                error += abs(Double(gray[index]) - target)
            } }
            errors[template.label] = min(errors[template.label] ?? .infinity, error / count / 255)
        }
        let ranked = errors.sorted { $0.value < $1.value }
        guard ranked.count >= 2, let best = ranked.first, best.value < 0.075 else { return nil }
        let margin = ranked[1].value - best.value
        return SquareRecognition(label: best.key, confidence: Float(max(0.5, min(0.95, 1 - best.value * 3))), uncertain: best.value > 0.035 || margin < 0.008)
    }
}
