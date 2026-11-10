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
files=sorted([str(p.relative_to(r)) for p in (r/'ChessVision').rglob('*.swift')]+['Engine/StockfishBridge.cpp']+[str(p.relative_to(r)) for p in (r/'Vendor/FairyStockfish').rglob('*.cpp') if p.name not in ['main.cpp','pyffish.cpp','ffishjs.cpp']])
resources=['ChessVision/Resources/ClassicalPrelude.wav','ChessVision/Resources/Assets.xcassets','ChessVision/Resources/ChessPieces.mlpackage','ChessVision/Resources/ChessPiecesDetail.mlpackage','ChessVision/Resources/ThirdPartyNotices.txt','ChessVision/Resources/PrivacyInfo.xcprivacy','ChessVision/Core/Resources/Puzzles.json','ChessVision/Core/Resources/Openings.json']
fileids=[];buildids=[];resids=[]
for f in files+resources:
 typ='sourcecode.swift' if f.endswith('.swift') else 'sourcecode.cpp.cpp' if f.endswith('.cpp') else 'folder.assetcatalog' if f.endswith('.xcassets') else 'folder.mlpackage' if f.endswith('.mlpackage') else 'text.xml' if f.endswith('.xcprivacy') else 'text'
 fid=obj('file:'+f,'{isa = PBXFileReference; lastKnownFileType = '+typ+'; path = '+q(f)+'; sourceTree = SOURCE_ROOT;}');fileids.append(fid)
 bid=obj('build:'+f,'{isa = PBXBuildFile; fileRef = '+fid+';}')
 # Core ML models belong in Sources so Xcode invokes coremlc, not a raw resource copy.
 if f in files or f.endswith('.mlpackage'):buildids.append(bid)
 else:resids.append(bid)
