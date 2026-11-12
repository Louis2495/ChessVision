import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

struct SharePositionButton: View {
    var position: Position
    var game: [Position] = []
    var title = "Share position"
    @State private var items: [Any] = []
    @State private var sharing = false
    @State private var exporting = false
    @State private var exportTask: Task<Void, Never>?
    @State private var exportedGIF: URL?
    @State private var message: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                if game.count > 1 { Button("Share GIF", systemImage: "film") { shareGIF() } }
                Button("Share FEN", systemImage: "text.alignleft") { share(image: false, fen: true) }
                Button("Share board image", systemImage: "photo") { share(image: true, fen: false) }
            } label: { Label(title, systemImage: "square.and.arrow.up") }
            .disabled(exporting)
            if exporting {
                HStack { ProgressView("Creating GIF…"); Button("Cancel") { exportTask?.cancel() } }
            }
        }
        .sheet(isPresented: $sharing, onDismiss: removeGIF) { PositionShareSheet(items: items) }
        .onDisappear { exportTask?.cancel() }
        .alert("Unable to share", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
    }
    @MainActor private func removeGIF() {
        if let exportedGIF { try? FileManager.default.removeItem(at: exportedGIF) }
        exportedGIF = nil
    }
    @MainActor private func shareGIF() {
        exportTask?.cancel(); removeGIF(); exporting = true
        let frames = game
        exportTask = Task { @MainActor in
            defer { exporting = false }
            do {
                let url = try await BoardImageExporter.gif(for: frames)
                guard !Task.isCancelled else { try? FileManager.default.removeItem(at: url); return }
                exportedGIF = url; items = [url]; sharing = true
            } catch is CancellationError { }
            catch { message = error.localizedDescription }
        }
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
    static func image(for position: Position, scale: CGFloat = 2) -> UIImage? {
        let renderer = ImageRenderer(content: BoardSnapshot(position: position).environment(\.colorScheme, .light))
        renderer.scale = scale
        return renderer.uiImage
    }
    static func gif(for positions: [Position]) async throws -> URL {
        guard positions.count > 1 else { throw ChessError.invalid("Play a move before sharing a game GIF.") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("NovaChess-\(UUID().uuidString).gif")
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: url) } }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, positions.count, nil) else {
            throw ChessError.invalid("The GIF file could not be created.")
        }
        let loop: [String: Any] = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]
        CGImageDestinationSetProperties(destination, loop as CFDictionary)
        for (index, position) in positions.enumerated() {
            try Task.checkCancellation()
            try autoreleasepool {
                guard let image = image(for: position, scale: 0.75)?.cgImage else { throw ChessError.invalid("A GIF frame could not be rendered.") }
                let delay = index == 0 || index == positions.count - 1 ? 1.4 : 0.7
                let properties: [String: Any] = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: delay, kCGImagePropertyGIFUnclampedDelayTime as String: delay]]
                CGImageDestinationAddImage(destination, image, properties as CFDictionary)
            }
            await Task.yield()
        }
        try Task.checkCancellation()
        guard CGImageDestinationFinalize(destination) else { throw ChessError.invalid("The GIF could not be finished. Please try a shorter game.") }
        completed = true
        return url
    }

}

private struct BoardSnapshot: View {
    @AppStorage("theme") private var theme = "Forest"
    var position: Position
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("NovaChess").font(.title2.bold()).foregroundStyle(Color(hex: (AppTheme(rawValue: theme) ?? .forest).hex))
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
