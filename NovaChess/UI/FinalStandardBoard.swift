import SwiftUI

struct FinalStandardBoard: View {
    let position: Position
    let status: String
    var flipped = false
    @Environment(\.scenePhase) private var phase
    @ObservedObject private var engine = EngineController.shared
    private var terminal: Bool { position.legalMoves().isEmpty }
    private var line: EngineLine? { engine.analyzedFEN == position.fen ? engine.lines.first : nil }
    private var evaluation: String {
        if status == "draw" { return "0.00" }
        if terminal { return position.isInCheck ? (position.turn == .white ? "−M0" : "+M0") : "0.00" }
        return line?.evaluation ?? "…"
    }
    private var fraction: Double {
        if status == "draw" { return 0.5 }
        if terminal { return position.isInCheck ? (position.turn == .white ? 0 : 1) : 0.5 }
        return EvaluationScale.whiteFraction(centipawns: line?.centipawns, mate: line?.mate)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BoardEvaluationLayout {
                BoardView(position: position, flipped: flipped)
                EvaluationBar(whiteFraction: fraction)
            }
            Text(evaluation).font(.title.bold().monospacedDigit()).accessibilityLabel("Final position evaluation \(evaluation)")
        }
        .task(id: position.fen) { if !terminal && status != "draw" { engine.analyze(position) } }
        .onDisappear { engine.stopAnalysis() }
        .onChange(of: phase) { _, value in
            if value == .active && !terminal && status != "draw" { engine.analyze(position) }
            else { engine.stopAnalysis() }
        }
    }
}
