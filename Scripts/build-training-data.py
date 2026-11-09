#!/usr/bin/env python3
"""Rebuild the bundled CC0 facts from pinned upstream inputs; requires chess==1.11.2."""
from pathlib import Path
import argparse,csv,hashlib,json,math
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
  rating=int(row['Rating']);estimate=max(200,int(math.floor((rating*.8)/50+.5))*50)
  valid.append(dict(id=row['PuzzleId'],fen=row['FEN'],moves=moves,sourceRating=rating,estimatedRating=estimate,themes=row['Themes'].split(),gameURL=row['GameUrl']))
 except (ValueError,KeyError):continue
valid.sort(key=lambda x:(x['estimatedRating'],x['id']))
assert len(valid)>=1000
puzzles=[valid[round(i*(len(valid)-1)/999)] for i in range(1000)]
assert len({p['id'] for p in puzzles})==1000
out=ROOT/'ChessVision/Core/Resources';out.mkdir(exist_ok=True)
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
