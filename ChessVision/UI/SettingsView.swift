import SwiftUI
import AVFoundation

@MainActor final class ClassicalMusic {
    static let shared = ClassicalMusic()
    private var player: AVAudioPlayer?
    func setEnabled(_ enabled: Bool) {
        if !enabled { player?.stop(); player = nil; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation); return }
        guard player == nil, let url = Bundle.main.url(forResource: "ClassicalPrelude", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let audio = try AVAudioPlayer(contentsOf: url); audio.numberOfLoops = -1; audio.volume = 0.3
            audio.prepareToPlay(); audio.play(); player = audio
        } catch { player = nil }
    }
}

struct SettingsButton: View {
    @State private var showing = false
    var body: some View {
        Button { showing = true } label: { Image(systemName: "gearshape") }
            .accessibilityLabel("Settings")
            .sheet(isPresented: $showing) { NavigationStack { SettingsView() } }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("theme") private var theme = "Forest"
    @AppStorage("background") private var background = "Default"
    @AppStorage("boardStyle") private var board = "Classic"
    @AppStorage("pieceStyle") private var pieces = "Illustrated"
    @AppStorage("classicalMusic") private var music = false
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Display", selection: $appearance) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } }
                Picker("Theme", selection: $theme) { ForEach(["Forest", "Ocean", "Plum"], id: \.self) { Text($0) } }
                Picker("Background", selection: $background) { ForEach(["Default", "Warm", "Cool"], id: \.self) { Text($0) } }
            }
            Section("Chessboard") {
                Picker("Board", selection: $board) { ForEach(["Classic", "Walnut", "Slate"], id: \.self) { Text($0) } }
                Picker("Pieces", selection: $pieces) { ForEach(["Illustrated", "Traditional"], id: \.self) { Text($0) } }
                BoardView(position: .initial).padding(.vertical, 8)
            }
            Section("Sound") {
                Toggle("Classical music", isOn: $music)
                Text("An original classical-style piano prelude. Music pauses when you leave the app.").font(.caption).foregroundStyle(.secondary)
            }
            Section { NavigationLink("Privacy & licenses") { AppInfoView() } }
        }.modifier(AppSurface()).navigationTitle("Settings").toolbar { Button("Done") { dismiss() } }
    }
}

struct AppAppearance: ViewModifier {
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("theme") private var theme = "Forest"
    @AppStorage("background") private var background = "Default"
    @AppStorage("classicalMusic") private var music = false
    @Environment(\.scenePhase) private var phase
    private var tint: Color { theme == "Ocean" ? .blue : theme == "Plum" ? .purple : Color(red: 0.20, green: 0.44, blue: 0.34) }
    func body(content: Content) -> some View {
        content.tint(tint).preferredColorScheme(appearance == "Light" ? .light : appearance == "Dark" ? .dark : nil)
            .background(background == "Warm" ? Color.brown.opacity(0.10) : background == "Cool" ? Color.blue.opacity(0.08) : Color.clear)
            .onAppear { ClassicalMusic.shared.setEnabled(music && phase == .active) }
            .onChange(of: music) { _, enabled in ClassicalMusic.shared.setEnabled(enabled && phase == .active) }
            .onChange(of: phase) { _, value in ClassicalMusic.shared.setEnabled(music && value == .active) }
    }
}

struct AppSurface: ViewModifier {
    @AppStorage("background") private var background = "Default"
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Color(uiColor: .systemBackground)
                    if background == "Warm" { Color.brown.opacity(0.12) }
                    if background == "Cool" { Color.blue.opacity(0.10) }
                }.ignoresSafeArea()
            }
    }
}
