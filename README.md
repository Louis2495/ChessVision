# ChessVision for iPhone

Native SwiftUI application for photographing a **physical** chessboard, reviewing a reconstructed position, and analyzing it locally with Stockfish. No account, server, subscription, or photograph upload. Camera photos live in memory and are discarded when the app exits. Sharing a rendered board image or FEN is an explicit system-share action.

**Status:** implementation prepared for Xcode; the iOS target has not been compiled or run in this Linux environment. Recognition is experimental and does not yet meet the reliable, fully automatic acceptance criterion. See [validation](Documentation/VALIDATION.md) for actual results and remaining checks. Do not interpret a checked-in model as evidence of reliable recognition.

## Open and run on a Mac

1. Install **Xcode 16 or newer**, launch it once, and install an iOS Simulator runtime when prompted. Deployment target: **iOS 17.0**, iPhone, portrait. No Homebrew, CocoaPods, XcodeGen, Python, model downloads, or Swift package dependencies are needed to build the app.
2. Open **`ChessVision.xcodeproj`** (not `Package.swift`, which contains only the portable logic tests).
3. Select the **ChessVision** scheme and an available iPhone Simulator. Press **⌘R**. The example editor and local analysis work without a camera; Simulator camera capture is deliberately unavailable.
4. Press **⌘U** for the hosted unit/integration tests, including the bundled model and Stockfish bridge. These Mac-only tests have been written but not executed here.

The Xcode project, shared scheme, bundled Core ML model, engine source, camera permission, privacy manifest, and licenses are checked in. Model code generation is handled by Xcode's Core ML compiler. The C++ target uses C++14 and portable 64-bit settings for both Apple Silicon iPhones and simulators.

## Install on your iPhone

1. Connect the iPhone to the Mac and trust the computer. Enable **Settings → Privacy & Security → Developer Mode** if iOS asks.
2. In Xcode select the app target → **Signing & Capabilities**, choose your own Development Team, and change `com.chessvision.app` to a unique bundle identifier if needed. A personal Apple ID can be used for local development, subject to Apple's provisioning limits. No signing credentials are stored in this repository.
3. Select your connected iPhone and press **⌘R**. Grant camera access.
4. Tap **Take Pic of Board**, hold the phone directly overhead, and include all four corners with a small margin. Keep White's home rank nearest you. Avoid glare and hard shadows.
5. Choose whose turn it is and configure castling/en passant rights if relevant. Orange highlights are optional correction hints; they do not block analysis. Tap a square to replace/remove a piece or move it to another square. Capture with White at the bottom: the rotate-board control has been removed.
6. Tap **Analyze with Stockfish**. It deepens continuously, with standard algebraic notation (`Nf6`, `exd5`, `O-O`), three candidate tabs and a White/Black move table. Tap a table move or play a legal move on the board; evaluation refreshes automatically. The bar at the board’s right shows the balance, and Turn shows a square in the moving side’s color. Search pauses when you leave the screen or app.
7. **Share position** offers FEN, a board image, or both, including the current analysis/playback position. There is no fixed-time setting, Analyze again button, or mandatory review confirmation. Invalid chess positions still need correction before engine use.

## Tests

On a Mac:

```sh
swift test
bash Scripts/test-engine.sh
bash Scripts/test-controller.sh
bash Scripts/test-mac.sh
```

`test-controller.sh` exercises the actual Swift engine controller against the real C++ engine; on Linux only its Combine observation layer is replaced by a minimal test shim (not shipped in the app).

`test-mac.sh` selects an available iPhone simulator automatically; override it with `SIMULATOR_ID=<UDID>`. It builds and runs real hosted tests, and writes an `.xcresult` under `.build`. A real iPhone is still required for camera and representative recognition acceptance testing. CI is provided in `.github/workflows/macos.yml`; it runs only after you push or trigger it, and no CI run has been claimed here.

Optional model reproducibility and photo benchmark instructions: [Recognition](Documentation/RECOGNITION.md). The app itself needs none of those tools.

## Structure

- `ChessVision/Camera`: photo capture, permission handling, orientation normalization.
- `ChessVision/Recognition`: Vision rectangle candidates, perspective correction, grid refinement, per-square Core ML classifier and uncertainty.
- `ChessVision/Core`: FEN, state validation, legal moves, SAN, engine scores, recognition fusion and grid fitting; also a portable Swift package.
- `ChessVision/Engine` and `Engine`: asynchronous Swift controller and in-process C++ UCI bridge.
- `ChessVision/UI`: capture, correction, game-state controls, analysis and variation playback.
- `Vendor`: pinned Stockfish source, both original classifiers and filled CBurnett vector artwork, with sources/licenses.
- `Tests`: portable logic tests and native integration/parity tests.

## Licensing and distribution

This combined application is **AGPL-3.0-or-later**, reflecting the LiveChess2FEN model's upstream license. Stockfish source remains **GPL-3.0-or-later**. Preserve all notices and provide the complete corresponding source, model source artifact and conversion/build instructions when conveying binaries. See [third-party details](Documentation/THIRD_PARTY.md).

**Do not publish this build as a finished product.** It needs successful Xcode/device validation and improved recognition. App Store terms, signing/DRM and GPL/AGPL compatibility require a distribution review before submission; including license files alone does not establish App Store compliance. Nothing has been published, uploaded to a store, or pushed to GitHub.
