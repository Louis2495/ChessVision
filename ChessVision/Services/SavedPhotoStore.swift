import SwiftUI
import ImageIO

struct SavedBoardPhoto: Identifiable {
    let url: URL
    let date: Date
    var id: String { url.lastPathComponent }
}

@MainActor final class SavedPhotoStore: ObservableObject {
    @Published private(set) var photos: [SavedBoardPhoto] = []
    @Published var error: String?
    private let directory: URL
    init(directory override: URL? = nil) {
        directory = override ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChessVision/BoardPhotos", isDirectory: true)
        refresh()
    }
    func refresh() {
        do {
            guard FileManager.default.fileExists(atPath: directory.path) else { photos = []; return }
            photos = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "jpg" }.map { SavedBoardPhoto(url: $0, date: (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) }
                .sorted { $0.date > $1.date }
        } catch { self.error = error.localizedDescription }
    }
    @discardableResult func save(_ image: UIImage) -> Bool {
        do {
            guard let data = image.jpegData(compressionQuality: 0.92) else { throw ChessError.invalid("This photograph could not be saved.") }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent(UUID().uuidString + ".jpg"), options: [.atomic, .completeFileProtectionUnlessOpen])
            error = nil; refresh(); return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func delete(_ photo: SavedBoardPhoto) {
        do { try FileManager.default.removeItem(at: photo.url); error = nil; refresh() }
        catch { self.error = error.localizedDescription }
    }
    func image(_ photo: SavedBoardPhoto) -> UIImage? { UIImage(contentsOfFile: photo.url.path) }
}

struct SavedPhotosView: View {
    @ObservedObject var store: SavedPhotoStore
    let analyze: (UIImage) -> Void
    var body: some View {
        List {
            if store.photos.isEmpty { Text("Save board photos during your game, then analyze them here.").foregroundStyle(.secondary) }
            ForEach(store.photos) { photo in
                Button {
                    if let image = store.image(photo) { analyze(image) }
                    else { store.error = "This saved photograph could not be opened." }
                } label: {
                    HStack(spacing: 16) {
                        SavedPhotoThumbnail(url: photo.url).frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading) { Text(photo.date, style: .date); Text(photo.date, style: .time).font(.caption).foregroundStyle(.secondary); Text("Analyze").font(.caption).foregroundStyle(.tint) }
                    }
                }.swipeActions { Button("Delete", role: .destructive) { store.delete(photo) } }
            }.listRowBackground(ThemeCardBackground())
            if let error = store.error { Text(error).foregroundStyle(.red) }
        }.modifier(AppSurface()).navigationTitle("Saved photos")
    }
}

private struct SavedPhotoThumbnail: View {
    let url: URL
    @State private var image: UIImage?
    var body: some View {
        Group { if let image { Image(uiImage: image).resizable().scaledToFill() } else { Color.gray.opacity(0.15) } }
            .task(id: url) {
                // Decode a small thumbnail instead of retaining full-size captures in list rows.
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 180, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return }
                image = UIImage(cgImage: cg)
            }
    }
}
