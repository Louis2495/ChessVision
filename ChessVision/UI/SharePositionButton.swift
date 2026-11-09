import SwiftUI
import UIKit

struct SharePositionButton: View {
    var position: Position
    @State private var items: [Any] = []
    @State private var sharing = false
    @State private var message: String?
    var body: some View {
        Menu {
            Button("Share FEN", systemImage: "text.alignleft") { share(image: false, fen: true) }
            Button("Share board image", systemImage: "photo") { share(image: true, fen: false) }
            Button("Share image & FEN", systemImage: "square.and.arrow.up") { share(image: true, fen: true) }
        } label: { Label("Share position", systemImage: "square.and.arrow.up") }
        .sheet(isPresented: $sharing) { PositionShareSheet(items: items) }
        .alert("Unable to share", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
    }
    @MainActor private func share(image: Bool, fen: Bool) {
        var content: [Any] = []
        if image {
            guard let rendered = BoardImageExporter.image(for: position) else { message = "The board image could not be created. Please try again."; return }
            content.append(rendered)
        }
        if fen { content.append(position.fen) }
        items = content; sharing = true
    }
}

@MainActor enum BoardImageExporter {
    static func image(for position: Position) -> UIImage? {
        let renderer = ImageRenderer(content: BoardSnapshot(position: position).environment(\.colorScheme, .light))
        renderer.scale = 2
        return renderer.uiImage
    }
}

private struct BoardSnapshot: View {
    var position: Position
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("ChessVision").font(.title2.bold()).foregroundStyle(Color(red: 0.20, green: 0.44, blue: 0.34))
                Spacer(); TurnBadge(side: position.turn)
            }
            BoardView(position: position).frame(width: 512, height: 512)
        }.padding(24).frame(width: 560).background(.white)
    }
}

private struct PositionShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
