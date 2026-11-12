#!/usr/bin/env python3
"""Structural checks only; this does not replace an Xcode build."""
from pathlib import Path
import json,plistlib,re,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
pbx=(ROOT/'NovaChess.xcodeproj/project.pbxproj').read_text()
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
scheme=ET.parse(ROOT/'NovaChess.xcodeproj/xcshareddata/xcschemes/NovaChess.xcscheme')
for ref in scheme.iter('BuildableReference'):assert ref.attrib['BlueprintIdentifier'] in objects
for f in ['NovaChess/Info.plist','NovaChess/Resources/PrivacyInfo.xcprivacy']:plistlib.loads((ROOT/f).read_bytes())
models=list((ROOT/'NovaChess/Resources').glob('*.mlpackage'))
assert len(models)==2
for model in models:
 manifest=json.loads((model/'Manifest.json').read_text())
 for item in manifest['itemInfoEntries'].values():assert (model/'Data'/item['path']).exists(),item
for side in ['w','b']:
 for piece in ['K','Q','R','B','N','P']:
  asset=ROOT/f'NovaChess/Resources/Assets.xcassets/{side}{piece}.imageset'
  assert (asset/f'{side}{piece}.pdf').exists()
  json.loads((asset/'Contents.json').read_text())
assert 'Tests/Headless' not in pbx, 'CLI harness must not be compiled into the hosted iOS tests'
for source in (ROOT/'NovaChess').rglob('*.swift'):assert str(source.relative_to(ROOT)) in pbx,source

