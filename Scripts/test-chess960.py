#!/usr/bin/env python3
"""Compare all Chess960 starts and sampled complete legal histories with python-chess."""
from pathlib import Path
import random, subprocess
import chess
root = Path(__file__).resolve().parents[1]
library = subprocess.check_output(['bash', str(root/'Scripts/build-engine-library.sh')], text=True).strip()
subprocess.run(['c++','-std=c++17','-O2','-pthread','-I'+str(root/'Engine'),str(root/'Tests/variant_rules.cpp'),library,'-o',str(root/'.build/variant-checks')],check=True)
p = subprocess.Popen([str(root/'.build/variant-checks')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
def query(index, history):
 p.stdin.write(f'cv960{index}\t'+ ' '.join(history)+'\n');p.stdin.flush();rows=[]
 while True:
  line=p.stdout.readline()
  if not line: raise RuntimeError('Engine exited')
  if line.strip()=='END': break
  rows.append(line.rstrip('\n').split('\t'))
 fields={r[0]:r[1] for r in rows if len(r)==2}
 assert 'error' not in fields,(index,history,fields)
 return fields,{r[1] for r in rows if r[0]=='move'}
try:
 for index in range(960):
  board=chess.Board.from_chess960_pos(index)
  fields,moves=query(index,[])
  native=chess.Board(fields['fen'],chess960=True)
  assert native.piece_map()==board.piece_map(),index
  assert moves=={m.uci() for m in board.legal_moves},index
 castles=0
 for index in [0,42,249,518,959]:
  board=chess.Board.from_chess960_pos(index);history=[];rng=random.Random(index)
  for ply in range(120):
   fields,moves=query(index,history)
   if fields['status']!='ongoing': break
   assert moves=={m.uci() for m in board.legal_moves},(index,history)
   legal=list(board.legal_moves);castling=[m for m in legal if board.is_castling(m)]
   move=rng.choice(castling or legal);castles+=int(board.is_castling(move));history.append(move.uci());board.push(move)
 assert castles>0
 print(f'PASS: all 960 starts and five sampled legal histories, including {castles} castling moves.')
finally:
 p.stdin.close();p.wait(timeout=10)
