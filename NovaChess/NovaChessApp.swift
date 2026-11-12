import SwiftUI
@main struct NovaChessApp: App {
    @UIApplicationDelegateAdaptor(NovaChessDelegate.self) private var delegate
    var body: some Scene { WindowGroup { AppTabs() } }
}
