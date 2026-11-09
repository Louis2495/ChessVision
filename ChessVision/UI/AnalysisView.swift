import SwiftUI
struct AnalysisView: View {
    let original: Position
    let seconds: Int
    @ObservedObject private var engine = EngineController.shared
    @State private var rank = 1
    @State private var ply = 0
    @State private var playback: Position?
    @State private var playbackError: String?
    @State private var frozenMoves: [String] = []
    private var variation: EngineLine? { engine.lines.first{$0.rank == rank} }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                BoardView(position:playback ?? original)
                if let error = engine.error { Text(error).foregroundStyle(.red) }
                if engine.running { ProgressView("Stockfish is analyzing…") }
                if let line = variation {
                    HStack { Text(line.evaluation).font(.largeTitle.bold().monospacedDigit()); Spacer();Text("Depth \(line.depth)").foregroundStyle(.secondary) }
                    Text("Evaluation is from White's perspective.").font(.caption).foregroundStyle(.secondary)
                    Text("Best move: \(engine.bestMove == "(none)" ? "No legal moves" : (line.moves.first ?? "—"))").font(.headline)
                    Picker("Variation",selection:$rank) { ForEach(engine.lines,id:\.rank) { line in Text("\(line.rank): \(line.evaluation)").tag(line.rank) } }.pickerStyle(.segmented).disabled(engine.running)
                    Text((frozenMoves.isEmpty ? line.moves : frozenMoves).joined(separator:"  ")).font(.body.monospaced()).textSelection(.enabled)
                    HStack {
                        Button("Previous",systemImage:"backward.end") { step(-1) }.disabled(ply == 0 || engine.running)
                        Spacer()
                        Text("\(ply) ply").monospacedDigit()
                        Spacer()
                        Button("Next",systemImage:"forward.end") { step(1) }.disabled(engine.running || ply >= (frozenMoves.isEmpty ? line.moves.count : frozenMoves.count))
                    }
                    Button("Return to original position") { ply=0; playback=nil; frozenMoves=[] }
                }
                if engine.bestMove == "(none)" && engine.lines.isEmpty { Text("No legal moves: checkmate or stalemate.").font(.headline) }
                if let playbackError {Text(playbackError).foregroundStyle(.red)}
                if engine.running { Button("Stop analysis",role:.destructive) { engine.stop() } }
                else { Button("Analyze again") { reset(); engine.analyze(original,seconds:seconds) }.buttonStyle(.borderedProminent) }
            }.padding()
        }.navigationTitle("Stockfish analysis")
        .onAppear { reset(); engine.analyze(original,seconds:seconds) }
        .onDisappear { engine.stop() }
        .onChange(of:rank) { _,_ in reset() }
    }
    private func reset() {ply=0; playback=nil; frozenMoves=[]; playbackError=nil}
    private func step(_ delta: Int) {
        if frozenMoves.isEmpty { frozenMoves=variation?.moves ?? [] }
        let target=max(0,min(frozenMoves.count,ply+delta))
        var board=original
        do {for move in frozenMoves.prefix(target) {try board.apply(uci:move)}; playback=board; ply=target}
        catch {playbackError=error.localizedDescription}
    }
}
