#!/usr/bin/env python3
"""Rebuild the bundled CC0 facts from pinned upstream inputs; requires chess==1.11.2."""
from pathlib import Path
import argparse,csv,hashlib,json
import chess,chess.pgn,io
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('puzzles',type=Path);p.add_argument('openings',type=Path);a=p.parse_args()
provenance=json.loads((ROOT/'Vendor/ChessData/PROVENANCE.json').read_text())
assert hashlib.sha256(a.puzzles.read_bytes()).hexdigest()==provenance['puzzles']['source_sha256'], 'Puzzle source does not match the pinned snapshot'
for name,digest in provenance['openings']['sha256'].items():
 assert hashlib.sha256((a.openings/name).read_bytes()).hexdigest()==digest, 'Opening source does not match: '+name
valid=[];seen=set()
for row in csv.DictReader(a.puzzles.open()):
 if int(row['Popularity'])<75 or int(row['NbPlays'])<100 or int(row['RatingDeviation'])>100:continue
 try:
  board=chess.Board(row['FEN']);moves=row['Moves'].split()
  if not board.is_valid() or len(moves)<2:continue
  for uci in moves:
   move=chess.Move.from_uci(uci)
   if move not in board.legal_moves:raise ValueError('illegal solution')
   board.push(move)
  key=(row['FEN'],tuple(moves))
  if key in seen:continue
  seen.add(key)
  rating=int(row['Rating'])
  valid.append(dict(id=row['PuzzleId'],fen=row['FEN'],moves=moves,sourceRating=rating,themes=row['Themes'].split(),gameURL=row['GameUrl']))
 except (ValueError,KeyError):continue
valid.sort(key=lambda x:(x['sourceRating'],x['id']))
target=provenance["puzzles"]["bundled_count"]
assert len(valid)>=target
existing=json.loads((ROOT/'NovaChess/Core/Resources/Puzzles.json').read_text())
by_id={p['id']:p for p in valid}
assert all(by_id[p['id']]==p for p in existing), 'Existing puzzle records no longer match the pinned source'
puzzles=list(existing)
def solving_key(puzzle):
 board=chess.Board(puzzle['fen']);board.push_uci(puzzle['moves'][0])
 return board.epd(en_passant='legal')
positions={solving_key(p) for p in puzzles}
assert len(positions)==len(puzzles), 'Existing library has duplicate solving positions'
selected={p['id'] for p in puzzles}
remaining=[]
for puzzle in valid:
 key=solving_key(puzzle)
 if puzzle['id'] not in selected and key not in positions:
  remaining.append(puzzle);positions.add(key)
needed=target-len(puzzles)
assert 0<=needed<=len(remaining), 'Not enough distinct validated puzzles'
if needed==1:
 puzzles.append(remaining[len(remaining)//2])
elif needed>1:
 puzzles.extend(remaining[round(i*(len(remaining)-1)/(needed-1))] for i in range(needed))
assert len(puzzles)==target and len({p['id'] for p in puzzles})==target
assert len({solving_key(p) for p in puzzles})==target
out=ROOT/'NovaChess/Core/Resources';out.mkdir(exist_ok=True)
(out/'Puzzles.json').write_text(json.dumps(puzzles,separators=(',',':'))+'\n')
openings=[]
for file in sorted(a.openings.glob('[abcde].tsv')):
 for row in csv.DictReader(file.open(),delimiter='\t'):
  game=chess.pgn.read_game(io.StringIO(row['pgn']));assert not game.errors
  board=game.end().board();moves=[move.uci() for move in game.mainline_moves()]
  openings.append(dict(id=row['eco']+'-'+hashlib.sha256((row['name']+' '.join(moves)).encode()).hexdigest()[:12],eco=row['eco'],name=row['name'],moves=moves,key=board.epd(en_passant='legal')))
(out/'Openings.json').write_text(json.dumps(openings,ensure_ascii=False,separators=(',',':'))+'\n')
print('Validated and bundled:',len(puzzles),'unique puzzles;',len(openings),'named opening lines')
print('Puzzle source SHA256',hashlib.sha256(a.puzzles.read_bytes()).hexdigest())
