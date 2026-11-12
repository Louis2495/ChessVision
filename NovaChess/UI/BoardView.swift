import SwiftUI
import UniformTypeIdentifiers

struct PieceView: View {
    @AppStorage("pieceStyle") private var style = "Illustrated"
    var piece: Piece
    var body: some View {
        Image((PieceStyle(rawValue: style) ?? .illustrated).asset(for: piece))
            .resizable().renderingMode(.original).scaledToFit()
            .shadow(color: .black.opacity(0.14), radius: 0.8, y: 1)
            .accessibilityLabel(piece.name)
    }

}

struct BoardView: View {
    @AppStorage("boardStyle") private var style = "Classic"
    var position: Position
    var uncertain: Set<Int> = []
    var selected: Int? = nil
    var legalTargets: Set<Int> = []
    var premoveSquares: Set<Int> = []
    var flipped = false
    var hidePieces = false
    var obscured: Set<Int> = []
    var duckSquare: Int? = nil
    var moveAssessment: MoveAssessment? = nil
    var onDropPiece: ((Character, Int) -> Void)? = nil
    var onDragMove: ((Int, Int) -> Void)? = nil
    var onTap: ((Int) -> Void)? = nil
    @State private var dragging: Int?
    @State private var dragPoint = CGPoint.zero
    var body: some View {
        GeometryReader { geometry in
            let cell = geometry.size.width / 8
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { col in
                            let index = flipped ? 63 - (row * 8 + col) : row * 8 + col
                            square(index: index, row: row, col: col, cell: cell)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 8, coordinateSpace: .local)
                .onChanged { value in
                    guard onTap != nil else { return }
                    if dragging == nil {
                        guard let source = squareAt(value.startLocation, cell: cell), !obscured.contains(source), position.squares[source] != nil || duckSquare == source else { return }
                        dragging = source
                    }
                    dragPoint = value.location
                }
                .onEnded { value in
                    defer { dragging = nil }
                    guard let source = dragging, let target = squareAt(value.location, cell: cell), source != target else { return }
                    if let onDragMove { onDragMove(source, target); return }
                    if selected != source { onTap?(source) }
                    onTap?(target)
                }, including: onTap == nil ? .none : .all)
            .overlay(alignment: .topLeading) {
                if !hidePieces, let source = dragging {
                    Group {
                        if let piece = position.squares[source] { PieceView(piece: piece) }
                        else if duckSquare == source { Image("CartoonDuck").resizable().scaledToFit() }
                    }.frame(width: cell, height: cell).position(dragPoint).allowsHitTesting(false)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    private func squareAt(_ point: CGPoint, cell: CGFloat) -> Int? {
        guard cell > 0, point.x >= 0, point.y >= 0, point.x < cell * 8, point.y < cell * 8 else { return nil }
        let index = Int(point.y / cell) * 8 + Int(point.x / cell)
        return flipped ? 63 - index : index
    }
    private func squareColor(light: Bool) -> Color {
        let board = BoardStyle(rawValue: style) ?? .classic
        return Color(hex: light ? board.lightHex : board.darkHex)
    }
    private func coordinateColor(light: Bool) -> Color {
        let board = BoardStyle(rawValue: style) ?? .classic
        let value = light ? board.lightHex : board.darkHex
        let brightness = Double((value >> 16) & 255) * 0.299 + Double((value >> 8) & 255) * 0.587 + Double(value & 255) * 0.114
        return brightness > 150 ? .black.opacity(0.78) : .white.opacity(0.95)
    }
    private func squareLabel(_ index: Int) -> String {
        let contents: String
        if hidePieces || obscured.contains(index) { contents = "hidden" }
        else if duckSquare == index { contents = "Duck" }
        else { contents = position.squares[index]?.name ?? "empty" }
        let warning = uncertain.contains(index) ? ", uncertain recognition" : ""
        let grade = moveAssessment?.destination == index ? ", " + (moveAssessment?.quality.title ?? "") : ""
        return "\(Position.name(index)), \(contents)\(warning)\(grade)"
    }
    private func square(index: Int, row: Int, col: Int, cell: CGFloat) -> some View {
        let light = (index / 8 + index % 8).isMultiple(of: 2)
        return Button { onTap?(index) } label: {
            ZStack {
                Rectangle().fill(squareColor(light: light))
                if premoveSquares.contains(index) { Rectangle().fill(Color.cyan.opacity(0.65)) }
                if selected == index { Rectangle().fill(Color.accentColor.opacity(0.20)) }
                if dragging != index && !hidePieces && !obscured.contains(index), let piece = position.squares[index] { PieceView(piece: piece).padding(cell * 0.055) }
                if dragging != index && duckSquare == index { Image("CartoonDuck").resizable().scaledToFit().padding(cell * 0.06).accessibilityLabel("Duck") }
                if obscured.contains(index) { Rectangle().fill(Color(white: 0.18).opacity(0.94)) }
                if legalTargets.contains(index) {
                    if position.squares[index] == nil { Circle().fill(coordinateColor(light: light).opacity(0.5)).frame(width: cell * 0.24, height: cell * 0.24) }
                    else { Circle().strokeBorder(Color.accentColor.opacity(0.8), lineWidth: 3).padding(2) }
                }
                if premoveSquares.contains(index) { Rectangle().strokeBorder(Color.blue, lineWidth: 4) }
                if uncertain.contains(index) { Rectangle().strokeBorder(Color.orange, lineWidth: 3) }
                if selected == index { Rectangle().strokeBorder(Color.accentColor, lineWidth: 3) }
            }
            .overlay(alignment: .topTrailing) {
                if let moveAssessment, moveAssessment.destination == index, !hidePieces && !obscured.contains(index) {
                    Image(systemName: moveAssessment.quality.symbol).font(.system(size: max(12, cell * 0.32), weight: .bold))
                        .foregroundStyle(moveAssessment.quality.color).padding(2).background(.regularMaterial, in: Circle()).padding(1)
                }
            }
            .overlay(alignment: .topLeading) {
                if col == 0 { Text(String(8 - index / 8)).padding(2).coordinateStyle(cell: cell, foreground: premoveSquares.contains(index) ? .black : coordinateColor(light: light)) }
            }
            .overlay(alignment: .bottomTrailing) {
                if row == 7 { Text(String(Position.name(index).prefix(1))).padding(2).coordinateStyle(cell: cell, foreground: premoveSquares.contains(index) ? .black : coordinateColor(light: light)) }
            }
            .frame(width: cell, height: cell)
        }
        .buttonStyle(.plain)
        .onDrop(of: [UTType.text.identifier], isTargeted: nil) { providers in
            guard onDropPiece != nil, let provider = providers.first, provider.canLoadObject(ofClass: NSString.self) else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { value, _ in
                guard let text = value as? String, text.hasPrefix("novachess-pocket:"), let token = text.split(separator: ":").last, token.count == 1, let kind = token.first, "PNBRQ".contains(kind) else { return }
                Task { @MainActor in onDropPiece?(kind, index) }
            }
            return true
        }
        .accessibilityLabel(squareLabel(index))
        .accessibilityIdentifier("square-\(Position.name(index))")
        .accessibilityAddTraits(selected == index ? .isSelected : [])
        .accessibilityRemoveTraits(onTap == nil ? .isButton : [])
        .allowsHitTesting(onTap != nil)
    }

}

private extension View {
    func coordinateStyle(cell: CGFloat, foreground: Color) -> some View {
        font(.system(size: max(9, cell * 0.20), weight: .bold))
            .foregroundStyle(foreground)
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

struct BoardEvaluationLayout: Layout {
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
