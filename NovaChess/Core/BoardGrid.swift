import Foundation
public struct BoardGridBounds: Equatable {
    public var left: Int
    public var top: Int
    public var right: Int
    public var bottom: Int
    public var quality: Double
}
public enum BoardGrid {
    // Refine a perspective-corrected rectangular candidate to the PLAYING area.
    // Seven periodic internal edges in each axis reject generic rectangles/tabletops.
    public static func locate(gray: [UInt8], width: Int, height: Int) -> BoardGridBounds? {
        guard width >= 128, height >= 128, gray.count == width*height else { return nil }
        func profile(vertical: Bool) -> [Double] {
            let length = vertical ? width : height, cross = vertical ? height : width
            var result = Array(repeating:0.0,count:length)
            for axis in 2..<(length-2) {
                var differences: [Double] = []
                for other in stride(from:cross/10,to:cross*9/10,by:2) {
                    let before = vertical ? other*width+axis-2 : (axis-2)*width+other
                    let after = vertical ? other*width+axis+2 : (axis+2)*width+other
                    differences.append(abs(Double(gray[before])-Double(gray[after])))
                }
                differences.sort(); result[axis] = differences[differences.count*3/5]
            }
            return result
        }
        func fit(_ values: [Double]) -> (Int,Int,Double)? {
            let n = values.count
            var best = -Double.infinity, bounds: (Int,Int,Double)?
            let baseline = values.sorted()[n/2]
            for start in 0...(n*15/100) {
                for end in (n*85/100)..<n where end-start >= n*7/10 {
                    let step = Double(end-start)/8
                    var edges: [Double] = []
                    for k in 1...7 {
                        let i = Int((Double(start)+Double(k)*step).rounded())
                        edges.append(values[max(0,i-1)...min(n-1,i+1)].max() ?? 0)
                    }
                    let score = edges.reduce(0) { $0+log(1+$1) }
                    if score > best && edges.filter({$0 > max(12,baseline*1.5)}).count >= 6 {best=score; bounds=(start,end,score)}
                }
            }
            return bounds
        }
        guard let x=fit(profile(vertical:true)),let y=fit(profile(vertical:false)) else {return nil}
        return BoardGridBounds(left:x.0,top:y.0,right:x.1,bottom:y.1,quality:exp((x.2+y.2)/14)-1)
    }
}
