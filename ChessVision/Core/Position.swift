import Foundation

public enum Side: String, CaseIterable, Codable, Sendable {
    case white = "w", black = "b"
    public var opposite: Side { self == .white ? .black : .white }
    public var title: String { self == .white ? "White" : "Black" }
}
public struct Piece: Equatable, Codable, Sendable {
    public var symbol: Character
    public init(_ symbol: Character) { self.symbol = symbol }
    public var side: Side { symbol.isUppercase ? .white : .black }
    public var kind: Character { Character(symbol.lowercased()) }
    public var glyph: String {
        let chars: [Character: String] = ["K":"♔", "Q":"♕", "R":"♖", "B":"♗", "N":"♘", "P":"♙", "k":"♚", "q":"♛", "r":"♜", "b":"♝", "n":"♞", "p":"♟"]
        return chars[symbol] ?? "?"
    }
    public var name: String {
        let names: [Character:String] = ["k":"king", "q":"queen", "r":"rook", "b":"bishop", "n":"knight", "p":"pawn"]
        return "\(side.title) \(names[kind] ?? "piece")"
    }
    enum CodingKeys: String, CodingKey { case symbol }
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer().decode(String.self)
        guard c.count == 1, let ch = c.first, "KQRBNPkqrbnp".contains(ch) else { throw ChessError.invalid("Invalid piece.") }
        symbol = ch
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(String(symbol)) }
}
public enum ChessError: Error, LocalizedError { case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
public struct Position: Equatable, Sendable {
    // a8 = 0, h1 = 63. FEN and recognition use the same indexing.
    public var squares: [Piece?] = Array(repeating: nil, count: 64)
    public var turn: Side = .white
    public var castling = ""
    public var enPassant = "-"
    public var halfmove = 0
    public var fullmove = 1
    public init() {}
    public static let initial = try! Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    public static func name(_ index: Int) -> String { "\(Array("abcdefgh")[index % 8])\(8 - index / 8)" }
    public static func index(_ name: String) -> Int? {
        let a = Array(name)
        guard a.count == 2, let f = "abcdefgh".firstIndex(of: a[0]), let rank = a[1].wholeNumberValue, (1...8).contains(rank) else { return nil }
        return (8-rank)*8 + "abcdefgh".distance(from: "abcdefgh".startIndex, to: f)
    }
    public init(fen: String) throws {
        self.init()
        let fields = fen.split(separator: " ").map(String.init)
        guard fields.count == 6, let side = Side(rawValue: fields[1]), let h = Int(fields[4]), h >= 0, let f = Int(fields[5]), f >= 1 else { throw ChessError.invalid("FEN requires six valid fields.") }
        let ranks = fields[0].split(separator: "/", omittingEmptySubsequences:false)
        guard ranks.count == 8 else { throw ChessError.invalid("FEN needs eight ranks.") }
        var result: [Piece?] = []
        for rank in ranks {
            var row: [Piece?] = []
            for ch in rank {
                if let n = ch.wholeNumberValue, (1...8).contains(n) { row += Array(repeating: nil, count: n) }
                else if "KQRBNPkqrbnp".contains(ch) { row.append(Piece(ch)) }
                else { throw ChessError.invalid("Unknown FEN piece.") }
            }
            guard row.count == 8 else { throw ChessError.invalid("Each rank must contain eight squares.") }
            result += row
        }
        guard fields[2] == "-" || (!fields[2].isEmpty && fields[2].allSatisfy({ "KQkq".contains($0) }) && Set(fields[2]).count == fields[2].count), fields[3] == "-" || Self.index(fields[3]) != nil else { throw ChessError.invalid("Invalid castling or en passant field.") }
        squares = result; turn = side; castling = fields[2] == "-" ? "" : fields[2]; enPassant = fields[3]; halfmove = h; fullmove = f
    }
    public var fen: String {
        var ranks: [String] = []
        for row in 0..<8 {
            var rank = "", empty = 0
            for col in 0..<8 {
                if let p = squares[row*8+col] { if empty > 0 { rank += String(empty); empty = 0 }; rank.append(p.symbol) }
                else { empty += 1 }
            }
            if empty > 0 { rank += String(empty) }; ranks.append(rank)
        }
        let rights = "KQkq".filter { castling.contains($0) }
        return "\(ranks.joined(separator: "/")) \(turn.rawValue) \(rights.isEmpty ? "-" : rights) \(enPassant) \(halfmove) \(fullmove)"
    }
    public func attacked(_ square: Int, by side: Side) -> Bool {
        for i in 0..<64 {
            guard let p = squares[i], p.side == side else { continue }
            let dr = square/8-i/8, dc = square%8-i%8
            switch p.kind {
            case "p": if dr == (side == .white ? -1 : 1) && abs(dc) == 1 { return true }
            case "n": if abs(dr)*abs(dc) == 2 { return true }
            case "k": if max(abs(dr),abs(dc)) == 1 { return true }
            default:
                let diagonal = abs(dr) == abs(dc) && dr != 0
                let straight = (dr == 0 || dc == 0) && dr != dc
                if (diagonal && "bq".contains(p.kind)) || (straight && "rq".contains(p.kind)) {
                    let sr = dr == 0 ? 0 : (dr > 0 ? 1 : -1), sc = dc == 0 ? 0 : (dc > 0 ? 1 : -1)
                    var r = i/8+sr, c = i%8+sc, clear = true
                    while r != square/8 || c != square%8 { if squares[r*8+c] != nil { clear = false; break }; r += sr; c += sc }
                    if clear { return true }
                }
            }
        }
        return false
    }
    public var problems: [String] {
        var issues: [String] = []
        for side in Side.allCases {
            let pieces = squares.compactMap { $0 }.filter { $0.side == side }
            if pieces.filter({ $0.kind == "k" }).count != 1 { issues.append("\(side.title) must have exactly one king.") }
            if pieces.count > 16 { issues.append("\(side.title) has more than 16 pieces.") }
            let pawns = pieces.filter { $0.kind == "p" }.count
            if pawns > 8 { issues.append("\(side.title) has more than eight pawns.") }
            var extras = max(0, pieces.filter { $0.kind == "q" }.count - 1)
            for kind: Character in ["r", "b", "n"] { extras += max(0, pieces.filter { $0.kind == kind }.count - 2) }
            if extras > 8-pawns { issues.append("\(side.title) has more promoted pieces than missing pawns permit.") }
        }
        if (0..<8).contains(where: { squares[$0]?.kind == "p" || squares[56+$0]?.kind == "p" }) { issues.append("Pawns cannot be on rank 1 or rank 8.") }
        if let k = squares.firstIndex(where: { $0?.kind == "k" && $0?.side == turn.opposite }), attacked(k, by: turn) { issues.append("The side that just moved is in check. Check the pieces and whose turn it is.") }
        for (right,k,r) in [(Character("K"),60,63),("Q",60,56),("k",4,7),("q",4,0)] where castling.contains(right) {
            let side: Side = right.isUppercase ? .white : .black
            if squares[k] != Piece(side == .white ? "K" : "k") || squares[r] != Piece(side == .white ? "R" : "r") { issues.append("Castling right \(right) requires its king and rook on their starting squares.") }
        }
        if enPassant != "-" {
            if let ep = Self.index(enPassant) {
                let pawn = ep + (turn == .white ? 8 : -8), origin = ep + (turn == .white ? -8 : 8)
                if ep/8 != (turn == .white ? 2 : 5) || squares[ep] != nil || !(0..<64).contains(pawn) || squares[pawn] != Piece(turn == .white ? "p" : "P") || !(0..<64).contains(origin) || squares[origin] != nil || halfmove != 0 { issues.append("En passant must match the opponent's last two-square pawn move (with halfmove clock zero).") }
            } else { issues.append("Invalid en passant square.") }
        }
        return issues
    }
    // Apply engine-supplied legal UCI moves, including promotions, castling and en passant.
    // This is deliberately not a move-legality generator; only Stockfish supplies playback moves.
    public mutating func apply(uci: String) throws {
        guard uci.count == 4 || uci.count == 5, let from = Self.index(String(uci.prefix(2))), let to = Self.index(String(uci.dropFirst(2).prefix(2))), from != to, let piece = squares[from], piece.side == turn, squares[to]?.side != turn else { throw ChessError.invalid("Invalid engine move: \(uci)") }
        let capture = squares[to] != nil
        if uci.count == 5 && (piece.kind != "p" || !"qrbn".contains(uci.last!) || (to/8 != 0 && to/8 != 7)) { throw ChessError.invalid("Invalid promotion.") }
        if piece.kind == "p", to == Self.index(enPassant), squares[to] == nil { squares[to + (turn == .white ? 8 : -8)] = nil }
        squares[from] = nil; squares[to] = piece
        if piece.kind == "p", uci.count == 5, let promotion = uci.last { squares[to] = Piece(turn == .white ? Character(promotion.uppercased()) : promotion) }
        if piece.kind == "k" {
            if abs(to-from) == 2 { let rookFrom = to > from ? from+3 : from-4; let rookTo = to > from ? from+1 : from-1; squares[rookTo] = squares[rookFrom]; squares[rookFrom] = nil }
            castling.removeAll { turn == .white ? "KQ".contains($0) : "kq".contains($0) }
        }
        for (sq,right) in [(0,Character("q")),(7,"k"),(56,"Q"),(63,"K")] where from == sq || to == sq { castling.removeAll{$0 == right} }
        enPassant = piece.kind == "p" && abs(to-from) == 16 ? Self.name((from+to)/2) : "-"
        halfmove = piece.kind == "p" || capture ? 0 : halfmove+1
        if turn == .black { fullmove += 1 }; turn = turn.opposite
    }
}
