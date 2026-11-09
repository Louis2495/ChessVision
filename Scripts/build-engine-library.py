#!/usr/bin/env python3
from pathlib import Path
import concurrent.futures,json,os,shlex,subprocess,sys
root=Path(__file__).resolve().parents[1];build=root/'.build/fairy';objects=build/'objects';objects.mkdir(parents=True,exist_ok=True)
compiler=shlex.split(os.environ.get('CXX','c++'))
flags=['-std=c++17','-O2','-DNDEBUG','-DIS_64BIT','-DNO_PREFETCH','-DNNUE_EMBEDDING_OFF','-DALLVARS','-pthread','-I'+str(root/'Engine'),'-I'+str(root/'Vendor/FairyStockfish')]
if sys.platform == "darwin": flags.append("-mmacosx-version-min=13.0")
config=json.dumps([compiler,flags,subprocess.check_output(compiler+['--version'],text=True).splitlines()[0]])
configfile=build/'configuration.json';refresh=not configfile.exists() or configfile.read_text()!=config
headers=list((root/'Vendor/FairyStockfish').rglob('*.h'))+list((root/'Engine').glob('*.h'))
latest_header=max(p.stat().st_mtime for p in headers)
sources=[root/'Engine/StockfishBridge.cpp']+sorted(p for p in (root/'Vendor/FairyStockfish').rglob('*.cpp') if p.name not in ['main.cpp','pyffish.cpp','ffishjs.cpp'])
def compile(source):
 object=objects/(str(source.relative_to(root)).replace('/','_')+'.o')
 if refresh or not object.exists() or object.stat().st_mtime<max(source.stat().st_mtime,latest_header):
  subprocess.run(compiler+flags+['-c',str(source),'-o',str(object)],check=True)
 return object
with concurrent.futures.ThreadPoolExecutor(max_workers=max(1,min(8,int(os.environ.get('BUILD_JOBS','4'))))) as pool:result=list(pool.map(compile,sources))
subprocess.run(['ar','rcs',str(build/'libfairy.a')]+list(map(str,result)),check=True)
configfile.write_text(config)
print(build/'libfairy.a')
