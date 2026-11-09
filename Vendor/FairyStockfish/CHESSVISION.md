# Embedded engine provenance

Upstream: https://github.com/fairy-stockfish/Fairy-Stockfish
Commit: 4e3d0147d5b8da1b780a29f0b3e1d24311d028fa (pinned master snapshot)
License: GPL-3.0-or-later; original Copying.txt and AUTHORS accompany the sources.

Upstream src files are unmodified. ChessVision supplies Engine/StockfishBridge.cpp instead of CLI main.cpp and excludes Python/JS bindings. C++17, IS_64BIT, NO_PREFETCH, NNUE_EMBEDDING_OFF and ALLVARS are enabled. Use NNUE is explicitly disabled; no weights are downloaded. ALLVARS includes the actual compound-turn Duck rules.

The bridge registers three app-specific variants using the upstream INI parser: cvfog (nonroyal capturable kings, king capture wins); cvpawns (pawns and kings, ordinary promotions/checkmate); cvpawnrace (no kings, first pawn to last rank or capture all enemy pawns wins). Standard Atomic and Antichess use upstream rules. Board visibility for Fog of War is computed for the human side even during computer turns. The computer searches the full position.

Every saved move is validated against legal moves from the variant start. UCI ready/bestmove barriers protect variant table changes. Stalemate and checkmate results use each variant's rules. Native rule results drive UI legal targets, pockets, counters and endings.

Chess960: the bridge registers all 960 Scharnagl starts as cv9600…cv960959. Game saves retain their chosen index. Native position setup and computer UCI both enable Chess960 castling encoding (king-to-rook); ordinary Analysis resets that option. All starts and sampled castling histories are independently checked in Scripts/test-chess960.py.
