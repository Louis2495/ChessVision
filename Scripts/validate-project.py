#!/usr/bin/env python3
"""Structural checks only; this does not replace an Xcode build."""
from pathlib import Path
import json,plistlib,re,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
pbx=(ROOT/'ChessVision.xcodeproj/project.pbxproj').read_text()
objects=set(re.findall(r'^([A-F0-9]{24}) = ',pbx,re.M))
assert objects
for reference in re.findall(r'(?:fileRef|target|targetProxy|containerPortal|remoteGlobalIDString|buildConfigurationList|productReference|rootObject|mainGroup|productRefGroup) = ([A-F0-9]{24})',pbx):assert reference in objects,reference
count=0
for m in re.finditer(r'isa = PBXFileReference;([^}]+)',pbx):
 fields=m.group(1)
 if 'sourceTree = SOURCE_ROOT' not in fields:continue
 raw=re.search(r'path = ("(?:[^"\\]|\\.)*"|[^;]+);',fields).group(1)
 path=json.loads(raw) if raw.startswith('"') else raw
 assert (ROOT/path).exists(),path;count+=1
scheme=ET.parse(ROOT/'ChessVision.xcodeproj/xcshareddata/xcschemes/ChessVision.xcscheme')
for ref in scheme.iter('BuildableReference'):assert ref.attrib['BlueprintIdentifier'] in objects
for f in ['ChessVision/Info.plist','ChessVision/Resources/PrivacyInfo.xcprivacy']:plistlib.loads((ROOT/f).read_bytes())
models=list((ROOT/'ChessVision/Resources').glob('*.mlpackage'))
assert len(models)==2
for model in models:
 manifest=json.loads((model/'Manifest.json').read_text())
 for item in manifest['itemInfoEntries'].values():assert (model/'Data'/item['path']).exists(),item
for side in ['w','b']:
 for piece in ['K','Q','R','B','N','P']:
  asset=ROOT/f'ChessVision/Resources/Assets.xcassets/{side}{piece}.imageset'
  assert (asset/f'{side}{piece}.pdf').exists()
  json.loads((asset/'Contents.json').read_text())
assert 'Tests/Headless' not in pbx, 'CLI harness must not be compiled into the hosted iOS tests'
for source in (ROOT/'ChessVision').rglob('*.swift'):assert str(source.relative_to(ROOT)) in pbx,source

assert 'Vendor/FairyStockfish/main.cpp' not in pbx
assert 'Vendor/FairyStockfish/pyffish.cpp' not in pbx
assert 'Vendor/FairyStockfish/ffishjs.cpp' not in pbx
assert 'Vendor/Stockfish/' not in pbx
assert 'NNUE_EMBEDDING_OFF' in pbx and 'c++17' in pbx
puzzles=json.loads((ROOT/'ChessVision/Core/Resources/Puzzles.json').read_text())
assert len(puzzles)==2000 and len({p['id'] for p in puzzles})==2000
assert len(json.loads((ROOT/'ChessVision/Core/Resources/Openings.json').read_text()))==3865
import struct
icon=(ROOT/'ChessVision/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png').read_bytes()
assert icon[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',icon[16:24])==(1024,1024) and icon[25]==2

print(f'PASS: {count} project paths, target/scheme references, plist files, both model packages, 12 base piece assets, 2,000 puzzles, 3,865 openings, opaque icon and Swift source membership.')
print('These are structural checks. iOS SDK compilation and runtime tests require macOS/Xcode.')

# Settings media and privacy reason must survive project regeneration.
import wave
with wave.open(str(ROOT/'ChessVision/Resources/ClassicalPrelude.wav'),'rb') as audio:
 assert audio.getnchannels()==1 and audio.getnframes()>audio.getframerate()*30
assert 'ClassicalPrelude.wav' in pbx
privacy=plistlib.loads((ROOT/'ChessVision/Resources/PrivacyInfo.xcprivacy').read_bytes())
assert any(item['NSPrivacyAccessedAPIType']=='NSPrivacyAccessedAPICategoryUserDefaults' and 'CA92.1' in item['NSPrivacyAccessedAPITypeReasons'] for item in privacy['NSPrivacyAccessedAPITypes'])

assert 'GCC_STRICT_ALIASING = "NO"' in pbx
assert (ROOT/'ChessVision/Resources/Assets.xcassets/CartoonDuck.imageset/CartoonDuck.png').exists()

# Every selectable piece set must contain all twelve vector assets, with preserved source provenance.
import hashlib
piece_provenance=json.loads((ROOT/'Vendor/PieceStyles/PROVENANCE.json').read_text())
for display,details in piece_provenance['sets'].items():
 for side in 'wb':
  for kind in 'KQRBNP':
   symbol=side+kind
   relative=details['source']+'/'+symbol+'.svg'
   assert hashlib.sha256((ROOT/'Vendor/PieceStyles'/relative).read_bytes()).hexdigest()==piece_provenance['sha256'][relative]
   directory=ROOT/f'ChessVision/Resources/Assets.xcassets/{display}-{symbol}.imageset'
   definition=json.loads((directory/'Contents.json').read_text())
   assert definition['properties']['preserves-vector-representation']
   assert (directory/definition['images'][0]['filename']).read_bytes().startswith(b'%PDF')
assert '"Traditional"' not in (ROOT/'ChessVision/UI/SettingsView.swift').read_text()
assert 'piece.glyph' not in (ROOT/'ChessVision/UI/BoardView.swift').read_text()
assert 'Find your next move' not in (ROOT/'ChessVision/UI/ContentView.swift').read_text()
print('PASS: all 36 additional vector pieces and source hashes; glyph pieces and old analysis heading removed.')

# Landscape is advertised for Bughouse and restricted elsewhere by the app delegate.
app_info=plistlib.loads((ROOT/'ChessVision/Info.plist').read_bytes())
assert set(app_info['UISupportedInterfaceOrientations']) == {'UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'}
assert 'UIApplicationDelegateAdaptor(ChessVisionDelegate.self)' in (ROOT/'ChessVision/ChessVisionApp.swift').read_text()
assert 'BughousePlayView.swift' in pbx and 'OrientationPolicy.swift' in pbx
print('PASS: Bughouse project membership and landscape declarations.')
