import SwiftUI

@MainActor struct AppTabs: View {
    @StateObject private var library = LibraryStore()
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Home", systemImage: "house") }
            ContentView().tabItem { Label("Analysis", systemImage: "square.grid.3x3") }
            ComputerPlayView().tabItem { Label("Play", systemImage: "desktopcomputer") }
            NavigationStack { PuzzleTrainingView() }.tabItem { Label("Puzzles", systemImage: "puzzlepiece.extension") }
            OpeningsHubView().tabItem { Label("Openings", systemImage: "books.vertical") }
        }
        .modifier(AppAppearance())
        .environmentObject(library)
        .alert("Your local library", isPresented: Binding(get: { library.notice != nil }, set: { if !$0 { library.notice = nil } })) { Button("OK") { library.notice = nil } } message: { Text(library.notice ?? "") }
    }
}
