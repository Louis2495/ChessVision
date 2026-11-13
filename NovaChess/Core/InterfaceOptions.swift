import Foundation

public enum OpponentChoice: String, CaseIterable, Sendable {
    case developer, adaptive, matched, custom
    public var title: String {
        switch self {
        case .developer: return "Play the Developer"
        case .adaptive: return "Adaptive difficulty"
        case .matched: return "Match my level"
        case .custom: return "Custom"
        }
    }
}

public enum InterfaceContrast {
    public static func luminance(_ hex: UInt32) -> Double {
        func linear(_ component: UInt32) -> Double {
            let value = Double(component) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear((hex >> 16) & 255) + 0.7152 * linear((hex >> 8) & 255) + 0.0722 * linear(hex & 255)
    }
    public static func foreground(on hex: UInt32) -> UInt32 {
        let luminance = luminance(hex)
        return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05) ? 0x000000 : 0xFFFFFF
    }
}
