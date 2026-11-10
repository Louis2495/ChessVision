import SwiftUI
@main struct ChessVisionApp: App {
    @UIApplicationDelegateAdaptor(ChessVisionDelegate.self) private var delegate
    var body: some Scene { WindowGroup { AppTabs() } }
}
