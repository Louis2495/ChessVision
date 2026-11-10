#!/usr/bin/env python3
from pathlib import Path
import concurrent.futures,json,os,shlex,subprocess,sys
root=Path(__file__).resolve().parents[1]
build=root/('.build/modern-assertions' if os.environ.get('ENGINE_ASSERTIONS')=='1' else '.build/modern')
objects=build/'objects';objects.mkdir(parents=True,exist_ok=True)
compiler=shlex.split(os.environ.get('CXX','c++'))
flags=['-std=c++20','-O3','-DNDEBUG','-include',str(root/'Engine/ModernConfig.h'),'-DIS_64BIT','-pthread','-I'+str(root/'Vendor/Stockfish19/src'),'-I'+str(root/'Engine')]
if os.environ.get('ENGINE_ASSERTIONS')=='1':flags.remove('-DNDEBUG')
if sys.platform=='darwin':flags.append('-mmacosx-version-min=13.0')
config=json.dumps([compiler,flags,subprocess.check_output(compiler+['--version'],text=True).splitlines()[0]]);cache=build/'configuration.json'
refresh=not cache.exists() or cache.read_text()!=config
headers=list((root/'Vendor/Stockfish19/src').rglob('*.h'))+list((root/'Engine').glob('*.h'))
latest=max(p.stat().st_mtime for p in headers+list((root/'Vendor/Stockfish19/src').rglob('*.cpp')))
sources=[root/'Engine/ModernStockfishBridge.cpp']+sorted((root/'Engine/ModernSources').glob('*.cpp'))
def compile(source):
 target=objects/(str(source.relative_to(root)).replace('/','_')+'.o')
 if refresh or not target.exists() or target.stat().st_mtime<max(latest,source.stat().st_mtime):subprocess.run(compiler+flags+['-c',str(source),'-o',str(target)],check=True)
 return target
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:result=list(pool.map(compile,sources))
temporary=build/'libmodern-new.a';temporary.unlink(missing_ok=True)
subprocess.run(['ar','rcs',str(temporary)]+list(map(str,result)),check=True)
temporary.replace(build/'libmodern.a')
cache.write_text(config)
print(build/'libmodern.a')
