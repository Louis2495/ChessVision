import SwiftUI
import UIKit

@MainActor enum OrientationPolicy {
    static var mask: UIInterfaceOrientationMask = .portrait
    static func set(_ mask: UIInterfaceOrientationMask) {
        self.mask = mask
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            var controller = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            controller?.setNeedsUpdateOfSupportedInterfaceOrientations()
            while let presented = controller?.presentedViewController { controller = presented }
            controller?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        }
    }
}
@MainActor final class ChessVisionDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { OrientationPolicy.mask }
}
