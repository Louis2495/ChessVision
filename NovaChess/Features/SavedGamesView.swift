import SwiftUI

struct SavedGamesView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var name = ""
    @State private var creating = false
    @State private var editingFolder: UUID?
    var body: some View {
        List {
            games(in: nil)
            ForEach(library.state.folders) { folder in
                Section {
                    games(in: folder.id)
                    Button("Delete folder", role: .destructive) {
                        for i in library.state.savedGames.indices where library.state.savedGames[i].folderID == folder.id { library.state.savedGames[i].folderID = nil }
                        library.state.folders.removeAll { $0.id == folder.id }
                    }
                } header: {
                    HStack {
                        Text(folder.name); Spacer()
                        Button("Rename") { editingFolder = folder.id; name = folder.name; creating = true }.font(.caption)
                    }
                }
            }
            if library.state.savedGames.isEmpty { Text("Save a game from History or Record game in the camera menu.").foregroundStyle(.secondary) }
        }.navigationTitle("Saved games").modifier(AppSurface())
        .toolbar { Button("New folder", systemImage: "folder.badge.plus") { editingFolder = nil; name = ""; creating = true } }
        .alert(editingFolder == nil ? "New folder" : "Rename folder", isPresented: $creating) {
            TextField("Folder name", text: $name)
            Button("Save") {
                let value = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
                if !value.isEmpty {
                    if let editingFolder, let i = library.state.folders.firstIndex(where: { $0.id == editingFolder }) { library.state.folders[i].name = value }
                    else { library.state.folders.append(GameFolder(name: value)) }
                }
                name = ""; editingFolder = nil
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    @ViewBuilder private func games(in folder: UUID?) -> some View {
        ForEach(library.state.savedGames.filter { $0.folderID == folder }) { game in
            NavigationLink { SavedGameReplay(game: game) } label: {
                VStack(alignment: .leading) { Text(game.title); Text(game.date, style: .date).font(.caption).foregroundStyle(.secondary) }
            }.contextMenu {
                Menu("Move to folder") {
                    Button("Unfiled") { move(game.id, to: nil) }
                    ForEach(library.state.folders) { f in Button(f.name) { move(game.id, to: f.id) } }
                }
                Button("Delete game", role: .destructive) { library.state.savedGames.removeAll { $0.id == game.id } }
            }
        }
    }
    private func move(_ id: UUID, to folder: UUID?) { if let i = library.state.savedGames.firstIndex(where: { $0.id == id }) { library.state.savedGames[i].folderID = folder } }
}
private struct SavedGameReplay: View {
    var game: SavedBoardGame
    @State private var cursor = 0
    @State private var variation = 0
    private var positions: [String] { if let lines = game.variations, lines.indices.contains(variation) { return lines[variation].positions }; return game.positions }
    private var notation: [String] { if let lines = game.variations, lines.indices.contains(variation) { return lines[variation].notation }; return game.notation }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let lines = game.variations, lines.count > 1 {
                    Picker("Variation", selection: $variation) { ForEach(lines.indices, id: \.self) { i in Text(lines[i].title).tag(i) } }.pickerStyle(.menu)
                }
                if positions.indices.contains(cursor), let snapshot = try? VariantSnapshot.parse("fen\t" + positions[cursor] + "\nstatus\tongoing") { BoardView(position: snapshot.board, duckSquare: snapshot.duckSquare).aspectRatio(1, contentMode: .fit) }
                HStack {
                    Button("Previous", systemImage: "chevron.left") { cursor = max(0, cursor - 1) }.disabled(cursor == 0)
                    Spacer(); Text("\(String(GameStatistics.moveCount(plies: cursor))) / \(String(GameStatistics.moveCount(plies: positions.count - 1)))"); Spacer()
                    Button("Next", systemImage: "chevron.right") { cursor = min(positions.count - 1, cursor + 1) }.disabled(cursor + 1 >= positions.count)
                }
                Text(notation.enumerated().map { i, san in (i % 2 == 0 ? "\(i / 2 + 1). " : "") + san }.joined(separator: " "))
            }.padding()
        }.navigationTitle(game.title).modifier(AppSurface()).onChange(of: variation) { _, _ in cursor = 0 }
    }
}
