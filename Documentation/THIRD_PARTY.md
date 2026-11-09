# Third-party source and distribution

- **Stockfish 11**: official `sf_11` tag, commit `c3483fa9a7d7c0ffa9fcc32b467ca844cfb63790`; https://github.com/official-stockfish/Stockfish. Original source, AUTHORS and GPL-3.0-or-later license are in `Vendor/Stockfish`. The source is unmodified; the application excludes the CLI `main.cpp` and substitutes `Engine/StockfishBridge.cpp`. C++14 avoids an ambiguity with modern `std::clamp`. Portable 64-bit settings avoid x86-specific intrinsics on iPhone. Stockfish 11 is an older classical engine, chosen for a self-contained integration with no NNUE network download; it is not the latest Stockfish and has lower playing strength than current releases. No Syzygy files are included or requested.
- **LiveChess2FEN**: Copyright (c) 2020 David Mallasén Quintana. https://github.com/davidmallasen/LiveChess2FEN. Repository license: AGPL-3.0-or-later. Original license/notices, training scripts, both MobileNetV2 and DenseNet201 ONNX graphs/weights, release URL and SHA-256 are in `Vendor/LiveChess2FEN`. `Scripts/convert-model.py` records the conversion and the four-view inference modification. Public test-photo crops are derived from its v0.1.0 TestImages release. Its published notices include MIT attributions for upstream components; those notices are preserved even though their board-detection code is not used in the app.
- **Model conversion tools**: PyTorch (BSD-style), torchvision (BSD), ONNX (Apache-2.0), onnx2torch (Apache-2.0), Core ML Tools (BSD), NumPy (BSD), Pillow (HPND), ONNX Runtime (MIT), OpenCV (Apache-2.0). These are optional development tools and are not bundled in the iPhone binary. Install through their normal package distributions, preserving their notices.
- Apple frameworks come from the user's Xcode/iOS SDK under Apple's terms. No Apple SDK is redistributed in this repository.
- The app icon uses a rendered Unicode knight from DejaVu Sans; the font is not embedded. DejaVu font license/attribution accompanies `Vendor/DejaVu`.

The combined app is offered under AGPL-3.0-or-later, with Stockfish's original GPL notices retained. GPLv3 section 13 permits the combination with AGPLv3; this does not remove the respective source and notice obligations. If conveying a binary, preserve notices and provide complete corresponding source and build/conversion instructions as required. This repository contains the application and engine source, original model and conversion/training code; training datasets are not bundled. Review the release asset/data licensing and your proposed source-delivery mechanism before distribution.

The app displays notices under Privacy & open-source licenses. The project source is stored in the user's ChessVision GitHub repository. Repository visibility/access may be private; that alone is not a public corresponding-source offer. A binary distributor must provide recipients with compliant corresponding-source delivery/access; a link to an unrelated upstream project alone is insufficient.

No App Store submission or license compatibility determination has been made. App Store signing, DRM and additional terms can conflict with GPL/AGPL redistribution requirements. Review the exact distribution plan before publishing; this project currently targets private development/device testing.

## Filled board/palette artwork

The board and correction palette use Colin M. L. Burnett's **CBurnett** set from lichess-org/lila, pinned to commit `a1590345c9c3a31b6f9c6705eefeeb7dab32a78e`. Upstream explicitly licenses these pieces GPL-2.0-or-later. This project uses the GPL-3.0-or-later option, compatible with its existing combined-license plan. Original SVGs, individual SHA-256 hashes, upstream attribution and GPL text accompany `Vendor/CBurnett`. SVGs were rendered to vector PDF without changing their shapes/colors; PDFs are checked into the asset catalog and need no runtime SVG library. CairoSVG 2.7.1 is an optional development conversion tool, not part of the app binary.

## Five-tab expansion

The active engine is now Fairy-Stockfish pinned snapshot, commit `4e3d0147d5b8da1b780a29f0b3e1d24311d028fa`, GPL-3.0-or-later. Its original complete source/AUTHORS/Copying.txt accompany `Vendor/FairyStockfish`. The previous Stockfish 11 source is retained for historical provenance but not linked. NNUE embedding/evaluation are disabled; no engine weights are downloaded. See `Vendor/FairyStockfish/CHESSVISION.md` for build details.

Lichess puzzle facts and the lichess-org/chess-openings catalog are CC0. Pinned mirror/upstream commits, source hash and estimation/sampling recipes are in `Vendor/ChessData/PROVENANCE.json`, with full CC0 text. No puzzle mirror Flask/server code is copied. python-chess 1.11.2 (GPL-3.0-or-later) is an optional generation/test tool, not an iPhone dependency.

The current binocular-knight app icon is original generated artwork, preserved in `Artwork/`. The earlier DejaVu-derived icon is no longer used; its old notice/source remain only as historical provenance. Filled playing pieces still use the attributed CBurnett set.

Public Chess.com/Lichess API calls use their supported anonymous game-export interfaces when requested by the user. Their service terms/rate limits remain applicable. No OAuth credentials, paid service, analytics SDK or remote engine is added.

Import regression PGN: a public Chess.com game recorded in sarartur/chess.com commit 4ea67f858260802f7d42fccaf679962321356a0d, tests/fixtures/vcr_cassettes/get_player_games_by_month.yaml (FabianoCaruana–viditchess, 2020-05-05). Only the public game record is included, not client code.
