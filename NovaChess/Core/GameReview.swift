import Foundation

public enum ImprovementConcept: String, Codable, CaseIterable, Sendable {
    case repertoire, matingPatterns, kingSafety, material, pawnPlay, activity, calculation, variantStrategy, endgame
    public var title: String {
        switch self {
        case .repertoire: return "Repertoire recall"
        case .matingPatterns: return "Mating patterns"
        case .kingSafety: return "King safety"
        case .material: return "Material and tactical threats"
        case .pawnPlay: return "Pawn decisions"
        case .activity: return "Piece activity"
        case .calculation: return "Candidate-move calculation"
        case .variantStrategy: return "Variant goals and special rules"
        case .endgame: return "Endgame technique"
        }
    }
    public var practice: String {
        switch self {
        case .repertoire: return "Rehearse your saved branches at the positions where this game left your repertoire."
        case .matingPatterns: return "Practice forcing checks and mating sequences before choosing a quiet move."
        case .kingSafety: return "Check the opponent's forcing replies and keep escape squares and king cover in mind."
        case .material: return "Before moving, scan captures, loose pieces and the opponent's immediate threats."
        case .pawnPlay: return "Compare pawn advances, captures and promotion timing before committing to a structure."
        case .activity: return "Compare the destinations of your pieces and the replies each placement permits."
        case .calculation: return "List at least two candidate moves and calculate the opponent's strongest reply to each."
        case .variantStrategy: return "Revisit the variant objective, special threats and blocking or drop choices; ordinary material advice may not apply."
        case .endgame: return "Calculate king routes, pawn tempos and promotion races in the highlighted endgame positions."
        }
    }
}
public struct GameSuggestion: Codable, Identifiable, Sendable {
    public enum Source: String, Codable, Sendable { case repertoire, engine }
    public var id: Int { ply }
    public var ply: Int
    public var number: Int
    public var side: Side
    public var played: String
    public var recommended: [String]
    public var recommendedUCI: [String]
    public var source: Source
    public var concept: ImprovementConcept
    public var explanation: String
    public var centipawnLoss: Int?
    public var depth: Int?
    public var repertoireIDs: [UUID]
    public var label: String {
        if source == .repertoire { return "Repertoire deviation" }
        if concept == .matingPatterns { return "Missed mate" }
        if centipawnLoss == nil { return concept == .kingSafety ? "Mating threat" : "Critical move" }
        let loss = centipawnLoss ?? 0
        return loss >= 250 ? "Blunder" : loss >= 100 ? "Mistake" : "Inaccuracy"
    }
    public var moveLabel: String { "\(number)\(side == .white ? "." : "…") \(played)" }
}
public struct GameReview: Codable, Sendable {
    public var ungradedBughouseMoves: [Int]?
    public var repertoireSignature: String
    public var suggestions: [GameSuggestion] = []
    public var assessments: [MoveAssessment]?
    public var nextPly = 0
    public var assessedMoves = 0
    public var repertoireMatches = 0
    public var complete = false
    public var reviewedAt: Date?
    public init(signature: String) { repertoireSignature = signature }
    public var areas: [ImprovementConcept] {
        ImprovementConcept.allCases.filter { concept in suggestions.contains { $0.concept == concept } }
    }
}
public struct CompletedGame: Codable, Identifiable, Sendable {
    public var id: UUID
    public var game: SavedComputerGame
    public var result: String
    public var finishedAt: Date
    public var positions: [String] = []
    public var review: GameReview?
    public var ratingChange: Int?
    public var bughouse: BughouseMatch?
    public var partnerPositions: [String]?
    public var engineEvaluations: [Int: EngineLine]?
    public var evaluationSignature: String?
    public init(game: SavedComputerGame, result: String, now: Date = Date()) {
        self.id = game.id ?? UUID(); self.game = game; self.result = result; self.finishedAt = now
        if game.reviewEvaluationVersion == GameReviewLogic.evaluationVersion, let cache = game.prefetchedEvaluations {
            engineEvaluations = cache.filter { (0...game.moves.count).contains($0.key) }
            evaluationSignature = GameReviewLogic.evaluationSignature(for: self)
        }
        self.game.prefetchedEvaluations = nil; self.game.reviewEvaluationVersion = nil
    }
    public var moveCount: Int {
        if let bughouse { return GameStatistics.moveCount(plies: bughouse.events.filter { $0.board == 0 }.count) + GameStatistics.moveCount(plies: bughouse.events.filter { $0.board == 1 }.count) }
        return GameStatistics.moveCount(plies: game.moves.count)
    }
    public var humanMoveCount: Int { if let bughouse { return bughouse.events.filter { $0.board == 0 && $0.side == bughouse.config.human }.count }; return game.human == .white ? (game.moves.count + 1) / 2 : game.moves.count / 2 }
    /// Outcome relative to the local player, including either bughouse team.
    public var playerOutcome: String {
        if let match = bughouse, let winner = match.winner {
            return winner == 2 ? "Draw" : winner == match.config.humanTeam ? "Win" : "Loss"
        }
        guard result == "white" || result == "black" else { return "Draw" }
        return result == game.human.title.lowercased() ? "Win" : "Loss"
    }
    public var resultTitle: String { if let bughouse { return bughouse.resultTitle }; return result == "white" ? "White wins" : result == "black" ? "Black wins" : "Draw" }
}
public enum GameReviewLogic {
    public static let evaluationVersion = "sf19-nnue-1a298aa575a0-review3000-v1"
    public static func evaluationSignature(for entry: CompletedGame) -> String {
        let sequence = entry.bughouse?.events.map { "\($0.board):\($0.uci)" } ?? entry.game.moves
        return evaluationVersion + "|" + entry.game.variant + "|" + sequence.joined(separator: " ")
    }
    public static func signature(_ lines: [RepertoireLine]) -> String {
        let text = lines.map { "\($0.id)|\($0.name)|\($0.side.rawValue)|\($0.startingFEN)|\($0.moves.joined(separator: " "))" }.sorted().joined(separator: "\n")
        var hash: UInt64 = 14695981039346656037
        for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return "sf19-nnue-1a298aa575a0-review3000-allmoves-topmove-v3:" + String(hash, radix: 16)
    }
    public static func repertoireSuggestion(at board: Position, played: String, san: String, ply: Int, lines: [RepertoireLine] = [], choices supplied: [RepertoireMatch]? = nil) -> (matched: Bool, suggestion: GameSuggestion?) {
        let choices = supplied ?? RepertoireTraining.choices(at: board, in: lines)
        guard !choices.isEmpty else { return (false, nil) }
        if choices.contains(where: { $0.move == played }) { return (true, nil) }
        var unique = Set<String>()
        let options = choices.filter { unique.insert($0.move).inserted }
        let notation = options.compactMap { try? board.move(forSAN: $0.move) }.compactMap { try? board.san(for: $0) }
        guard !notation.isEmpty else { return (false, nil) }
        let names = Array(Set(choices.map { $0.line.name })).sorted().joined(separator: ", ")
        return (true, GameSuggestion(ply: ply, number: board.fullmove, side: board.turn, played: san, recommended: notation, recommendedUCI: options.map(\.move), source: .repertoire, concept: .repertoire, explanation: "Your saved repertoire (\(names)) calls for \(notation.joined(separator: " or ")) here. This is an opening-recall suggestion, not an engine verdict on \(san).", centipawnLoss: nil, depth: nil, repertoireIDs: Array(Set(choices.map { $0.line.id }))))
    }
    public static func engineSuggestion(ply: Int, side: Side, number: Int, played: VariantMove, before: VariantSnapshot, after: VariantSnapshot, baseline: EngineLine, outcome: EngineLine?, standard: Bool, variant: String = "chess") -> GameSuggestion? {
        guard let bestUCI = baseline.moves.first, let best = before.moves.first(where: { $0.uci == bestUCI }), best.uci != played.uci else { return nil }
        let sign = side == .white ? 1 : -1
        let beforeMate = baseline.mate.map { $0 * sign }
        let afterMate: Int? = after.finished ? (after.status == (side == .white ? "white" : "black") ? 1 : after.status == "draw" ? nil : -1) : outcome?.mate.map { $0 * sign }
        if after.finished && after.status == (side == .white ? "white" : "black") { return nil }
        if let b = beforeMate, let a = afterMate, (b > 0 && a > 0) || (b < 0 && a < 0) { return nil }
        var concept: ImprovementConcept = .calculation
        let loss: Int?
        var reason: String
        if (beforeMate ?? 0) > 0 && (afterMate ?? 0) <= 0 {
            concept = standard ? .matingPatterns : .variantStrategy; loss = nil
            reason = standard ? "The engine found a forced mate before this move, but no longer finds one afterward." : "The engine found a forced variant win before this move, but no longer finds one afterward."
        } else if (afterMate ?? 0) < 0 && (beforeMate ?? 0) >= 0 {
            concept = standard ? .kingSafety : .variantStrategy; loss = nil
            reason = "This move allowed an engine-detected forced loss."
        } else {
            guard let start = baseline.centipawns, let finish = after.status == "draw" ? 0 : outcome?.centipawns else { return nil }
            let change = (start - finish) * sign
            guard change >= 60 else { return nil }
            loss = change
            reason = "The quick engine comparison drops by about \(String(format: "%.2f", Double(change) / 100)) pawns after this move."
        }
        if let reply = outcome?.moves.first, let move = after.moves.first(where: { $0.uci == reply }) {
            reason += " The engine's main reply is \(move.san)."
            if concept == .calculation, let target = move.to, after.board.squares[target]?.side == side { concept = .material }
        }
        if concept == .calculation {
            let actualPiece = played.from.flatMap { before.board.squares[$0] }
            let preferredPiece = best.from.flatMap { before.board.squares[$0] }
            if actualPiece?.kind == "k" && standard { concept = .kingSafety }
            else if actualPiece?.kind == "p" || preferredPiece?.kind == "p" { concept = .pawnPlay }
            else if played.from == best.from { concept = .activity }
        }
        if standard, loss != nil, [.kingSafety, .pawnPlay, .activity].contains(concept) {
            let pieces = before.board.squares.compactMap { $0 }
            let hasQueen = pieces.contains { $0.kind == "q" }
            let nonPawnPieces = pieces.filter { !"pk".contains($0.kind) }.count
            if !hasQueen && nonPawnPieces <= 2 { concept = .endgame }
        }
        if variant == "antichess" { concept = .variantStrategy }
        if played.duckDestination != nil, played.pieceMove == best.pieceMove {
            concept = .variantStrategy
            reason += " The piece move is the same; the recommended duck square changes the blocking pattern."
        } else if best.drop != nil || played.drop != nil {
            concept = .variantStrategy
            reason += " Compare the timing and square of the pocket drop."
        } else if before.checksRemaining != nil, best.san.contains("+"), !played.san.contains("+") {
            concept = .variantStrategy
            reason += " Checks also advance the three-check winning objective."
        } else if variant == "kingofthehill", best.from.flatMap({ before.board.squares[$0]?.kind }) == "k" {
            concept = .variantStrategy
            reason += " Compare the king's routes to the four central winning squares."
        }
        let depth = min(baseline.depth, outcome?.depth ?? baseline.depth)
        return GameSuggestion(ply: ply, number: number, side: side, played: played.san, recommended: [best.san], recommendedUCI: [best.uci], source: .engine, concept: concept, explanation: reason, centipawnLoss: loss, depth: depth, repertoireIDs: [])
    }
}

public struct ReviewRepertoireIndex: Sendable {
    public var positions: [String: [RepertoireMatch]] = [:]
    public init(lines: [RepertoireLine]) throws {
        for line in lines {
            try Task.checkCancellation()
            guard var board = try? Position(fen: line.startingFEN) else { continue }
            for (index, uci) in line.moves.enumerated() {
                try Task.checkCancellation()
                guard let move = board.legalMoves().first(where: { $0.uci == uci }) else { break }
                if board.turn == line.side { positions[board.openingKey, default: []].append(RepertoireMatch(line: line, index: index, move: uci)) }
                board = try board.playing(move)
            }
        }
    }
}
