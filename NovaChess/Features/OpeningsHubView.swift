import SwiftUI

struct OpeningsHubView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    NavigationLink { RepertoireView() } label: {
                        tile("Your Repertoire", detail: "Build and train your opening lines", icon: "books.vertical")
                    }.accessibilityLabel("Your Repertoire")
                    NavigationLink { OpeningTrainingView() } label: {
                        tile("Train an opening", detail: "Practice a chosen opening against the computer", icon: "square.grid.3x3.fill")
                    }.accessibilityLabel("Train an opening")
                    NavigationLink { OpeningExplorerView() } label: {
                        tile("Research", detail: "Explore an account", icon: "magnifyingglass")
                    }.accessibilityLabel("Research")
                }.padding()
            }.modifier(AppSurface()).navigationTitle("Openings").toolbar { SettingsButton() }
        }
    }
    private func tile(_ title: String, detail: String, icon: String) -> some View {
        AppCard {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon).font(.system(size: 26, weight: .medium))
                    .frame(width: 54, height: 54).background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.title2.bold()).foregroundStyle(.primary)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary).padding(.top, 8)
            }.padding(.vertical, 12)
        }.contentShape(RoundedRectangle(cornerRadius: 18))
    }
}
