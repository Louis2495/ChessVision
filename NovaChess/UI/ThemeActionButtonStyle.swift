import SwiftUI

/// Use the solid theme color instead of the brightened dark-mode link tint.
struct ThemeActionButtonStyle: ButtonStyle {
    var backgroundHex: UInt32?
    init(backgroundHex: UInt32? = nil) { self.backgroundHex = backgroundHex }
    @AppStorage("theme") private var theme = "Forest"
    @Environment(\.isEnabled) private var enabled
    private var hex: UInt32 { backgroundHex ?? (AppTheme(rawValue: theme) ?? .forest).hex }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(Color(hex: InterfaceContrast.foreground(on: hex)))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(Color(hex: hex), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(!enabled ? 0.45 : configuration.isPressed ? 0.78 : 1)
    }
}
