# Validation status — continuous analysis update

Prepared in Debian 13 x86-64. Target: Xcode 16+, Swift 5 language mode, iOS 17+. No Xcode, iOS SDK, iOS Simulator or physical iPhone is available here.

## Executed successfully

- **35 portable Swift XCTest tests passed, zero failures**, compiled with Swift 6.0.3. Includes FEN/state/playback, evaluation-bar direction and symmetry, grid refinement, recognition verification/conflict behavior, and 320 cross-language photo-prediction fusion cases.
- SAN and legal moves matched **585 reference notations across 159 positions** generated independently with python-chess 1.11.2 (fixed seed). Covers captures, ambiguity, pinned pieces, castling, en passant, promotions, checks, mate, black-first variations and fullmove numbers.
- Portable legal-move perft counts matched standard references: initial depth 3 = **8,902**, Kiwipete depth 2 = **2,039**, and the rook/pawn en passant position depth 3 = **2,812**.
- The **actual Swift EngineController plus the real embedded Stockfish bridge** passed headless integration checks for continuously increasing depth, board changes, immediate clearing of old results, latest-request-wins behavior after rapid changes, cancellation, mate/stalemate and restart. Linux uses a minimal Combine property-wrapper/observation shim; UCI transport, scheduling, controller source and C++ engine execute unchanged. This does not validate Apple's Combine or SwiftUI runtime. Run `Scripts/test-controller.sh` to reproduce; a Mac uses real Combine.
- Vendored Stockfish/C++ bridge smoke checks also passed UCI readiness, MultiPV, terminal positions, cancellation and perft(3)=8,902.
- Updated physical-photo classifier benchmark: **296/320 correct squares (92.5%), 0/5 exact positions**, all 24 errors flagged, 64 uncertain squares, 7/10 kings correct, no missed occupied squares on these examples. This uses manual corners, original ONNX models and upstream sample photos; it does not validate the user's unseen photos or Apple detection/runtime. See Recognition documentation.
- Both four-view Core ML conversions completed after ONNX/Torch numerical parity checks. The DenseNet source checksum is checked by its conversion script. Core ML execution remains unavailable here.
- All iOS Swift sources passed parser checks. Xcode OpenStep structure, shared scheme, source membership, both model manifests, 12 filled-piece vector assets and plist files passed structural validation. Syntax/structure checks are not an iOS SDK build.

## Prepared for macOS, not executed here

`bash Scripts/test-mac.sh` runs portable tests and real Xcode simulator tests. Hosted tests cover both model contracts/prediction references, continuous engine replacement/cancellation, twelve artwork assets and a rendered board-image export. The UI test covers immediate analysis without confirmation toggles, White/Black columns, live playback and sharing options. Mac CI is configured, but has not been run or uploaded.

**The updated iOS target has not been compiled, launched or visually verified in Xcode here.** No iPhone camera or device-recognition result is claimed. SDK type errors or runtime/layout issues could still be exposed by the Mac checks.

## Required follow-up validation

1. Run `Scripts/test-mac.sh` and inspect the new `.xcresult`. Run the app on simulator and check filled pieces, file/rank labels, SAN columns (including a black-to-move start), right-hand bar, turn badge and image/FEN sharing.
2. On iPhone, check camera permissions, all rectangle candidates/grid cropping, capture orientation (White at bottom), secondary-model memory/latency, cancellation and repeated captures.
3. Use the actual misrecognized king/bishop and missed-piece photographs, with consent and exact positions, as held-out regressions. Current example performance does not establish that these cases are fixed. Add physical styles, lighting, crowded positions, starting positions and sparse endings.
4. Verify automatic search refresh for legal board moves, variation cells, Previous and Return to original; change boards rapidly, then background/foreground the app. The bar is a bounded evaluation display, not a calibrated winning probability.
5. Review the existing GPL/AGPL distribution and corresponding-source obligations before publishing. No binary or source has been published or pushed.
