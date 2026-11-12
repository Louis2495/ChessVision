#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
build="$root/.build/features"
mkdir -p "$build/include"
library=$(bash Scripts/build-engine-library.sh)
modern=$(python3 Scripts/build-modern-engine.py)
cp Engine/StockfishBridge.h "$build/include/StockfishBridge.h"
cat > "$build/include/module.modulemap" <<'MAP'
module CStockfish { header "StockfishBridge.h" export * }
MAP
python3 - "$root" "$build" <<'PY'
from pathlib import Path
import sys
root,build=map(Path,sys.argv[1:])
for file in ['Engine/EngineController.swift','Services/VariantRules.swift','Services/BughouseRules.swift']:
 (build/Path(file).name).write_text('import CStockfish\n'+(root/'NovaChess'/file).read_text())
for file,separator in [('ComputerPlayView.swift','struct ComputerPlayView: View'),('OpeningExplorerView.swift','struct OpeningExplorerView: View')]:
 source=(root/'NovaChess/Features'/file).read_text().split(separator)[0]
 (build/('Models-'+file)).write_text(source.replace('import SwiftUI','import Foundation\nimport Combine'))
PY
link_options=()
platform_options=()
if [[ "$(uname -s)" == Linux ]]; then
 swiftc -emit-library -emit-module -module-name Combine Tests/Headless/CombineShim.swift -o "$build/libCombine.so" -emit-module-path "$build/Combine.swiftmodule"
 link_options=(-I "$build" -L "$build" -lCombine -Xlinker -rpath -Xlinker "$build" -Xlinker -lstdc++)
else
 link_options=(-Xlinker -lc++)
 platform_options=(-target "$(uname -m)-apple-macosx13.0")
fi
swiftc -swift-version 5 "${platform_options[@]}" -parse-as-library -I "$build/include" NovaChess/Core/*.swift "$build"/*.swift NovaChess/Services/LibraryStore.swift NovaChess/Services/PublicGameService.swift NovaChess/Services/GameReviewModel.swift NovaChess/Services/BughouseModel.swift Tests/Headless/FeatureChecks.swift "$library" "$modern" "${link_options[@]}" -o "$build/feature-checks"
"$build/feature-checks" "$root"
