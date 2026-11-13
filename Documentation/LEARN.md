# Learn: openings, facts and history

Version 0.27 presents three square navigation cards, stacked and centered: Openings, Fun facts, History. They scale to the available portrait height and remain scrollable when the viewport cannot fit the stack.

## Openings and Developer

The curated list now has **65 lessons**, selected from distinct branches and a wider set of opening families. Lessons remain 16–40 half-moves (8–20 full moves); search exposes other lines within that range. All lines are legal and retain their original IDs/final keys. Three authored London/Scandinavian/Modern illustrations remain available.

The Developer keeps its configured target **2407**. Its 17 validated book lines cover:

- White: Italian after e4/e5; Grand Prix against the Sicilian (Nc3, then f4 against common replies); French Tarrasch with Nd2; Alekhine Exchange with exd6 instead of the Four Pawns Attack.
- Black: Open Ruy Lopez with a6, Nf6 and Nxe4 after White castles; Nimzo-Indian after d4/c4/Nc3; early accepted Catalan.

Book moves are indexed by legal position, so transpositions can match. The Catalan rule captures d5xc4 as soon as legal when White has the d4/c4 pawn center and kingside fianchetto setup. Other deviations fall back to the engine rather than forcing an illegal continuation. Black cannot force a Nimzo-Indian if White avoids the required setup. The Alekhine wording “on d6” was interpreted as the Exchange Variation, exd6.

## Fun facts and illustrations

The bundled content has **56 original concise fact summaries** across rules, pieces, numbers, origins, people and technology. Category filtering and search avoid a long undifferentiated text page. Cards use large numbers, icons and six empty-board movement illustrations. The diagrams show geometric destinations, not a playable legal position with kings.

Long-press a card for its reference link. All summaries and graphics load offline; no external portrait, recording, web page or application code is copied. `Scripts/build-learning-content.py` regenerates the checked-in JSON; it is not needed to build the app in Xcode.

## History and ratings

History has Milestones, Champions and Ratings views: **22 historical milestones**, the open championship lineage, and a separately selectable **1993–2006 FIDE split branch**. The 27 reign entries cover 18 main-line champions, including repeated Alekhine/Botvinnik reigns, plus six FIDE split reigns. Coverage is explicitly through the **2024 championship**, not a claim to a live current champion/ranking feed. The final row says “Won 2024,” not an unverified present-tense reign end.

Ratings are **dated event snapshots**, not peaks or cross-era strength conversions. For example, Carlsen's value is from the 2021 event, Karpov's first main-line entry uses the 1978 defense, and Spassky's 1972 rating is supplied during his reign. Early title-era ratings absent from the data show a dash; retrospective Chessmetrics estimates are not substituted for FIDE Elo. The graphical scale is explicitly 0–3000. The rating year is visible on every rated card.

`Vendor/ChessHistory/PROVENANCE.json` records source links, pinned archive commits, file SHA-256 hashes and example game headers for the archived snapshots. Knockout events can span rating-list periods: the Ponomariov and Khalifman snapshots use the final-stage headers, rather than mixing earlier rounds. Gukesh's November 2024 standard rating is a historical FIDE reference; the primary FIDE host could not be fetched under this cloud network policy, and that limitation is recorded in provenance. Source links are available from long-press menus. The app makes no USCF equivalence claim for these historical event values.

## Review and time controls

Areas for improvement remain in Stats; individual-game suggestions retain the compact icon/SAN/arrow layout. The shared Clock and Bughouse preset list now includes **1+1** and omits **5+3** and **10+5**. Custom controls remain available. Default selections locate the five-minute preset by value rather than by an index that would shift when the list changes.
