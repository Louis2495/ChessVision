import SwiftUI

@MainActor struct AppTabs: View {
    @StateObject private var library = LibraryStore()
    var body: some View {
        TabView {
            ContentView().tabItem { Label("Board", systemImage: "camera.viewfinder") }
            OpeningExplorerView().tabItem { Label("Openings", systemImage: "tree") }
            PuzzleTrainingView().tabItem { Label("Puzzles", systemImage: "puzzlepiece.extension") }
            RepertoireView().tabItem { Label("Repertoire", systemImage: "books.vertical") }
            ComputerPlayView().tabItem { Label("Play", systemImage: "desktopcomputer") }
        }
        .environmentObject(library)
        .alert("Your local library", isPresented: Binding(get: { library.notice != nil }, set: { if !$0 { library.notice = nil } })) { Button("OK") { library.notice = nil } } message: { Text(library.notice ?? "") }
    }
}
