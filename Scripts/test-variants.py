#!/usr/bin/env python3
"""Differential rules checks against python-chess, including crazyhouse drops and counters."""
from pathlib import Path
import random,subprocess
import chess,chess.variant
root=Path(__file__).resolve().parents[1]
library=subprocess.check_output(['bash',str(root/'Scripts/build-engine-library.sh')],text=True).strip()
subprocess.run(['c++','-std=c++17','-O2','-pthread','-I'+str(root/'Engine'),str(root/'Tests/variant_rules.cpp'),library,'-o',str(root/'.build/variant-checks')],check=True)
process=subprocess.Popen([str(root/'.build/variant-checks')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
checked=0;drops=0;endings=0
try:
 for variant,klass in [('chess',chess.Board),('3check',chess.variant.ThreeCheckBoard),('kingofthehill',chess.variant.KingOfTheHillBoard),('horde',chess.variant.HordeBoard),('crazyhouse',chess.variant.CrazyhouseBoard)]:
  for seed in range(3):
   rng=random.Random(2495+seed);board=klass();history=[]
   for ply in range(100):
    process.stdin.write(variant+'\t'+' '.join(history)+'\n');process.stdin.flush()
    records=[]
    while True:
     line=process.stdout.readline()
     if not line:raise RuntimeError('Native rules process terminated')
     if line.strip()=='END':break
     if line.strip():records.append(line.rstrip('\n').split('\t'))
    fields={row[0]:row[1] for row in records if len(row)==2}
    assert 'error' not in fields,(variant,history,fields)
    native=klass(fields['fen']);expected={move.uci() for move in board.legal_moves}
    got={row[1] for row in records if row[0]=='move'}
    if fields['status']=='ongoing':assert got==expected,(variant,history,sorted(expected-got),sorted(got-expected))
    assert native.piece_map()==board.piece_map(),(variant,history,'placement')
    assert native.turn==board.turn and native.castling_rights==board.castling_rights,(variant,history,'state')
    if variant=='crazyhouse':assert str(native.pockets[0])==str(board.pockets[0]) and str(native.pockets[1])==str(board.pockets[1])
    if variant=='3check':assert native.remaining_checks==board.remaining_checks
    for row in records:
     if row[0]=='move':assert board.san(chess.Move.from_uci(row[1]))==row[2],(variant,history,row)
    checked+=1
    if fields['status']!='ongoing':
     assert board.is_game_over(claim_draw=True),(variant,history,fields['status'])
     endings+=1;break
    legal=list(board.legal_moves)
    # Exercise goals/captures/drops instead of relying exclusively on quiet random play.
    checks=[m for m in legal if board.gives_check(m)]
    captures=[m for m in legal if board.is_capture(m)]
    dropping=[m for m in legal if m.drop]
    central=[m for m in legal if board.piece_type_at(m.from_square)==chess.KING and chess.square_distance(m.to_square,chess.D4)<chess.square_distance(m.from_square,chess.D4)]
    choices=(checks if variant=='3check' and checks else central if variant=='kingofthehill' and central else dropping if dropping and rng.random()<.6 else captures if captures and rng.random()<.5 else legal)
    move=rng.choice(choices);drops+=bool(move.drop);board.push(move);history.append(move.uci())
 # A promoted queen captured in crazyhouse must return to the capturer's pocket as a pawn.
 history='a2a4 h7h5 a4a5 h5h4 a5a6 h4h3 a6b7 h3g2 b7a8q g2h1q a8b8 h1g1 b8c8 g1f1 e1f1'.split()
 board=chess.variant.CrazyhouseBoard()
 for uci in history:board.push_uci(uci)
 process.stdin.write('crazyhouse\t'+' '.join(history)+'\n');process.stdin.flush()
 records=[]
 while True:
  line=process.stdout.readline()
  if not line:raise RuntimeError('Native process terminated in promoted-capture regression')
  if line.strip()=='END':break
  if line.strip():records.append(line.rstrip('\n').split('\t'))
 fields={row[0]:row[1] for row in records if len(row)==2}
 native=chess.variant.CrazyhouseBoard(fields['fen'])
 assert native.promoted==board.promoted and str(native.pockets[0])==str(board.pockets[0]) and str(native.pockets[1])==str(board.pockets[1])
 assert {r[1] for r in records if r[0]=='move'}=={m.uci() for m in board.legal_moves}
 checked+=1
 print(f'PASS: {checked} native positions across five variants; SAN/legality/state/counters/pockets; {drops} drops and {endings} game endings; promoted-capture-to-pawn regression.')
finally:
 process.stdin.close();process.wait(timeout=10)
