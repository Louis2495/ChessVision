// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ChessCore", platforms: [.iOS(.v17), .macOS(.v13)], products: [.library(name: "ChessCore", targets: ["ChessCore"])], targets: [.target(name: "ChessCore", path: "ChessVision/Core"), .testTarget(name: "ChessCoreTests", dependencies: ["ChessCore"], path: "Tests/Core")])
