# Ratings and USCF accuracy

NovaChess does **not** publish official US Chess ratings or claim a validated USCF-equivalent playing strength. Bot strength, human tournament ratings, variant pools, puzzle difficulty and single-game engine accuracy are different quantities. Changing a formula or applying a constant offset does not establish equivalence between them.

## Standard local estimate (version 0.24)

`RatingPolicy` implements the published US Chess **approximation**, processing each game as a one-game event:

- Start displaying 1000 until a rated result is available. For the first eight results, combine the prior performance estimate with the opponent rating plus 400 for a win, minus 400 for a loss, or unchanged for a draw: `(N × R + opponent + 400 × (2S − 1)) / (N + 1)`.
- Thereafter, `N* = 50 / sqrt(0.662 + 0.00000739 × (2569 − R)^2)` below 2355, or 50 at/above 2355. `N' = min(actual previous games, N*)`.
- `E = 1 / (1 + 10^((opponent − R)/400))`, `K = 800/(N' + 1)`, `Rnew = max(100, R + K(S − E))`.
- Keep fractional precision between games and round only for display and the displayed change. Mark the estimate provisional through 25 games.

This replaces the earlier fixed K=64/32 calculation for Standard. It is **not the complete official event-rating algorithm**: no official age-based initialization, all-win/all-loss special handling, event rerating passes, historical/title/money/participation floors, bonus points or cross-system initializations are inferred. One-game local events do not receive event bonuses. The 100 minimum is the only implemented floor. Blindfold and variant ratings retain separate local Elo pools rather than claiming USCF applicability.

References: [US Chess system, September 2020](https://new.uschess.org/sites/default/files/media/documents/the-us-chess-rating-system-revised-september-2020.pdf), [Mark Glickman, Approximating Formulas](https://www.glicko.net/ratings/approx.pdf). These identify the mathematical basis and full-system differences, not a certification that this app reproduces current official event processing. The official PDF host was inaccessible under this cloud's network policy; the formulas were cross-checked against publicly accessible calculator documentation, not a live official certification service.

## Bot-strength limits

Stockfish 19's own `Vendor/Stockfish19/src/search.h` describes its UCI_Elo fit to Stash engine results and **approximate CCRL Blitz** range 1320–3190. This is not calibration to USCF humans. Fairy-Stockfish supplies weaker Standard opponents and variants (UCI_Elo range 500–2850); there is no per-variant human calibration. Developer's 2407 is its configured engine target.

Out-of-range targets previously could earn local points as though the requested number represented a measured opponent, even though the engine selected minimum/full strength. Rated Standard/blindfold targets now require 500–3190; variants require 500–2850. Adaptive games cannot affect ratings even if stale saved data also has a rated flag. Unrated requests outside these ranges remain available.

To establish a USCF-equivalent estimate, collect a sufficiently large dataset of games against independently verified USCF-rated humans under specified time controls and conditions. Fit and validate against held-out players, report uncertainty, and reassess by device/search budget. No such dataset is bundled or available here. Official tournament ratings must still come from US Chess.

## Existing progress

On library load, rebuild legacy Standard estimates chronologically when every previously rated result is archived, including the per-game changes. Unsupported or adaptive results are excluded. Migration is versioned and idempotent, does not settle games again, and preserves achievements, game IDs, folders and solved puzzles. If the complete rated history cannot be established, retain the old estimate and count as a labeled legacy seed for future updates.

## Puzzles and reviews

All 4000 puzzles now use original source Lichess difficulty ratings. The arbitrary `0.8 × Lichess` conversion and its claim to a Chess.com-style scale were removed. Personal puzzle progress is still an independent local training estimate with fast placement, not an official Lichess account rating or any USCF equivalent. Old personal estimates are rescaled once by dividing by 0.8, retaining solved IDs, attempts and successes, and restarting placement. This is a change of training scale only.

Single-game average centipawn loss and move labels are retained. The former `2800 − 8 × average loss` human-rating estimate was removed because it had no calibration dataset. Engine loss also depends on position, opponent, depth and variant and is not a human rating conversion.
