import Foundation

public enum AppTheme: String, CaseIterable, Sendable {
    case pink = "Pink", forest = "Forest", ocean = "Ocean", plum = "Plum", amber = "Amber", rose = "Rose", teal = "Teal", indigo = "Indigo", graphite = "Graphite"
    public var hex: UInt32 {
        switch self {
        case .pink: return 0xEF5BA8
        case .forest: return 0x23845D
        case .ocean: return 0x1D7CDD
        case .plum: return 0x9948C5
        case .amber: return 0xD7980C
        case .rose: return 0xDC507D
        case .teal: return 0x089B9A
        case .indigo: return 0x6E65DD
        case .graphite: return 0x677F9E
        }
    }
}
public enum AppBackdrop: String, CaseIterable, Sendable {
    case pink = "Pink", standard = "Default", warm = "Warm", cool = "Cool", parchment = "Parchment", sage = "Sage", lavender = "Lavender", blush = "Blush", theme = "Theme", aurora = "Aurora", sunset = "Sunset", grid = "Grid"
    public var hex: UInt32? {
        switch self {
        case .pink: return 0xF3A8CD
        case .standard: return nil
        case .warm, .parchment: return 0xBA8E50
        case .cool: return 0x5B88B8
        case .sage: return 0x66937B
        case .lavender: return 0x9D86B8
        case .blush: return 0xC77B93
        case .theme, .aurora, .sunset, .grid: return nil
        }
    }
}
public enum BoardStyle: String, CaseIterable, Sendable {
    case classic = "Classic", walnut = "Walnut", slate = "Slate", ocean = "Ocean", sand = "Sand", rose = "Rose", mint = "Mint", lavender = "Lavender", cocoa = "Cocoa", ebony = "Ebony", tournament = "Tournament", ice = "Ice"
    public var lightHex: UInt32 {
        switch self {
        case .classic: return 0xE8E3D1
        case .walnut: return 0xEAD7B7
        case .slate: return 0xDFE6EE
        case .ocean: return 0xDEEAF2
        case .sand: return 0xF3E4C7
        case .rose: return 0xF5DFE4
        case .mint: return 0xDDEFE5
        case .lavender: return 0xE9E2F1
        case .cocoa: return 0xE8D8CB
        case .ebony: return 0xE4E4E4
        case .tournament: return 0xF0ECD8
        case .ice: return 0xE8F4F6
        }
    }
    public var darkHex: UInt32 {
        switch self {
        case .classic: return 0x5C7866
        case .walnut: return 0x6E4730
        case .slate: return 0x526680
        case .ocean: return 0x376E99
        case .sand: return 0xAB844C
        case .rose: return 0xA85D77
        case .mint: return 0x527F69
        case .lavender: return 0x7C6899
        case .cocoa: return 0x795848
        case .ebony: return 0x414751
        case .tournament: return 0x3B6C48
        case .ice: return 0x4B8290
        }
    }
}
public enum PieceStyle: String, CaseIterable, Sendable {
    case illustrated = "Illustrated", merida = "Merida", sculpted = "Sculpted", fantasy = "Fantasy", chessnut = "Chessnut", celtic = "Celtic"
    public func asset(for piece: Piece) -> String {
        let name = (piece.side == .white ? "w" : "b") + piece.kind.uppercased()
        return self == .illustrated ? name : rawValue + "-" + name
    }
}
