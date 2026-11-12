import Foundation

public enum PositionInsights {
    private struct Finding {
        let priority: Int
        let text: String
    }
    /// Local whole-board assessment. Geometric threats are described without claiming a forced win.
    public static func observations(in board: Position, engine: EngineLine? = nil) -> [String] {
        guard board.squares.count == 64 else { return [] }
        let legal = board.legalMoves()
        if legal.isEmpty { return [board.isInCheck ? "Checkmate: \(board.turn.opposite.title) wins." : "Stalemate: the game is drawn."] }
        var findings: [Finding] = []
        func add(_ priority: Int, _ text: String) { findings.append(Finding(priority: priority, text: text)) }
        let occupied = board.squares.indices.filter { board.squares[$0] != nil }
        let nonKings = occupied.filter { board.squares[$0]?.kind != "k" }
        let loneMinor = nonKings.count == 1 && "bn".contains(board.squares[nonKings[0]]!.kind)
        let sameColorBishops = nonKings.allSatisfy { board.squares[$0]?.kind == "b" } && Set(nonKings.map { ($0 / 8 + $0 % 8) % 2 }).count <= 1
        if nonKings.isEmpty || loneMinor || sameColorBishops { return ["The position is drawn by insufficient mating material."] }
        if board.halfmove >= 150 { return ["The game is drawn under the 75-move rule: no pawn move or capture in 75 full moves."] }
        if board.halfmove >= 100 { add(118, "A draw can be claimed under the 50-move rule; the halfmove clock has reached \(board.halfmove).") }
        func indices(_ side: Side, kind: Character? = nil) -> [Int] {
            occupied.filter { board.squares[$0]?.side == side && (kind == nil || board.squares[$0]?.kind == kind) }
        }
        func name(_ square: Int) -> String {
            guard let piece = board.squares[square] else { return Position.name(square) }
            return "\(piece.name) on \(Position.name(square))"
        }
        func squares(_ list: [Int]) -> String { list.map(Position.name).joined(separator: ", ") }
        func attacked(from: Int, to: Int) -> Bool {
            guard let piece = board.squares[from], from != to else { return false }
            let dr = to / 8 - from / 8, dc = to % 8 - from % 8
            switch piece.kind {
            case "p": return dr == (piece.side == .white ? -1 : 1) && abs(dc) == 1
            case "n": return abs(dr) * abs(dc) == 2
            case "k": return max(abs(dr), abs(dc)) == 1
            default:
                let diagonal = abs(dr) == abs(dc), straight = dr == 0 || dc == 0
                guard (diagonal && "bq".contains(piece.kind)) || (straight && "rq".contains(piece.kind)) else { return false }
                let sr = dr == 0 ? 0 : dr > 0 ? 1 : -1, sc = dc == 0 ? 0 : dc > 0 ? 1 : -1
                var r = from / 8 + sr, c = from % 8 + sc
                while r != to / 8 || c != to % 8 {
                    if board.squares[r * 8 + c] != nil { return false }
                    r += sr; c += sc
                }
                return true
            }
        }
        let values: [Character: Int] = ["p": 1, "n": 3, "b": 3, "r": 5, "q": 9, "k": 0]
        func material(_ side: Side) -> Int { indices(side).reduce(0) { $0 + (values[board.squares[$1]!.kind] ?? 0) } }
        let balance = material(.white) - material(.black)
        if balance != 0 { add(80, "\(balance > 0 ? "White" : "Black") is ahead by \(abs(balance)) point\(abs(balance) == 1 ? "" : "s") of material. Activity and king safety can outweigh this count.") }
        if board.isInCheck { add(120, "\(board.turn.title) is in check: resolving the king threat takes priority over positional plans.") }
        if let engine {
            if let mate = engine.mate, mate != 0 { add(125, "The engine finds a forced mate for \(mate > 0 ? "White" : "Black") in \(abs(mate)) at depth \(engine.depth).") }
            else if let cp = engine.centipawns {
                let assessment = abs(cp) < 35 ? "roughly balanced" : "in \(cp > 0 ? "White" : "Black")'s favor"
                add(110, "The engine evaluates the position as \(assessment) (\(engine.evaluation), depth \(engine.depth)).")
            }
            if let uci = engine.moves.first, let move = legal.first(where: { $0.uci == uci }), let san = try? board.san(for: move), let next = try? board.playing(move) {
                var reasons: [String] = []
                if let victim = board.squares[move.to] { reasons.append("captures the \(victim.name.lowercased())") }
                else if board.squares[move.from]?.kind == "p", move.from % 8 != move.to % 8 { reasons.append("captures en passant") }
                if next.isInCheck { reasons.append("gives check") }
                if move.promotion != nil { reasons.append("promotes the pawn") }
                if board.squares[move.from]?.kind == "k", abs(move.to - move.from) == 2 { reasons.append("castles the king and activates a rook") }
                let reason = reasons.isEmpty ? "" : ": it " + reasons.joined(separator: " and ")
                var continuation = ""
                if let reply = engine.moves.dropFirst().first, let response = try? next.move(forSAN: reply), let sanReply = try? next.san(for: response) { continuation = " The main reply is \(sanReply)." }
                add(115, "Engine plan: \(san)\(reason).\(continuation)")
            }
        }
        let nonPawnMaterial = occupied.filter { !"pk".contains(board.squares[$0]!.kind) }.reduce(0) { $0 + (values[board.squares[$1]!.kind] ?? 0) }
        let endgame = indices(.white, kind: "q").isEmpty && indices(.black, kind: "q").isEmpty && nonPawnMaterial <= 20
        for side in Side.allCases {
            if Task.isCancelled { return [] }
            let own = indices(side), pawns = indices(side, kind: "p"), enemyPawns = indices(side.opposite, kind: "p")
            var sideBoard = board; sideBoard.turn = side
            if side != board.turn { sideBoard.enPassant = "-" }
            let sideLegal = side == board.turn ? legal : sideBoard.legalMoves()
            let hanging = own.filter { board.squares[$0]?.kind != "k" && board.attacked($0, by: side.opposite) && !board.attacked($0, by: side) }
            for square in hanging { add(105, "\(name(square)) is attacked and undefended. Check whether it can be captured safely.") }
            let loose = own.filter { board.squares[$0]?.kind != "k" && (values[board.squares[$0]!.kind] ?? 0) >= 3 && !board.attacked($0, by: side) && !hanging.contains($0) }
            if !loose.isEmpty && (board.fullmove > 4 || nonPawnMaterial < 40) { add(45, "\(side.title) has unprotected pieces on \(squares(loose)). They are not currently attacked, but can become tactical targets.") }
            let doubledFiles = (0..<8).filter { file in pawns.filter { $0 % 8 == file }.count > 1 }
            if !doubledFiles.isEmpty { add(58, "\(side.title) has doubled pawns on the \(doubledFiles.map { String(Array("abcdefgh")[$0]) }.joined(separator: ", ")) file(s). Their mobility and defense deserve attention.") }
            let isolated = pawns.filter { pawn in !pawns.contains { abs($0 % 8 - pawn % 8) == 1 } }
            if !isolated.isEmpty { add(59, "\(side.title)'s pawns on \(squares(isolated)) are isolated: no friendly pawn on an adjacent file can support them.") }
            let passed = pawns.filter { pawn in
                !enemyPawns.contains { abs($0 % 8 - pawn % 8) <= 1 && (side == .white ? $0 / 8 < pawn / 8 : $0 / 8 > pawn / 8) }
            }
            if !passed.isEmpty { add(endgame ? 95 : 72, "\(side.title) has passed pawn\(passed.count == 1 ? "" : "s") on \(squares(passed)). Support their advance and watch the blockading squares.") }
            let nearPromotion = pawns.filter { side == .white ? $0 / 8 == 1 : $0 / 8 == 6 }
            if !nearPromotion.isEmpty { add(98, "\(side.title)'s pawn\(nearPromotion.count == 1 ? "" : "s") on \(squares(nearPromotion)) are one rank from promotion. Check blockades, captures and promotion tactics.") }
            let central = pawns.filter { [3, 4].contains($0 % 8) && (side == .white ? $0 / 8 <= 4 : $0 / 8 >= 3) }
            if central.count >= 2 { add(50, "\(side.title) occupies the center with pawns on \(squares(central)); use that space to develop pieces while keeping the center supported.") }
            let bishops = indices(side, kind: "b")
            if Set(bishops.map { ($0 / 8 + $0 % 8) % 2 }).count == 2 && indices(side.opposite, kind: "b").count < 2 { add(55, "\(side.title) has the bishop pair. Opening lines can make the two bishops more effective.") }
            for square in own where board.squares[square]?.kind != "p" && board.squares[square]?.kind != "k" {
                let piece = board.squares[square]!
                if !sideBoard.isInCheck, !sideLegal.contains(where: { $0.from == square }), board.fullmove > 4 || nonPawnMaterial < 40 {
                    let row = square / 8, col = square % 8
                    let diagonals = [(-1,-1),(-1,1),(1,-1),(1,1)].compactMap { dr, dc -> Int? in
                        let r = row + dr, c = col + dc
                        return (0..<8).contains(r) && (0..<8).contains(c) ? r * 8 + c : nil
                    }
                    if piece.kind == "b", !diagonals.isEmpty, diagonals.allSatisfy({ board.squares[$0] == Piece(side == .white ? "P" : "p") }) {
                        add(62, "\(name(square)) is boxed in by its own pawns on the same color squares.")
                    } else { add(57, "\(name(square)) has no legal move in this position. Look for a way to free or support it.") }
                }
                if piece.kind == "r" {
                    let filePawns = occupied.filter { $0 % 8 == square % 8 && board.squares[$0]?.kind == "p" }
                    if filePawns.isEmpty { add(68, "\(name(square)) is on an open file, a useful route for pressure and invasion.") }
                    else if !filePawns.contains(where: { board.squares[$0]?.side == side }) { add(60, "\(name(square)) is on a semi-open file, facing an enemy pawn rather than a friendly pawn.") }
                    if square / 8 == (side == .white ? 1 : 6) { add(75, "\(name(square)) has reached the seventh rank, where it can pressure pawns and restrict the king.") }
                }
                if piece.kind == "n", (side == .white ? square / 8 <= 4 : square / 8 >= 3), pawns.contains(where: { attacked(from: $0, to: square) }), !enemyPawns.contains(where: { abs($0 % 8 - square % 8) == 1 && (side == .white ? $0 / 8 < square / 8 : $0 / 8 > square / 8) }) {
                    add(70, "\(name(square)) has a pawn-supported outpost: enemy pawns on adjacent files cannot advance to challenge it.")
                }
                let targets = indices(side.opposite).filter { ((values[board.squares[$0]!.kind] ?? 0) >= 3 || board.squares[$0]?.kind == "k") && attacked(from: square, to: $0) }
                if targets.count >= 2 { add(102, "\(name(square)) attacks \(squares(targets)) at once. This fork or double attack may force a concession; check pins and counterplay.") }
            }
            for pawn in pawns {
                let targets = indices(side.opposite).filter { ((values[board.squares[$0]!.kind] ?? 0) >= 3 || board.squares[$0]?.kind == "k") && attacked(from: pawn, to: $0) }
                if targets.count >= 2 { add(103, "\(name(pawn)) attacks \(squares(targets)) at once: a pawn fork worth calculating before making a quiet move.") }
            }
            if let king = indices(side, kind: "k").first {
                if endgame {
                    var distance = 7
                    let centers: [Int] = [27, 28, 35, 36]
                    for center in centers {
                        let rows = abs(center / 8 - king / 8)
                        let columns = abs(center % 8 - king % 8)
                        distance = min(distance, max(rows, columns))
                    }
                    if distance >= 3 { add(64, "\(side.title)'s king is far from the center in a queenless endgame. Look for safe routes to activate it and support pawns.") }
                } else if king / 8 == (side == .white ? 7 : 0), [0,1,2,5,6,7].contains(king % 8) {
                    let front = king / 8 + (side == .white ? -1 : 1)
                    let shield = pawns.filter { $0 / 8 == front && abs($0 % 8 - king % 8) <= 1 }
                    if shield.count <= 1 && !indices(side.opposite, kind: "q").isEmpty { add(78, "\(side.title)'s king has a thin immediate pawn shield. Watch open lines and checks near \(Position.name(king)).") }
                }
            }
            if board.fullmove <= 12 && nonPawnMaterial >= 40 {
                let undeveloped = own.filter { "nb".contains(board.squares[$0]!.kind) && $0 / 8 == (side == .white ? 7 : 0) }
                if undeveloped.count >= 2 { add(52, "\(side.title) still has \(undeveloped.count) minor pieces on the back rank. Development and king safety are the main opening priorities.") }
                if sideLegal.contains(where: { board.squares[$0.from]?.kind == "k" && abs($0.to - $0.from) == 2 }) { add(65, "\(side.title) can castle now; consider securing the king and connecting the rooks.") }
            }
        }
        // Absolute pins and skewers along unobstructed sliding-piece rays.
        for source in occupied where "brq".contains(board.squares[source]!.kind) {
            let slider = board.squares[source]!
            let directions = slider.kind == "b" ? [(-1,-1),(-1,1),(1,-1),(1,1)] : slider.kind == "r" ? [(-1,0),(1,0),(0,-1),(0,1)] : [(-1,-1),(-1,1),(1,-1),(1,1),(-1,0),(1,0),(0,-1),(0,1)]
            for (dr, dc) in directions {
                var row = source / 8 + dr, col = source % 8 + dc, hits: [Int] = []
                while (0..<8).contains(row) && (0..<8).contains(col) {
                    let square = row * 8 + col
                    if let piece = board.squares[square] {
                        if piece.side == slider.side { break }
                        hits.append(square); if hits.count == 2 { break }
                    }
                    row += dr; col += dc
                }
                if hits.count == 2 {
                    if board.squares[hits[1]]?.kind == "k" { add(100, "\(name(hits[0])) is pinned to its king by the \(name(source).lowercased()). Moving off that line exposes the king.") }
                    else if board.squares[hits[0]]?.kind == "k" { add(99, "The \(name(source).lowercased()) lines up the enemy king with \(Position.name(hits[1])) behind it: watch for a skewer when the king moves.") }
                }
            }
        }
        var seen = Set<String>()
        return findings.sorted { $0.priority == $1.priority ? $0.text < $1.text : $0.priority > $1.priority }.compactMap { seen.insert($0.text).inserted ? $0.text : nil }
    }
}
