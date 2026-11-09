# Embedded engine provenance

Upstream: https://github.com/fairy-stockfish/Fairy-Stockfish
Tag: fairy_sf_14
Commit: f3e6969d11d1bec17eba26e7ae0e629ad4af71dd
License: GPL-3.0-or-later; original COPYING/AUTHORS accompany the sources.

Upstream engine sources are unmodified. ChessVision substitutes its C bridge for the CLI main entry point and excludes Python/JS bindings. The app compiles C++17 with IS_64BIT, NO_PREFETCH and NNUE_EMBEDDING_OFF, and explicitly turns Use NNUE off. No NNUE file or engine download is needed. Classical evaluation supports chess, three-check, king of the hill, horde and crazyhouse locally. This is a pinned older Fairy-Stockfish release, not the current Stockfish engine.

The bridge adds legal-move/SAN/FEN queries from a validated start-position move history. It normalizes pawn drops to @square SAN and marks immediate variant wins with #. Swift waits for the engine's variant-ready barrier before querying rules; active rule tables are not changed during a search. The original Stockfish 11 sources remain in Vendor/Stockfish for provenance but are no longer linked.
