# ChessVision for iPhone

Native SwiftUI application for photographing a **physical** chessboard, reviewing a reconstructed position, and analyzing it locally with Stockfish. No account, server, subscription, or photograph upload. Camera photos live in memory and are discarded when the app exits.

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
5. Check the crop and all pieces. Rotate the recognized board if needed; orange squares must be resolved. Tap a square to replace/remove a piece or move it to another square. Confirm whose turn it is and explicitly configure any castling/en passant rights.
6. Tap **Analyze with Stockfish**. Results include White-perspective evaluation, UCI best move, three candidate lines where available, playback, return to original, stop, and reanalysis.

## Tests

On a Mac:

```sh
swift test
bash Scripts/test-engine.sh
bash Scripts/test-mac.sh
```

`test-mac.sh` selects an available iPhone simulator automatically; override it with `SIMULATOR_ID=<UDID>`. It builds and runs real hosted tests, and writes an `.xcresult` under `.build`. A real iPhone is still required for camera and representative recognition acceptance testing. CI is provided in `.github/workflows/macos.yml`; it runs only after you push or trigger it, and no CI run has been claimed here.

Optional model reproducibility and photo benchmark instructions: [Recognition](Documentation/RECOGNITION.md). The app itself needs none of those tools.

## Structure

- `ChessVision/Camera`: photo capture, permission handling, orientation normalization.
- `ChessVision/Recognition`: Vision rectangle candidates, perspective correction, grid refinement, per-square Core ML classifier and uncertainty.
- `ChessVision/Core`: FEN, state validation, engine-line parsing, variation playback, grid fitting; also a portable Swift package.
- `ChessVision/Engine` and `Engine`: asynchronous Swift controller and in-process C++ UCI bridge.
- `ChessVision/UI`: capture, correction, game-state controls, analysis and variation playback.
- `Vendor`: pinned upstream Stockfish source and original classifier, with licenses.
- `Tests`: portable logic tests and native integration/parity tests.

## Licensing and distribution

This combined application is **AGPL-3.0-or-later**, reflecting the LiveChess2FEN model's upstream license. Stockfish source remains **GPL-3.0-or-later**. Preserve all notices and provide the complete corresponding source, model source artifact and conversion/build instructions when conveying binaries. See [third-party details](Documentation/THIRD_PARTY.md).

**Do not publish this build as a finished product.** It needs successful Xcode/device validation and improved recognition. App Store terms, signing/DRM and GPL/AGPL compatibility require a distribution review before submission; including license files alone does not establish App Store compliance. Nothing has been published, uploaded to a store, or pushed to GitHub.
