import SwiftUI
import PhotosUI
import ImageIO

struct ProfilePortrait: View {
    let profile: PlayerProfile
    var body: some View {
        Group {
            if let data = profile.avatarData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(.secondary) }
        }.frame(width: 48, height: 48).clipShape(Circle()).accessibilityLabel("Profile picture for " + profile.username)
    }
}
struct ProfileEditorView: View {
    @ObservedObject private var store = SocialStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var country = ""
    @State private var avatar: Data?
    @State private var photo: PhotosPickerItem?
    @State private var loading = false
    @State private var error: String?
    private var countries: [String] { Countries.codes.sorted { Countries.name($0) < Countries.name($1) } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile picture") {
                    if let avatar, let image = UIImage(data: avatar) { Image(uiImage: image).resizable().scaledToFill().frame(width: 96, height: 96).clipShape(Circle()) }
                    PhotosPicker("Choose picture", selection: $photo, matching: .images).disabled(loading)
                    Button("Remove picture", role: .destructive) { avatar = nil }.disabled(loading)
                }
                Section("Country") {
                    Text("Your country and picture are visible on your public profile.").font(.caption).foregroundStyle(.secondary)
                    Picker("Country", selection: $country) {
                        Text("Not specified").tag("")
                        ForEach(countries, id: \.self) { code in Text(Countries.name(code)).tag(code) }
                    }
                }
                if loading || store.busy { ProgressView() }
                if let error = error ?? store.error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Edit profile").modifier(AppSurface())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await store.updateProfile(country: country, avatar: avatar); if store.error == nil { dismiss() } } }.disabled(loading || store.busy)
                }
            }
            .onAppear { country = store.profile?.countryCode ?? ""; avatar = store.profile?.avatarData }
            .task(id: photo) {
                guard let photo else { return }; loading = true; defer { loading = false }
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self),
                          let source = CGImageSourceCreateWithData(data as CFData, nil),
                          let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 512] as CFDictionary) else { throw ChessError.invalid("The selected picture could not be read.") }
                    let image = UIImage(cgImage: thumbnail)
                    let side = min(image.size.width, image.size.height)
                    guard side > 0 else { throw ChessError.invalid("Choose another picture.") }
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                    let rendered = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { _ in
                        let scale = 256 / side
                        image.draw(in: CGRect(x: (256-image.size.width*scale)/2, y: (256-image.size.height*scale)/2, width: image.size.width*scale, height: image.size.height*scale))
                    }
                    guard let jpeg = rendered.jpegData(compressionQuality: 0.65), jpeg.count <= 100000 else { throw ChessError.invalid("Choose a smaller picture.") }
                    try Task.checkCancellation(); avatar = jpeg; error = nil
                } catch is CancellationError {} catch { self.error = error.localizedDescription }
            }
        }
    }
}
