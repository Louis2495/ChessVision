from pathlib import Path
import hashlib,json,plistlib
r=Path(__file__).resolve().parents[1]
# Deterministic, checked-in Xcode project. No project generator needed on the Mac.
def uid(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def q(s):return json.dumps(str(s))
objects={}
def obj(k,v):objects[uid(k)]=v;return uid(k)
def ref(k):return uid(k)
def arr(items):return '('+','.join(items)+',)' if items else '()'
files=sorted([str(p.relative_to(r)) for p in (r/'NovaChess').rglob('*.swift')]+['Engine/StockfishBridge.cpp','Engine/ModernStockfishBridge.cpp']+[str(p.relative_to(r)) for p in (r/'Vendor/FairyStockfish').rglob('*.cpp') if p.name not in ['main.cpp','pyffish.cpp','ffishjs.cpp']])
modern_files=[str(p.relative_to(r)) for p in (r/'Engine/ModernSources').glob('*.cpp')]
files+=sorted(modern_files)
resources=['NovaChess/Resources/Engine/nn-1a298aa575a0.nnue','NovaChess/Resources/ClassicalPrelude.wav','NovaChess/Resources/Assets.xcassets','NovaChess/Resources/ChessPieces.mlpackage','NovaChess/Resources/ChessPiecesDetail.mlpackage','NovaChess/Resources/ThirdPartyNotices.txt','NovaChess/Resources/PrivacyInfo.xcprivacy','NovaChess/Core/Resources/Puzzles.json','NovaChess/Core/Resources/Openings.json']
fileids=[];buildids=[];resids=[]
for f in files+resources:
 typ='sourcecode.swift' if f.endswith('.swift') else 'sourcecode.cpp.cpp' if f.endswith('.cpp') else 'folder.assetcatalog' if f.endswith('.xcassets') else 'folder.mlpackage' if f.endswith('.mlpackage') else 'text.xml' if f.endswith('.xcprivacy') else 'text'
 fid=obj('file:'+f,'{isa = PBXFileReference; lastKnownFileType = '+typ+'; path = '+q(f)+'; sourceTree = SOURCE_ROOT;}');fileids.append(fid)
 extra=''
 if f in modern_files or f=='Engine/ModernStockfishBridge.cpp': extra=' settings = {COMPILER_FLAGS = '+q('-std=c++20 -include "$(SRCROOT)/Engine/ModernConfig.h" -I"$(SRCROOT)/Vendor/Stockfish19/src"')+';};'
 elif f.endswith('.cpp'): extra=' settings = {COMPILER_FLAGS = '+q('-I"$(SRCROOT)/Vendor/FairyStockfish"')+';};'
 bid=obj('build:'+f,'{isa = PBXBuildFile; fileRef = '+fid+';'+extra+'}')
 # Core ML models belong in Sources so Xcode invokes coremlc, not a raw resource copy.
 if f in files or f.endswith('.mlpackage'):buildids.append(bid)
 else:resids.append(bid)
product=obj('product','{isa = PBXFileReference; explicitFileType = wrapper.application; path = NovaChess.app; sourceTree = BUILT_PRODUCTS_DIR;}')
products=obj('products','{isa = PBXGroup; children = '+arr([product])+'; name = Products; sourceTree = "<group>";}')
main=obj('main','{isa = PBXGroup; children = '+arr(fileids+[products])+'; sourceTree = "<group>";}')
sources=obj('sources','{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = '+arr(buildids)+'; runOnlyForDeploymentPostprocessing = 0;}')
res=obj('resources','{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = '+arr(resids)+'; runOnlyForDeploymentPostprocessing = 0;}')
frameworks=obj('frameworks','{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;}')
common={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_CXX_LANGUAGE_STANDARD':'c++17','CLANG_CXX_LIBRARY':'libc++','CLANG_ENABLE_MODULES':'YES','ENABLE_USER_SCRIPT_SANDBOXING':'YES'}
app={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.novachess.app','INFOPLIST_FILE':'NovaChess/Info.plist','CODE_SIGN_STYLE':'Automatic','CODE_SIGN_ENTITLEMENTS':'NovaChess/NovaChess.entitlements','TARGETED_DEVICE_FAMILY':'1','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SWIFT_OBJC_BRIDGING_HEADER':'NovaChess/NovaChess-Bridging-Header.h','HEADER_SEARCH_PATHS':['$(inherited)','$(SRCROOT)/Engine'],'GCC_PREPROCESSOR_DEFINITIONS':['$(inherited)','IS_64BIT','NO_PREFETCH','NNUE_EMBEDDING_OFF','ALLVARS'],'OTHER_LDFLAGS':['$(inherited)','-lc++'],'GCC_STRICT_ALIASING':'NO','GCC_OPTIMIZATION_LEVEL':'3','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','CURRENT_PROJECT_VERSION':'21','MARKETING_VERSION':'0.19.0','SWIFT_EMIT_LOC_STRINGS':'YES','COREML_CODEGEN_LANGUAGE':'Swift','ENABLE_PREVIEWS':'YES'}
def settings(d):return '{'+''.join(k+' = '+(arr([q(x) for x in v]) if isinstance(v,list) else q(v))+';' for k,v in d.items())+'}'
for scope,base in [('project',common),('app',app)]:
 configs=[]
 for mode in ['Debug','Release']:
  conf=base.copy()
  if scope=='project':conf.update({'GCC_OPTIMIZATION_LEVEL':'0' if mode=='Debug' else '3','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym','ENABLE_TESTABILITY':'YES' if mode=='Debug' else 'NO'})
  configs.append(obj(scope+mode,'{isa = XCBuildConfiguration; buildSettings = '+settings(conf)+'; name = '+mode+';}'))
 obj(scope+'config','{isa = XCConfigurationList; buildConfigurations = '+arr(configs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
target=obj('target','{isa = PBXNativeTarget; buildConfigurationList = '+ref('appconfig')+'; buildPhases = '+arr([sources,frameworks,res])+'; buildRules = (); dependencies = (); name = NovaChess; productName = NovaChess; productReference = '+product+'; productType = "com.apple.product-type.application";}')

testfiles = sorted(str(p.relative_to(r)) for folder in ['Tests/Core','Tests/iOS'] for p in (r/folder).rglob('*.swift'))
testbuild=[]
for f in testfiles:
 fid=obj('file:'+f,'{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = '+q(f)+'; sourceTree = SOURCE_ROOT;}')
 bid=obj('build:'+f,'{isa = PBXBuildFile; fileRef = '+fid+';}');testbuild.append(bid)
# Visible test group attached to the main group.
testgroup=obj('testgroup','{isa = PBXGroup; children = '+arr([ref('file:'+f) for f in testfiles])+'; name = Tests; sourceTree = "<group>";}')
objects[main]=objects[main].replace(arr(fileids+[products]),arr(fileids+[testgroup,products]))
testproduct=obj('testproduct','{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = NovaChessTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;}')
objects[products]=objects[products].replace(arr([product]),arr([product,testproduct]))
testsources=obj('testsources','{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = '+arr(testbuild)+'; runOnlyForDeploymentPostprocessing = 0;}')
fixturefile=obj('fixturefile','{isa = PBXFileReference; lastKnownFileType = folder; path = Tests/Fixtures; sourceTree = SOURCE_ROOT;}')
fixturebuild=obj('fixturebuild','{isa = PBXBuildFile; fileRef = '+fixturefile+';}')
referencefile=obj('referencefile','{isa = PBXFileReference; lastKnownFileType = folder; path = Tests/Core/Reference; sourceTree = SOURCE_ROOT;}')
referencebuild=obj('referencebuild','{isa = PBXBuildFile; fileRef = '+referencefile+';}')
testresources=obj('testresources','{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = '+arr([fixturebuild,referencebuild])+'; runOnlyForDeploymentPostprocessing = 0;}')
testconfigs=[]
for mode in ['Debug','Release']:
 d={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.novachess.app.tests','GENERATE_INFOPLIST_FILE':'YES','SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/NovaChess.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/NovaChess','BUNDLE_LOADER':'$(TEST_HOST)','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O'}
 testconfigs.append(obj('test'+mode,'{isa = XCBuildConfiguration; buildSettings = '+settings(d)+'; name = '+mode+';}'))
testconfig=obj('testconfig','{isa = XCConfigurationList; buildConfigurations = '+arr(testconfigs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;}')
proxy=obj('proxy','{isa = PBXContainerItemProxy; containerPortal = '+ref('project')+'; proxyType = 1; remoteGlobalIDString = '+target+'; remoteInfo = NovaChess;}')
dependency=obj('dependency','{isa = PBXTargetDependency; target = '+target+'; targetProxy = '+proxy+';}')
testtarget=obj('testtarget','{isa = PBXNativeTarget; buildConfigurationList = '+testconfig+'; buildPhases = '+arr([testsources,testresources])+'; buildRules = (); dependencies = '+arr([dependency])+'; name = NovaChessTests; productName = NovaChessTests; productReference = '+testproduct+'; productType = "com.apple.product-type.bundle.unit-test";}')


uifile=obj('uifile','{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = UITests/NovaChessUITests.swift; sourceTree = SOURCE_ROOT;}')
uibuild=obj('uibuild','{isa = PBXBuildFile; fileRef = '+uifile+';}')
uisources=obj('uisources','{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = '+arr([uibuild])+'; runOnlyForDeploymentPostprocessing = 0;}')
uiproduct=obj('uiproduct','{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = NovaChessUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;}')
uiconfigs=[]
for mode in ['Debug','Release']:
 d={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.novachess.app.uitests','GENERATE_INFOPLIST_FILE':'YES','SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','TEST_TARGET_NAME':'NovaChess','SWIFT_OPTIMIZATION_LEVEL':'-Onone'}
 uiconfigs.append(obj('ui'+mode,'{isa = XCBuildConfiguration; buildSettings = '+settings(d)+'; name = '+mode+';}'))
uiconfig=obj('uiconfig','{isa = XCConfigurationList; buildConfigurations = '+arr(uiconfigs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;}')
uitarget=obj('uitarget','{isa = PBXNativeTarget; buildConfigurationList = '+uiconfig+'; buildPhases = '+arr([uisources])+'; buildRules = (); dependencies = '+arr([dependency])+'; name = NovaChessUITests; productName = NovaChessUITests; productReference = '+uiproduct+'; productType = "com.apple.product-type.bundle.ui-testing";}')
objects[products]=objects[products].replace(arr([product,testproduct]),arr([product,testproduct,uiproduct]))
objects[main]=objects[main].replace(arr(fileids+[testgroup,products]),arr(fileids+[testgroup,uifile,products]))

project=obj('project','{isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {'+target+' = {SystemCapabilities = {com.apple.GameCenter = {enabled = 1;}; com.apple.iCloud = {enabled = 1;};};};};}; buildConfigurationList = '+ref('projectconfig')+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = '+main+'; productRefGroup = '+products+'; projectDirPath = ""; projectRoot = ""; targets = '+arr([target,testtarget,uitarget])+';}')
p=r/'NovaChess.xcodeproj';p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(k+' = '+v+';\n' for k,v in objects.items())+'}; rootObject = '+project+';}\n')
s=p/'xcshareddata/xcschemes';s.mkdir(parents=True,exist_ok=True)
(s/'NovaChess.xcscheme').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+target+'''" BuildableName="NovaChess.app" BlueprintName="NovaChess" ReferencedContainer="container:NovaChess.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+testtarget+'''" BuildableName="NovaChessTests.xctest" BlueprintName="NovaChessTests" ReferencedContainer="container:NovaChess.xcodeproj"/></TestableReference><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+uitarget+'''" BuildableName="NovaChessUITests.xctest" BlueprintName="NovaChessUITests" ReferencedContainer="container:NovaChess.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+target+'''" BuildableName="NovaChess.app" BlueprintName="NovaChess" ReferencedContainer="container:NovaChess.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+target+'''" BuildableName="NovaChess.app" BlueprintName="NovaChess" ReferencedContainer="container:NovaChess.xcodeproj"/></BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
plist={'CFBundleDevelopmentRegion':'en','CFBundleDisplayName':'NovaChess','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','LSRequiresIPhoneOS':True,'NSPhotoLibraryAddUsageDescription':'Save a shared board image or game animation to Photos when you choose Save Image.','NSCameraUsageDescription':'Photograph or watch a chessboard to reconstruct positions and record game notation. Camera images stay on this device.','UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UILaunchScreen':{},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']}
(r/'NovaChess/Info.plist').write_bytes(plistlib.dumps(plist))
privacy={'NSPrivacyTracking':False,'NSPrivacyTrackingDomains':[],'NSPrivacyCollectedDataTypes':[{'NSPrivacyCollectedDataType':'NSPrivacyCollectedDataTypeUserID','NSPrivacyCollectedDataTypeLinked':True,'NSPrivacyCollectedDataTypeTracking':False,'NSPrivacyCollectedDataTypePurposes':['NSPrivacyCollectedDataTypePurposeAppFunctionality']},{'NSPrivacyCollectedDataType':'NSPrivacyCollectedDataTypeOtherUserContent','NSPrivacyCollectedDataTypeLinked':True,'NSPrivacyCollectedDataTypeTracking':False,'NSPrivacyCollectedDataTypePurposes':['NSPrivacyCollectedDataTypePurposeAppFunctionality']}],'NSPrivacyAccessedAPITypes':[{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryUserDefaults','NSPrivacyAccessedAPITypeReasons':['CA92.1']},{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategorySystemBootTime','NSPrivacyAccessedAPITypeReasons':['35F9.1']},{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryFileTimestamp','NSPrivacyAccessedAPITypeReasons':['C617.1']}]}
(r/'NovaChess/Resources/PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps(privacy))
print('Generated',len(files),'source references and shared scheme')
