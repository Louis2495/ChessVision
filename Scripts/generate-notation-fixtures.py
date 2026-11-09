#!/usr/bin/env python3
"""Independent SAN/legal-move oracle. Optional dev dependency: chess==1.11.2."""
import json, random
from pathlib import Path
import chess
ROOT = Path(__file__).resolve().parents[1]
rng = random.Random(2495)
cases = []
def record(board, sample_all=False):
    legal = sorted(board.legal_moves, key=lambda m:m.uci())
    sample = legal if sample_all else rng.sample(legal, min(3, len(legal)))
    cases.append({'fen':board.fen(en_passant='fen'), 'legal':[move.uci() for move in legal], 'san':{move.uci():board.san(move) for move in sample}})
for fen in [
 'k6r/8/8/8/8/8/3N3N/7K w - - 0 1',
 '7k/8/8/8/8/8/8/1N3N1K w - - 0 1',
 '7k/8/8/8/8/1N6/8/1N3N1K w - - 0 1',
 '7k/8/8/8/8/R7/8/R6K w - - 0 1',
 '4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1',
 '4k3/P7/8/8/8/8/8/4K3 w - - 0 1',
 '4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2',
 '7k/5Q2/6K1/8/8/8/8/8 w - - 0 1',
 '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1',
]:
    record(chess.Board(fen), True)
board = chess.Board()
for ply in range(150):
    if board.is_game_over(): board=chess.Board()
    record(board)
    board.push(rng.choice(list(board.legal_moves)))
target=ROOT/'Tests/Core/Reference';target.mkdir(exist_ok=True)
(target/'notation.json').write_text(json.dumps({'oracle':'python-chess 1.11.2; random seed 2495', 'cases':cases},indent=2)+'\n')
print('Wrote',len(cases),'positions and',sum(len(c['san']) for c in cases),'SAN comparisons')
