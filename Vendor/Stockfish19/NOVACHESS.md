# Official Stockfish 19

Upstream: https://github.com/official-stockfish/Stockfish
Release: sf_19 (latest official release verified 2026-11-10)
Commit: edb0d9db6731067ec50ce619ff372b463bc4dd5d
Source archive: https://codeload.github.com/official-stockfish/Stockfish/tar.gz/refs/tags/sf_19
License: GPL-3.0-or-later; Copying.txt and AUTHORS preserved. Upstream sources are unmodified (76 source-tree files checked byte-for-byte against the release archive).

NovaChess supplies Engine/ModernStockfishBridge.cpp and a forced ModernConfig.h, which isolates the C++ namespace as CVStockfish19 to coexist with Fairy-Stockfish. Engine/ModernSources contains one-line wrappers with unique basenames so Xcode cannot collide with Fairy-Stockfish object names. C++20, NEON on ARM64 and SSE2 on x86-64 are enabled. The network is an external **bundled resource**, not disabled evaluation: NNUE_EMBEDDING_OFF only prevents assembler embedding. Official SF19 always evaluates with NNUE. No weights are downloaded by the app.

Model: nn-1a298aa575a0.nnue, 98,511,183 bytes.
SHA-256: 1a298aa575a085434d29027978dc36867fe9c5bcea9376654b7a8eba1e52dfc2
Official pointer: https://raw.githubusercontent.com/official-stockfish/networks/master/nn-1a298aa575a0.nnue
The resource was exported using `export_net` from the official sf_19 Linux x86-64 universal binary and verified against that pointer's full SHA-256. It is the default model named by this release's evaluate.h, not a substitute or reduced network. Model and engine retain the upstream GPL license.

The bridge uses the upstream Engine API with callbacks; it does not redirect process iostreams. Its network-verification callback throws on upstream ERROR before upstream can call exit(), allowing Swift to display a failure without killing the app. Missing/corrupt network tests cover that path. Standard analysis and review fail visibly if the model cannot load; they never silently fall back to classical evaluation. Fairy-Stockfish remains responsible for native variant legality, variant searches, and low-rated standard opponents below official Stockfish's 1320 Elo calibration range.
