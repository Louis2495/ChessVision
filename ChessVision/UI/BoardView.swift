import SwiftUI

struct PieceView: View {
    var piece: Piece
    var body: some View {
        Image((piece.side == .white ? "w" : "b") + String(piece.kind).uppercased())
            .resizable().renderingMode(.original).scaledToFit()
            .shadow(color: .black.opacity(0.16), radius: 0.8, y: 1)
            .accessibilityLabel(piece.name)
    }
}

struct BoardView: View {
    var position: Position
    var uncertain: Set<Int> = []
    var selected: Int? = nil
    var legalTargets: Set<Int> = []
    var flipped = false
    var onTap: ((Int) -> Void)? = nil
    var body: some View {
        GeometryReader { geometry in
            let cell = geometry.size.width / 8
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { col in
                            let index = flipped ? 63 - (row * 8 + col) : row * 8 + col
                            let light = (index / 8 + index % 8).isMultiple(of: 2)
                            Button { onTap?(index) } label: {
                                ZStack {
                                    Rectangle().fill(light ? Color(red: 0.91, green: 0.89, blue: 0.82) : Color(red: 0.36, green: 0.47, blue: 0.40))
                                    if let piece = position.squares[index] { PieceView(piece: piece).padding(cell * 0.055) }
                                    if legalTargets.contains(index) {
                                        if position.squares[index] == nil { Circle().fill(.black.opacity(0.20)).frame(width: cell * 0.24, height: cell * 0.24) }
                                        else { Circle().strokeBorder(.cyan.opacity(0.8), lineWidth: 3).padding(2) }
                                    }
                                    if uncertain.contains(index) { Rectangle().strokeBorder(Color.orange, lineWidth: 3) }
                                    if selected == index { Rectangle().strokeBorder(Color.cyan, lineWidth: 3) }
                                }
                                .overlay(alignment: .topLeading) {
                                    if col == 0 { Text(String(8 - index / 8)).padding(2).coordinateStyle(cell: cell, light: light) }
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    if row == 7 { Text(String(Position.name(index).prefix(1))).padding(2).coordinateStyle(cell: cell, light: light) }
                                }
                                .frame(width: cell, height: cell)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(Position.name(index)), \(position.squares[index]?.name ?? "empty")\(uncertain.contains(index) ? ", uncertain recognition" : "")")
                            .accessibilityIdentifier("square-\(Position.name(index))")
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private extension View {
    func coordinateStyle(cell: CGFloat, light: Bool) -> some View {
        font(.system(size: max(9, cell * 0.20), weight: .bold))
            .foregroundStyle(light ? Color(red: 0.25, green: 0.37, blue: 0.29) : Color(red: 0.96, green: 0.94, blue: 0.86))
    }
}

struct TurnBadge: View {
    var side: Side
    var body: some View {
        HStack(spacing: 7) {
            Text("Turn:").foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 3)
                .fill(side == .white ? Color.white : Color.black)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(.gray.opacity(0.65), lineWidth: 1))
                .frame(width: 18, height: 18)
                .accessibilityLabel(side.title)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Turn: \(side.title)")
    }
}

struct EvaluationBar: View {
    var whiteFraction: Double
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Color(white: 0.12).frame(height: geometry.size.height * (1 - min(1, max(0, whiteFraction))))
                Color(white: 0.98)
            }
            .overlay { Rectangle().stroke(.gray.opacity(0.4), lineWidth: 1) }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .animation(.easeInOut(duration: 0.25), value: whiteFraction)
        .accessibilityLabel("Evaluation balance: \(Int(whiteFraction * 100)) percent white")
    }
}

private struct BoardEvaluationLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 346
        return CGSize(width: width, height: max(0, width - 26))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let side = max(0, bounds.width - 26)
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: side, height: side))
        subviews[1].place(at: CGPoint(x: bounds.minX + side + 8, y: bounds.minY), proposal: ProposedViewSize(width: 18, height: side))
    }
}

struct EvaluatedBoard: View {
    var position: Position
    var whiteFraction: Double
    var selected: Int?
    var legalTargets: Set<Int>
    var onTap: (Int) -> Void
    var body: some View {
        BoardEvaluationLayout {
            BoardView(position: position, selected: selected, legalTargets: legalTargets, onTap: onTap)
            EvaluationBar(whiteFraction: whiteFraction)
        }
    }
}