product=obj('product','{isa = PBXFileReference; explicitFileType = wrapper.application; path = ChessVision.app; sourceTree = BUILT_PRODUCTS_DIR;}')
products=obj('products','{isa = PBXGroup; children = '+arr([product])+'; name = Products; sourceTree = "<group>";}')
main=obj('main','{isa = PBXGroup; children = '+arr(fileids+[products])+'; sourceTree = "<group>";}')
sources=obj('sources','{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = '+arr(buildids)+'; runOnlyForDeploymentPostprocessing = 0;}')
res=obj('resources','{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = '+arr(resids)+'; runOnlyForDeploymentPostprocessing = 0;}')
frameworks=obj('frameworks','{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;}')
common={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_CXX_LANGUAGE_STANDARD':'c++17','CLANG_CXX_LIBRARY':'libc++','CLANG_ENABLE_MODULES':'YES','ENABLE_USER_SCRIPT_SANDBOXING':'YES'}
app={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.chessvision.app','INFOPLIST_FILE':'ChessVision/Info.plist','CODE_SIGN_STYLE':'Automatic','TARGETED_DEVICE_FAMILY':'1','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SWIFT_OBJC_BRIDGING_HEADER':'ChessVision/ChessVision-Bridging-Header.h','HEADER_SEARCH_PATHS':['$(inherited)','$(SRCROOT)/Engine','$(SRCROOT)/Vendor/FairyStockfish'],'GCC_PREPROCESSOR_DEFINITIONS':['$(inherited)','IS_64BIT','NO_PREFETCH','NNUE_EMBEDDING_OFF','ALLVARS'],'OTHER_LDFLAGS':['$(inherited)','-lc++'],'GCC_STRICT_ALIASING':'NO','GCC_OPTIMIZATION_LEVEL':'3','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','CURRENT_PROJECT_VERSION':'11','MARKETING_VERSION':'0.11.0','SWIFT_EMIT_LOC_STRINGS':'YES','COREML_CODEGEN_LANGUAGE':'Swift','ENABLE_PREVIEWS':'YES'}
def settings(d):return '{'+''.join(k+' = '+(arr([q(x) for x in v]) if isinstance(v,list) else q(v))+';' for k,v in d.items())+'}'
for scope,base in [('project',common),('app',app)]:
 configs=[]
 for mode in ['Debug','Release']:
  conf=base.copy()
  if scope=='project':conf.update({'GCC_OPTIMIZATION_LEVEL':'0' if mode=='Debug' else '3','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym','ENABLE_TESTABILITY':'YES' if mode=='Debug' else 'NO'})
  configs.append(obj(scope+mode,'{isa = XCBuildConfiguration; buildSettings = '+settings(conf)+'; name = '+mode+';}'))
 obj(scope+'config','{isa = XCConfigurationList; buildConfigurations = '+arr(configs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
target=obj('target','{isa = PBXNativeTarget; buildConfigurationList = '+ref('appconfig')+'; buildPhases = '+arr([sources,frameworks,res])+'; buildRules = (); dependencies = (); name = ChessVision; productName = ChessVision; productReference = '+product+'; productType = "com.apple.product-type.application";}')

testfiles = sorted(str(p.relative_to(r)) for folder in ['Tests/Core','Tests/iOS'] for p in (r/folder).rglob('*.swift'))
testbuild=[]
for f in testfiles:
 fid=obj('file:'+f,'{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = '+q(f)+'; sourceTree = SOURCE_ROOT;}')
 bid=obj('build:'+f,'{isa = PBXBuildFile; fileRef = '+fid+';}');testbuild.append(bid)
# Visible test group attached to the main group.
testgroup=obj('testgroup','{isa = PBXGroup; children = '+arr([ref('file:'+f) for f in testfiles])+'; name = Tests; sourceTree = "<group>";}')
objects[main]=objects[main].replace(arr(fileids+[products]),arr(fileids+[testgroup,products]))
testproduct=obj('testproduct','{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = ChessVisionTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;}')
objects[products]=objects[products].replace(arr([product]),arr([product,testproduct]))
testsources=obj('testsources','{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = '+arr(testbuild)+'; runOnlyForDeploymentPostprocessing = 0;}')
fixturefile=obj('fixturefile','{isa = PBXFileReference; lastKnownFileType = folder; path = Tests/Fixtures; sourceTree = SOURCE_ROOT;}')
fixturebuild=obj('fixturebuild','{isa = PBXBuildFile; fileRef = '+fixturefile+';}')
referencefile=obj('referencefile','{isa = PBXFileReference; lastKnownFileType = folder; path = Tests/Core/Reference; sourceTree = SOURCE_ROOT;}')
referencebuild=obj('referencebuild','{isa = PBXBuildFile; fileRef = '+referencefile+';}')
testresources=obj('testresources','{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = '+arr([fixturebuild,referencebuild])+'; runOnlyForDeploymentPostprocessing = 0;}')
testconfigs=[]
for mode in ['Debug','Release']:
 d={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.chessvision.app.tests','GENERATE_INFOPLIST_FILE':'YES','SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/ChessVision.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ChessVision','BUNDLE_LOADER':'$(TEST_HOST)','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O'}
 testconfigs.append(obj('test'+mode,'{isa = XCBuildConfiguration; buildSettings = '+settings(d)+'; name = '+mode+';}'))
testconfig=obj('testconfig','{isa = XCConfigurationList; buildConfigurations = '+arr(testconfigs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;}')
proxy=obj('proxy','{isa = PBXContainerItemProxy; containerPortal = '+ref('project')+'; proxyType = 1; remoteGlobalIDString = '+target+'; remoteInfo = ChessVision;}')
dependency=obj('dependency','{isa = PBXTargetDependency; target = '+target+'; targetProxy = '+proxy+';}')
testtarget=obj('testtarget','{isa = PBXNativeTarget; buildConfigurationList = '+testconfig+'; buildPhases = '+arr([testsources,testresources])+'; buildRules = (); dependencies = '+arr([dependency])+'; name = ChessVisionTests; productName = ChessVisionTests; productReference = '+testproduct+'; productType = "com.apple.product-type.bundle.unit-test";}')


uifile=obj('uifile','{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = UITests/ChessVisionUITests.swift; sourceTree = SOURCE_ROOT;}')
uibuild=obj('uibuild','{isa = PBXBuildFile; fileRef = '+uifile+';}')
uisources=obj('uisources','{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = '+arr([uibuild])+'; runOnlyForDeploymentPostprocessing = 0;}')
uiproduct=obj('uiproduct','{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = ChessVisionUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;}')
uiconfigs=[]
for mode in ['Debug','Release']:
 d={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.chessvision.app.uitests','GENERATE_INFOPLIST_FILE':'YES','SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','TEST_TARGET_NAME':'ChessVision','SWIFT_OPTIMIZATION_LEVEL':'-Onone'}
 uiconfigs.append(obj('ui'+mode,'{isa = XCBuildConfiguration; buildSettings = '+settings(d)+'; name = '+mode+';}'))
uiconfig=obj('uiconfig','{isa = XCConfigurationList; buildConfigurations = '+arr(uiconfigs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;}')
uitarget=obj('uitarget','{isa = PBXNativeTarget; buildConfigurationList = '+uiconfig+'; buildPhases = '+arr([uisources])+'; buildRules = (); dependencies = '+arr([dependency])+'; name = ChessVisionUITests; productName = ChessVisionUITests; productReference = '+uiproduct+'; productType = "com.apple.product-type.bundle.ui-testing";}')
objects[products]=objects[products].replace(arr([product,testproduct]),arr([product,testproduct,uiproduct]))
objects[main]=objects[main].replace(arr(fileids+[testgroup,products]),arr(fileids+[testgroup,uifile,products]))

project=obj('project','{isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600;}; buildConfigurationList = '+ref('projectconfig')+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = '+main+'; productRefGroup = '+products+'; projectDirPath = ""; projectRoot = ""; targets = '+arr([target,testtarget,uitarget])+';}')
p=r/'ChessVision.xcodeproj';p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(k+' = '+v+';\n' for k,v in objects.items())+'}; rootObject = '+project+';}\n')
s=p/'xcshareddata/xcschemes';s.mkdir(parents=True,exist_ok=True)
(s/'ChessVision.xcscheme').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+target+'''" BuildableName="ChessVision.app" BlueprintName="ChessVision" ReferencedContainer="container:ChessVision.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+testtarget+'''" BuildableName="ChessVisionTests.xctest" BlueprintName="ChessVisionTests" ReferencedContainer="container:ChessVision.xcodeproj"/></TestableReference><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+uitarget+'''" BuildableName="ChessVisionUITests.xctest" BlueprintName="ChessVisionUITests" ReferencedContainer="container:ChessVision.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+target+'''" BuildableName="ChessVision.app" BlueprintName="ChessVision" ReferencedContainer="container:ChessVision.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+target+'''" BuildableName="ChessVision.app" BlueprintName="ChessVision" ReferencedContainer="container:ChessVision.xcodeproj"/></BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
plist={'CFBundleDevelopmentRegion':'en','CFBundleDisplayName':'ChessVision','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','LSRequiresIPhoneOS':True,'NSPhotoLibraryAddUsageDescription':'Save a shared board image or game animation to Photos when you choose Save Image.','NSCameraUsageDescription':'Photograph a physical chessboard to reconstruct its position on your iPhone. Photos stay on this device.','UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UILaunchScreen':{},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']}
(r/'ChessVision/Info.plist').write_bytes(plistlib.dumps(plist))
privacy={'NSPrivacyTracking':False,'NSPrivacyTrackingDomains':[],'NSPrivacyCollectedDataTypes':[],'NSPrivacyAccessedAPITypes':[{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryUserDefaults','NSPrivacyAccessedAPITypeReasons':['CA92.1']},{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategorySystemBootTime','NSPrivacyAccessedAPITypeReasons':['35F9.1']},{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryFileTimestamp','NSPrivacyAccessedAPITypeReasons':['C617.1']}]}
(r/'ChessVision/Resources/PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps(privacy))
print('Generated',len(files),'source references and shared scheme')
