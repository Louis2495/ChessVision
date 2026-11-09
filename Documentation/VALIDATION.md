# Validation status

Prepared in a Debian 13 x86-64 cloud environment. Source is configured for Xcode 16+, Swift 5 language mode, iOS 17+. No Xcode, iOS SDK, iOS Simulator, signing identity or physical iPhone is available in this environment.

## Executed successfully here

- Portable Swift module compiled with official Swift 6.0.3; **23 XCTest tests passed, zero failed**. Covers FEN round trips, malformed input, king/pawn/promotion/castling/en passant consistency, attack detection, counters, engine score perspective/mate parsing, castling/en passant/promotion playback, synthetic grid refinement and rejection of blank/malformed candidates.
- Real vendored Stockfish and the application's exact C++ bridge compiled using GCC 14/C++14. Smoke checks exercise UCI/ready handshake, analysis, MultiPV output, no-legal-move handling, cancellation, and starting-position **perft(3) = 8,902**.
- Original ONNX model inference tested on public physical-board photos. Bundled ensemble: **287/320 correct squares (89.6875%), 0/5 exact positions**, 76 uncertain squares and zero confident errors on this small sample. Manual corners, no Apple detector. See the report and Recognition documentation for limitations.
- ONNX versus Torch maximum absolute difference on the conversion input: less than 0.000001; traced four-rotation inference matched the ONNX ensemble within the conversion script's 0.0001 absolute / 0.001 relative tolerance.
- Core ML conversion produced a bundled MLProgram package. **Core ML execution was not possible here.** Linux conversion warnings about missing Apple's runtime are expected and do not validate the converted model's output.
- Swift parser accepted the iOS UI/camera/recognition/controller and native/UI test sources. This is a syntax check, not an SDK type check or an iOS compilation.
- Xcode project parsed with an OpenStep project parser. Structural validation checks source/resource existence, model manifest, plist files, target/scheme references and source membership.

## Prepared, but not executed

`bash Scripts/test-mac.sh` runs portable tests and Xcode simulator tests using an available iPhone simulator. Hosted tests include model labels/input shape, real Core ML inference, three real-photo-square ONNX parity comparisons, embedded-engine analysis and cancellation. The UI test covers launch, example editor, game-state confirmation, analysis and variation playback. CI configuration is provided but has not been run or uploaded.

**A successful iOS build, launch and runtime result are unverified.** No simulator screenshot or camera result is claimed. Xcode may expose SDK/compiler issues that Linux syntax and logic tests cannot find.

## Acceptance work requiring a Mac and iPhone

1. Run `Scripts/test-mac.sh`; inspect the fresh `.xcresult` and resolve any SDK/compiler/runtime failures before treating this as a verified build.
2. Install on a real iPhone and verify camera permission/grant/denial, EXIF orientation, portrait guidance, memory use, retake/retry and navigation. Check the detected crop against the physical board.
3. Collect a held-out labeled set with consent: starting positions, crowded middlegames, sparse endings, multiple physical designs, lighting and shadows. Count all 64 squares and exact positions. Keep rejected detections, uncertain predictions and confident errors separate.
4. Improve detector/model calibration and retrain or replace the classifier if required. Current sample accuracy fails the reliable automatic-reconstruction goal. Uncertainty review is necessary, and confident errors can occur on unseen boards.
5. Measure full-board latency, battery/thermal behavior, cancellation and repeated analysis on device; test both colors, castling, promotion and en passant playback against the photograph and reference engine output.
6. Review release licensing, corresponding-source delivery and privacy declarations before any distribution.

The app implementation, portable tests, engine bridge and project files are prepared. The full physical-camera-to-correct-position workflow is **not yet accepted or production-ready**.