assert 'Vendor/FairyStockfish/main.cpp' not in pbx
assert 'Vendor/FairyStockfish/pyffish.cpp' not in pbx
assert 'Vendor/FairyStockfish/ffishjs.cpp' not in pbx
assert 'Vendor/Stockfish/' not in pbx
assert 'Vendor/Stockfish19/src/main.cpp' not in pbx
assert 'Engine/ModernStockfishBridge.cpp' in pbx and '-std=c++20' in pbx
assert 'NNUE_EMBEDDING_OFF' in pbx and 'c++17' in pbx
puzzles=json.loads((ROOT/'NovaChess/Core/Resources/Puzzles.json').read_text())
assert len(puzzles)==4000 and len({p['id'] for p in puzzles})==4000
assert len(json.loads((ROOT/'NovaChess/Core/Resources/Openings.json').read_text()))==3865
import struct
icon=(ROOT/'NovaChess/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png').read_bytes()
assert icon[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',icon[16:24])==(1024,1024) and icon[25]==2

print(f'PASS: {count} project paths, target/scheme references, plist files, both model packages, 12 base piece assets, 4,000 puzzles, 3,865 openings, opaque icon and Swift source membership.')
print('These are structural checks. iOS SDK compilation and runtime tests require macOS/Xcode.')

# Settings media and privacy reason must survive project regeneration.
import wave
with wave.open(str(ROOT/'NovaChess/Resources/ClassicalPrelude.wav'),'rb') as audio:
 assert audio.getnchannels()==1 and audio.getnframes()>audio.getframerate()*30
assert 'ClassicalPrelude.wav' in pbx
privacy=plistlib.loads((ROOT/'NovaChess/Resources/PrivacyInfo.xcprivacy').read_bytes())
assert any(item['NSPrivacyAccessedAPIType']=='NSPrivacyAccessedAPICategoryUserDefaults' and 'CA92.1' in item['NSPrivacyAccessedAPITypeReasons'] for item in privacy['NSPrivacyAccessedAPITypes'])

assert 'GCC_STRICT_ALIASING = "NO"' in pbx
assert (ROOT/'NovaChess/Resources/Assets.xcassets/CartoonDuck.imageset/CartoonDuck.png').exists()

# Every selectable piece set must contain all twelve vector assets, with preserved source provenance.
import hashlib
piece_provenance=json.loads((ROOT/'Vendor/PieceStyles/PROVENANCE.json').read_text())
for display,details in piece_provenance['sets'].items():
 for side in 'wb':
  for kind in 'KQRBNP':
   symbol=side+kind
   relative=details['source']+'/'+symbol+'.svg'
   assert hashlib.sha256((ROOT/'Vendor/PieceStyles'/relative).read_bytes()).hexdigest()==piece_provenance['sha256'][relative]
   directory=ROOT/f'NovaChess/Resources/Assets.xcassets/{display}-{symbol}.imageset'
   definition=json.loads((directory/'Contents.json').read_text())
   assert definition['properties']['preserves-vector-representation']
   assert (directory/definition['images'][0]['filename']).read_bytes().startswith(b'%PDF')
assert '"Traditional"' not in (ROOT/'NovaChess/UI/SettingsView.swift').read_text()
assert 'piece.glyph' not in (ROOT/'NovaChess/UI/BoardView.swift').read_text()
assert 'Find your next move' not in (ROOT/'NovaChess/UI/ContentView.swift').read_text()
print(f'PASS: all {len(piece_provenance["sets"])*12} additional vector pieces and source hashes; glyph pieces and old analysis heading removed.')

# Landscape is advertised for Bughouse and restricted elsewhere by the app delegate.
app_info=plistlib.loads((ROOT/'NovaChess/Info.plist').read_bytes())
assert set(app_info['UISupportedInterfaceOrientations']) == {'UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'}
assert 'UIApplicationDelegateAdaptor(NovaChessDelegate.self)' in (ROOT/'NovaChess/NovaChessApp.swift').read_text()
assert 'BughousePlayView.swift' in pbx and 'OrientationPolicy.swift' in pbx
print('PASS: Bughouse project membership and landscape declarations.')

network=ROOT/'NovaChess/Resources/Engine/nn-1a298aa575a0.nnue'
assert network.stat().st_size==98511183
assert hashlib.sha256(network.read_bytes()).hexdigest()=='1a298aa575a085434d29027978dc36867fe9c5bcea9376654b7a8eba1e52dfc2'
assert str(network.relative_to(ROOT)) in pbx
print('PASS: official Stockfish 19 NNUE network SHA-256 and dual-engine project membership.')

# Keep Xcode's object filenames unique across the two engine source trees.
engine_sources=re.findall(r'path = "([^";]+\.cpp)";',pbx)
assert len([Path(s).name for s in engine_sources])==len(set(Path(s).name for s in engine_sources))
wrappers=list((ROOT/'Engine/ModernSources').glob('*.cpp'))
upstream=[p for p in (ROOT/'Vendor/Stockfish19/src').rglob('*.cpp') if p.name!='main.cpp' and 'universal' not in p.parts]
assert len(wrappers)==len(upstream)==25
for wrapper in wrappers:
 target=re.search(r'#include "([^"]+)"',wrapper.read_text())[1]
 assert (wrapper.parent/target).resolve() in [p.resolve() for p in upstream]
print('PASS: unique engine object basenames and all 25 unmodified modern translation units.')

assert plistlib.loads((ROOT/'NovaChess/NovaChess.entitlements').read_bytes())['com.apple.developer.game-center'] is True
assert 'CODE_SIGN_ENTITLEMENTS = "NovaChess/NovaChess.entitlements"' in pbx
assert 'CorrespondenceService.swift' in pbx and 'CorrespondenceView.swift' in pbx
print('PASS: Game Center entitlement and correspondence source membership.')

entitlements=plistlib.loads((ROOT/'NovaChess/NovaChess.entitlements').read_bytes())
assert entitlements['com.apple.developer.icloud-container-identifiers']==['iCloud.com.novachess.app']
assert entitlements['com.apple.developer.icloud-services']==['CloudKit']
assert 'com.novachess.app' in pbx
assert not (ROOT/'ChessVision.xcodeproj').exists() and not (ROOT/'ChessVision').exists()
assert 'SocialStore.swift' in pbx and 'ScreenRecognition.swift' in pbx
print('PASS: NovaChess identity, CloudKit entitlements and social/screen source membership.')


# Offline country map and new profile/statistics screens must ship in Xcode.
countries=json.loads((ROOT/'NovaChess/Core/Resources/Countries.json').read_text())
assert len(countries) >= 230 and 'Countries.json' in pbx
assert {'US','GB','FR','JP','IN','BR','ZA','AU','SG'} <= {c['code'] for c in countries}
assert all(len(c['code']) == 2 and c['polygons'] for c in countries)
print('PASS: offline country geometry and resource membership.')
