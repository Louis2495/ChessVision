import SwiftUI

struct OpeningsHubView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    NavigationLink { RepertoireView() } label: {
                        tile("Your Repertoire", icon: "books.vertical")
                    }.accessibilityLabel("Your Repertoire")
                    NavigationLink { OpeningTrainingView() } label: {
                        tile("Train an opening", icon: "square.grid.3x3.fill")
                    }.accessibilityLabel("Train an opening")
                    NavigationLink { LearnOpeningsView() } label: {
                        tile("Learn", icon: "graduationcap.fill")
                    }.accessibilityLabel("Learn").accessibilityIdentifier("learn-library")
                    NavigationLink { OpeningExplorerView() } label: {
                        tile("Research", icon: "magnifyingglass")
                    }.accessibilityLabel("Research")
                }.padding()
            }.modifier(AppSurface()).navigationTitle("Learn").toolbar { SettingsButton() }
        }
    }
    private func tile(_ title: String, icon: String) -> some View {
        AppCard {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: icon).font(.system(size: 26, weight: .medium))
                    .frame(width: 54, height: 54).background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.title2.bold()).foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
            }.padding(.vertical, 24)
        }.contentShape(RoundedRectangle(cornerRadius: 18))
    }
}
