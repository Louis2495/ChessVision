#!/usr/bin/env python3
"""Fixed-depth comparisons with the official release, plus safe NNUE failure handling."""
from pathlib import Path
import hashlib,json,os,re,shlex,subprocess
root=Path(__file__).resolve().parents[1]
os.chdir(root)
reference=json.loads((root/'Tests/modern-engine-reference.json').read_text())
network=root/'ChessVision/Resources/Engine/nn-1a298aa575a0.nnue'
assert hashlib.sha256(network.read_bytes()).hexdigest()==reference['network_sha256']
library=subprocess.check_output(['python3','Scripts/build-modern-engine.py'],text=True).strip()
compiler=shlex.split(os.environ.get('CXX','c++'))
subprocess.run(compiler+['-std=c++20','-O2','-pthread','-IEngine','Tests/modern_engine_probe.cpp',library,'-o','.build/modern-probe'],check=True)
for case in reference['positions']:
 result=subprocess.run(['.build/modern-probe',str(network),case['fen'],'12'],text=True,capture_output=True,timeout=90,check=True)
 score=re.search(r'score (cp|mate) (-?\d+)',result.stdout)
 best=re.search(r'bestmove (\S+)',result.stdout)
 assert best and best[1]==case['move'],(case['name'],result.stdout)
 assert score and score[1]==case['type'] and int(score[2])==case['score'],(case['name'],result.stdout)
 print('PASS: official SF19 reference:',case['name'])
bad=root/'.build/invalid-network.nnue';bad.write_bytes(b'not a neural network')
for path in [bad,root/'.build/missing-network.nnue']:
 result=subprocess.run(['.build/modern-probe',str(path),reference['positions'][0]['fen'],'4'],text=True,capture_output=True,timeout=30)
 assert result.returncode==4 and 'engineerror' in result.stderr,(result.returncode,result.stderr)
print('PASS: missing/corrupt NNUE reports an engine error without upstream terminating the process.')
