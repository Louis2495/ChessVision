import Foundation

public struct DeveloperBookLine: Sendable {
    public var name: String
    public var side: Side
    public var moves: [String]
}
public enum DeveloperOpeningBook {
    public static let rating = 2407
    public static let lines: [DeveloperBookLine] = {
        let repertoire: [(String, Side, String)] = [
            ("Italian · Giuoco Piano", .white, "1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. c3 Nf6 5. d3 d6 6. O-O O-O 7. Re1 a6 8. Bb3 Ba7"),
            ("Italian · Two Knights", .white, "1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. d3 Bc5 5. O-O d6 6. c3 O-O 7. Re1 a6 8. Bb3"),
            ("Grand Prix · kingside fianchetto", .white, "1. e4 c5 2. Nc3 Nc6 3. f4 g6 4. Nf3 Bg7 5. Bc4 e6 6. O-O Nge7 7. d3 O-O 8. Qe1"),
            ("Grand Prix · d6", .white, "1. e4 c5 2. Nc3 d6 3. f4 Nc6 4. Nf3 g6 5. Bc4 Bg7 6. O-O e6 7. d3 Nge7 8. Qe1"),
            ("Grand Prix · e6", .white, "1. e4 c5 2. Nc3 e6 3. f4 Nc6 4. Nf3 d5 5. Bb5 Nf6 6. Bxc6+ bxc6 7. e5"),
            ("French Tarrasch · closed center", .white, "1. e4 e6 2. d4 d5 3. Nd2 Nf6 4. e5 Nfd7 5. Bd3 c5 6. c3 Nc6 7. Ngf3 Qb6 8. O-O cxd4 9. cxd4"),
            ("French Tarrasch · open center", .white, "1. e4 e6 2. d4 d5 3. Nd2 c5 4. exd5 exd5 5. Ngf3 Nc6 6. Bb5 Bd6 7. O-O Nge7 8. dxc5 Bxc5 9. Nb3"),
            ("Alekhine · Exchange with c-pawn recapture", .white, "1. e4 Nf6 2. e5 Nd5 3. d4 d6 4. exd6 cxd6 5. Nf3 g6 6. Be2 Bg7 7. O-O O-O 8. c4 Nb6 9. Nc3"),
            ("Alekhine · Exchange with e-pawn recapture", .white, "1. e4 Nf6 2. e5 Nd5 3. d4 d6 4. exd6 exd6 5. Nf3 Be7 6. Be2 O-O 7. O-O Nc6 8. c4 Nb6 9. Nc3"),
            ("Open Ruy Lopez", .black, "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Nxe4 6. d4 b5 7. Bb3 d5 8. dxe5 Be6 9. c3 Be7 10. Nbd2 O-O"),
            ("Nimzo-Indian · Rubinstein", .black, "1. d4 Nf6 2. c4 e6 3. Nc3 Bb4 4. e3 O-O 5. Bd3 d5 6. Nf3 c5 7. O-O Nc6"),
            ("Nimzo-Indian · Classical", .black, "1. d4 Nf6 2. c4 e6 3. Nc3 Bb4 4. Qc2 O-O 5. a3 Bxc3+ 6. Qxc3 b6 7. Bg5 Bb7 8. e3 d6"),
            ("Nimzo-Indian · Sämisch", .black, "1. d4 Nf6 2. c4 e6 3. Nc3 Bb4 4. a3 Bxc3+ 5. bxc3 c5 6. e3 Nc6 7. Bd3 d6 8. Ne2 O-O"),
            ("Catalan · Nf3 first", .black, "1. d4 Nf6 2. c4 e6 3. Nf3 d5 4. g3 dxc4 5. Bg2 Be7 6. O-O O-O"),
            ("Catalan · g3 first", .black, "1. d4 Nf6 2. c4 e6 3. g3 d5 4. Bg2 dxc4 5. Nf3 Be7 6. O-O O-O"),
            ("Catalan · early fianchetto", .black, "1. d4 Nf6 2. Nf3 e6 3. g3 d5 4. c4 dxc4 5. Bg2 Be7 6. O-O O-O"),
            ("Catalan · early g3", .black, "1. d4 Nf6 2. g3 e6 3. Bg2 d5 4. c4 dxc4 5. Nf3 Be7 6. O-O O-O")
        ]
        return repertoire.compactMap { name, side, pgn in
            guard let game = try? PGNGame.parse(pgn) else { return nil }
            return DeveloperBookLine(name: name, side: side, moves: game.moves)
        }
    }()
    private static let positions: [String: String] = {
        var result: [String: String] = [:]
        for line in lines {
            var board = Position.initial
            for uci in line.moves {
                if board.turn == line.side && result[board.openingKey] == nil { result[board.openingKey] = uci }
                guard (try? board.apply(uci: uci)) != nil else { break }
            }
        }
        return result
    }()
    public static func move(history: [String], side: Side, legal: [VariantMove]) -> String? {
        guard history.count <= 40 else { return nil }
        var board = Position.initial
        for uci in history { guard (try? board.apply(uci: uci)) != nil else { return nil } }
        guard board.turn == side else { return nil }
        let allowed = Set(legal.map(\.uci))
        // Keep the Grand Prix setup against common second-move Sicilian alternatives.
        if side == .white, history.count == 4, Array(history.prefix(3)) == ["e2e4", "c7c5", "b1c3"],
           board.squares[Position.index("d5")!] != Piece("p"), allowed.contains("f2f4"),
           board.legalMoves().contains(where: { $0.uci == "f2f4" }) { return "f2f4" }
        // Accept the Catalan pawn at the first legal opportunity, including transpositions.
        if side == .black, board.squares[Position.index("d4")!] == Piece("P"), board.squares[Position.index("c4")!] == Piece("P"),
           (board.squares[Position.index("g3")!] == Piece("P") || board.squares[Position.index("g2")!] == Piece("B")), allowed.contains("d5c4"),
           board.legalMoves().contains(where: { $0.uci == "d5c4" }) { return "d5c4" }
        guard let candidate = positions[board.openingKey], allowed.contains(candidate) else { return nil }
        return candidate
    }
}
