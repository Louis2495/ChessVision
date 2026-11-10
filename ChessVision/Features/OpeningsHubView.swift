import SwiftUI

struct OpeningsHubView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    NavigationLink { RepertoireView() } label: {
                        tile("Your Repertoire", detail: "Build and train your opening lines", icon: "books.vertical")
                    }
                    NavigationLink { OpeningExplorerView() } label: {
                        tile("Research", detail: "Explore public Chess.com and Lichess games", icon: "magnifyingglass")
                    }
                }.padding()
            }.modifier(AppSurface()).navigationTitle("Openings").toolbar { SettingsButton() }
        }
    }
    private func tile(_ title: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon).font(.system(size: 32))
            Text(title).font(.title2.bold())
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 155, alignment: .leading).padding(24)
            .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.accentColor.opacity(0.16)))
            .contentShape(RoundedRectangle(cornerRadius: 22))
    }
}
