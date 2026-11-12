import SwiftUI

/// A quiet, consistent surface for related controls across tabs.
struct AppCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background { ThemeCardBackground().clipShape(RoundedRectangle(cornerRadius: 18)) }
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
    }
}

