import UIKit

final class ScreenRecognition {
    private(set) var templates: [DigitalPieceTemplate] = []
    init() {
        let size = 48
        for style in PieceStyle.allCases {
            for symbol in "KQRBNPkqrbnp" {
                guard let asset = UIImage(named: style.asset(for: Piece(symbol))) else { continue }
                for scale in [0.74, 0.84, 0.92] {
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
                    let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { _ in
                        let side = Double(size) * scale, inset = (Double(size) - side) / 2
                        asset.draw(in: CGRect(x: inset, y: inset, width: side, height: side))
                    }
                    guard let cg = image.cgImage else { continue }
                    var bytes = [UInt8](repeating: 0, count: size*size*4)
                    let okay = bytes.withUnsafeMutableBytes { storage -> Bool in
                        guard let context = CGContext(data: storage.baseAddress, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                        context.translateBy(x: 0, y: CGFloat(size)); context.scaleBy(x: 1, y: -1)
                        context.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size)); return true
                    }
                    if okay {
                        // Convert premultiplied color back to straight color for background compositing.
                        for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i+3] > 0 {
                            let alpha = Int(bytes[i+3])
                            for offset in 0..<3 { bytes[i+offset] = UInt8(min(255, Int(bytes[i+offset])*255/alpha)) }
                        }
                        templates.append(DigitalPieceTemplate(label: String(symbol), rgba: bytes))
                    }
                }
            }
        }
    }
    func recognize(_ image: CGImage) -> SquareRecognition? {
        guard let gray = Self.gray(image, size: 48) else { return nil }
        return DigitalPieceMatcher.recognize(gray: gray, size: 48, templates: templates)
    }
    static func gray(_ image: CGImage, size: Int) -> [UInt8]? {
        var data = [UInt8](repeating: 0, count: size*size)
        let okay = data.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .high
            context.translateBy(x: 0, y: CGFloat(size)); context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size)); return true
        }
        return okay ? data : nil
    }
    /// Screenshot UI can surround a borderless board. Rank padded windows, then let
    /// BoardGrid validate the seven internal edges rather than accepting a rectangle blindly.
    static func candidates(_ image: CGImage) -> [CGImage] {
        let width = image.width, height = image.height, shortest = min(width, height)
        var ranked: [(Double, CGImage)] = []
        for fraction in [1.0,0.85,0.7,0.55] {
            let side = Int(Double(shortest)*fraction)
            let windowWidth = min(width, Int(Double(side)*1.15)), windowHeight = min(height, Int(Double(side)*1.25))
            let step = max(16, side/8)
            let ys = Array(Set(Array(stride(from: 0, through: height-windowHeight, by: step)) + [height-windowHeight])).sorted()
            let xs = Array(Set(Array(stride(from: 0, through: width-windowWidth, by: step)) + [width-windowWidth])).sorted()
            for y in ys {
                for x in xs {
                    guard let crop = image.cropping(to: CGRect(x: x, y: y, width: windowWidth, height: windowHeight)), let pixels = gray(crop, size: 64) else { continue }
                    var light = 0.0, dark = 0.0
                    for row in 0..<8 { for column in 0..<8 {
                        let i = (row*8+2)*64 + column*8+2
                        if (row+column).isMultiple(of: 2) { light += Double(pixels[i]) } else { dark += Double(pixels[i]) }
                    } }
                    ranked.append((abs(light-dark)/32, crop))
                }
            }
        }
        return [image] + ranked.sorted { $0.0 > $1.0 }.prefix(10).map(\.1)
    }
}
