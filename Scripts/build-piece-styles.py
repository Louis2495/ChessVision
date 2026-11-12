#!/usr/bin/env python3
"""Rebuild bundled vector styles from preserved licensed SVG sources. Requires CairoSVG."""
from pathlib import Path
import hashlib,json
import cairosvg
root=Path(__file__).resolve().parents[1]
vendor=root/'Vendor/PieceStyles'
provenance=json.loads((vendor/'PROVENANCE.json').read_text())
for display,details in provenance['sets'].items():
 for side in 'wb':
  for kind in 'KQRBNP':
   symbol=side+kind;relative=details['source']+'/'+symbol+'.svg';source=vendor/relative
   assert hashlib.sha256(source.read_bytes()).hexdigest()==provenance['sha256'][relative],relative
   target=root/f'NovaChess/Resources/Assets.xcassets/{display}-{symbol}.imageset';target.mkdir(exist_ok=True)
   cairosvg.svg2pdf(url=str(source),write_to=str(target/f'{symbol}.pdf'))
   (target/'Contents.json').write_text(json.dumps({'images':[{'filename':symbol+'.pdf','idiom':'universal'}],'info':{'author':'xcode','version':1},'properties':{'preserves-vector-representation':True}}))
print(f'Built {len(provenance["sets"])*12} vector piece assets from verified source files.')
