import Foundation

extension Position {
    public var openingKey: String {
        var fields = fen.split(separator: " ").prefix(4).map(String.init)
        if enPassant != "-", !legalMoves().contains(where: { $0.to == Self.index(enPassant) && squares[$0.from]?.kind == "p" && $0.from % 8 != $0.to % 8 }) { fields[3] = "-" }
        return fields.joined(separator: " ")
    }
    public func move(forSAN input: String) throws -> ChessMove {
        var san = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "0", with: "O")
        while let last = san.last, "+#!?".contains(last) { san.removeLast() }
        let legal = legalMoves()
        if san == "O-O" || san == "O-O-O" {
            let delta = san == "O-O" ? 2 : -2
            guard let move = legal.first(where: { squares[$0.from]?.kind == "k" && $0.to - $0.from == delta }) else { throw ChessError.invalid("Illegal castle: \(input)") }
            return move
        }
        if let move = legal.first(where: { $0.uci.lowercased() == san.lowercased() }) { return move }
        let pattern = #"^([KQRBN])?([a-h])?([1-8])?(x)?([a-h][1-8])(?:=?([QRBN]))?$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(san.startIndex..., in: san)
        guard let match = regex.firstMatch(in: san, range: range) else { throw ChessError.invalid("Unrecognized move: \(input)") }
        func group(_ index: Int) -> String { guard let r = Range(match.range(at: index), in: san) else { return "" }; return String(san[r]) }
        let kind = Character(group(1).isEmpty ? "p" : group(1).lowercased())
        let candidates = legal.filter { move in
            guard squares[move.from]?.kind == kind, Self.name(move.to) == group(5) else { return false }
            if !group(2).isEmpty && String(Self.name(move.from).prefix(1)) != group(2) { return false }
            if !group(3).isEmpty && String(Self.name(move.from).suffix(1)) != group(3) { return false }
            let promotion = move.promotion.map { String($0).uppercased() } ?? ""
            if promotion != group(6) { return false }
            let capture = squares[move.to] != nil || (kind == "p" && move.from % 8 != move.to % 8)
            return capture == !group(4).isEmpty
        }
        guard candidates.count == 1, let move = candidates.first else { throw ChessError.invalid("Illegal or ambiguous move: \(input)") }
        return move
    }
}

public struct PGNGame: Sendable {
    public var tags: [String: String]
    public var moves: [String]
    public static func parse(_ text: String, maxPlies: Int = 1000) throws -> PGNGame {
        guard text.utf8.count <= 2_000_000 else { throw ChessError.invalid("This game is too large to import.") }
        let tagRegex = try NSRegularExpression(pattern: #"(?m)^\s*\[(\w+)\s+\"((?:[^\"\\]|\\.)*)\"\]\s*$"#)
        let full = NSRange(text.startIndex..., in: text)
        var tags: [String: String] = [:]
        for match in tagRegex.matches(in: text, range: full) {
            if let key = Range(match.range(at: 1), in: text), let value = Range(match.range(at: 2), in: text) { tags[String(text[key])] = String(text[value]).replacingOccurrences(of: #"\""#, with: "\"") }
        }
        let body = tagRegex.stringByReplacingMatches(in: text, range: full, withTemplate: " ")
        var clean = "", braces = 0, variations = 0, lineComment = false
        for ch in body {
            if lineComment { if ch == "\n" { lineComment = false; clean += " " }; continue }
            if ch == ";" && braces == 0 { lineComment = true; continue }
            if ch == "{" { braces += 1; continue }
            if ch == "}" { braces = max(0, braces - 1); continue }
            if braces > 0 { continue }
            if ch == "(" { variations += 1; continue }
            if ch == ")" { variations = max(0, variations - 1); continue }
            if variations == 0 { clean.append(ch) }
        }
        guard braces == 0 && variations == 0 else { throw ChessError.invalid("Unclosed PGN comment or variation.") }
        var board = try Position(fen: tags["FEN"] ?? Position.initial.fen)
        guard board.problems.isEmpty else { throw ChessError.invalid(board.problems.joined(separator: "\n")) }
        var moves: [String] = []
        for raw in clean.split(whereSeparator: { $0.isWhitespace }) {
            if moves.count == maxPlies { break }
            var token = String(raw)
            token = token.replacingOccurrences(of: #"^\d+\.+"#, with: "", options: .regularExpression)
            if token.isEmpty || token.hasPrefix("$") || token == "..." || token == "e.p." { continue }
            if ["1-0", "0-1", "1/2-1/2", "*"].contains(token) { if tags["Result"] == nil { tags["Result"] = token }; break }
            let move = try board.move(forSAN: token)
            moves.append(move.uci); try board.apply(uci: move.uci)
        }
        return PGNGame(tags: tags, moves: moves)
    }
}
public enum GameResult: String, Codable, Sendable { case white = "1-0", black = "0-1", draw = "1/2-1/2", unknown = "*" }
public struct OpeningGame: Codable, Sendable {
    public var white: String
    public var black: String
    public var result: GameResult
    public var moves: [String]
    public init(white: String, black: String, result: GameResult, moves: [String]) { self.white = white; self.black = black; self.result = result; self.moves = moves }
}
public struct OpeningLine: Codable, Identifiable, Sendable {
    public var id: String
    public var eco: String
    public var name: String
    public var moves: [String]
    public var key: String
}
public struct OpeningCounts: Sendable, Equatable {
    public var games = 0
    public var whiteWins = 0
    public var blackWins = 0
    public var draws = 0
    public mutating func record(_ result: GameResult) {
        games += 1
        switch result { case .white: whiteWins += 1; case .black: blackWins += 1; case .draw: draws += 1; case .unknown: break }
    }
}
public struct OpeningBranch: Sendable, Identifiable {
    public var uci: String
    public var san: String
    public var counts = OpeningCounts()
    public var id: String { uci }
}
public struct OpeningNode: Sendable {
    public var counts = OpeningCounts()
    public var branches: [String: OpeningBranch] = [:]
}
public struct OpeningTree: Sendable {
    public private(set) var nodes: [String: OpeningNode] = [:]
    public private(set) var gameCount = 0
    public init() {}
    public mutating func add(_ game: OpeningGame, maxPlies: Int = 40) throws {
        var board = Position.initial
        var visited: Set<String> = []
        var events: [(String, String, String)] = []
        for uci in game.moves.prefix(maxPlies) {
            try Task.checkCancellation()
            let key = board.openingKey
            guard let move = board.legalMoves().first(where: { $0.uci == uci }) else { throw ChessError.invalid("Imported game contains an illegal opening move.") }
            if visited.insert(key).inserted { events.append((key, uci, try board.san(for: move))) }
            try board.apply(uci: uci)
        }
        // Do not partially update statistics if validation or cancellation fails.
        for (key, uci, san) in events {
            var node = nodes[key] ?? OpeningNode()
            node.counts.record(game.result)
            var branch = node.branches[uci] ?? OpeningBranch(uci: uci, san: san)
            branch.counts.record(game.result); node.branches[uci] = branch; nodes[key] = node
        }
        let finalKey = board.openingKey
        if !visited.contains(finalKey) {
            var node = nodes[finalKey] ?? OpeningNode(); node.counts.record(game.result); nodes[finalKey] = node
        }
        gameCount += 1
    }
    public func branches(at position: Position) -> [OpeningBranch] {
        (nodes[position.openingKey]?.branches.values.map { $0 } ?? []).sorted { a, b in a.counts.games == b.counts.games ? a.san < b.san : a.counts.games > b.counts.games }
    }
}
